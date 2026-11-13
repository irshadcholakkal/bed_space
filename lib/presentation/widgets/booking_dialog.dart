import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/management_repository.dart';
import '../blocs/management/management_bloc.dart';

Future<void> showBookingDialog(BuildContext context, {String? bedId}) async {
  final bloc = context.read<ManagementBloc>();
  final repository = context.read<ManagementRepository>();
  await showDialog<void>(
      context: context,
      builder: (_) => BlocProvider.value(
          value: bloc,
          child: _BookingDialog(repository: repository, bedId: bedId)));
}

class _BookingDialog extends StatefulWidget {
  final ManagementRepository repository;
  final String? bedId;
  const _BookingDialog({required this.repository, this.bedId});
  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _rent = TextEditingController();
  final _advance = TextEditingController(text: '0');
  final _rentPaid = TextEditingController(text: '0');
  final _due = TextEditingController(text: '1');
  late String? _bedId = widget.bedId;
  DateTime _moveIn = BookingModel.day(DateTime.now());
  DateTime _paidDate = BookingModel.day(DateTime.now());
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final data = context.read<ManagementBloc>().state;
    if (data is ManagementLoaded && _bedId != null) {
      final bed = data.beds.where((bed) => bed.bedId == _bedId).firstOrNull;
      final room =
          data.rooms.where((room) => room.roomId == bed?.roomId).firstOrNull;
      if (bed != null && room != null) {
        _rent.text = (bed.bedType == BedType.lower
                ? room.lowerBedRent
                : room.upperBedRent)
            .toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _phone,
      _rent,
      _advance,
      _rentPaid,
      _due
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _money(String? value, {bool positive = false}) {
    final number = double.tryParse(value ?? '');
    if (number == null ||
        !number.isFinite ||
        number < 0 ||
        (positive && number == 0)) {
      return positive
          ? 'Enter a positive amount'
          : 'Enter zero or a positive amount';
    }
    return null;
  }

  Future<void> _save(ManagementLoaded data, String? bedId) async {
    if (!_form.currentState!.validate() || bedId == null) return;
    final bed = data.beds.firstWhere((bed) => bed.bedId == bedId);
    final room = data.rooms.firstWhere((room) => room.roomId == bed.roomId);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.addBooking(BookingModel(
          bookingId: const Uuid().v4(),
          tenantName: _name.text.trim(),
          phone: _phone.text.trim(),
          buildingId: room.buildingId,
          roomId: bed.roomId,
          bedId: bedId,
          moveInDate: _moveIn,
          rentAmount: double.parse(_rent.text),
          advanceAmount: double.parse(_advance.text),
          rentPaid: double.parse(_rentPaid.text),
          paymentDate: _paidDate,
          rentDueDay: int.parse(_due.text)));
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ManagementBloc, ManagementState>(builder: (context, state) {
        if (state is! ManagementLoaded) {
          return const AlertDialog(content: Text('Loading bed availability…'));
        }
        final candidates = state.beds.where((bed) {
          if (bed.bedId == null ||
              state.bookings.any((booking) =>
                  booking.bedId == bed.bedId &&
                  booking.status == BookingStatus.reserved)) {
            return false;
          }
          if (!state.rooms.any((room) =>
              room.roomId == bed.roomId && room.isAvailable(state.rooms))) {
            return false;
          }
          final occupants = state.tenants
              .where((tenant) => tenant.active && tenant.bedId == bed.bedId);
          if (occupants.isEmpty) return bed.status == BedStatus.vacant;
          return occupants.every((tenant) =>
              tenant.checkoutDate != null &&
              !BookingModel.day(tenant.checkoutDate!).isAfter(_moveIn));
        }).toList();
        final selection =
            candidates.where((bed) => bed.bedId == _bedId).firstOrNull;
        return PopScope(
            canPop: !_saving,
            child: AlertDialog(
              title: const Text('Book a bed'),
              content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                      child: Form(
                          key: _form,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                    controller: _name,
                                    enabled: !_saving,
                                    decoration: const InputDecoration(
                                        labelText: 'Tenant name'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Enter a name'
                                            : null),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _phone,
                                    enabled: !_saving,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                        labelText: 'Phone number'),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                            ? 'Enter a phone number'
                                            : null),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                    icon: const Icon(Icons.event),
                                    label: Text(
                                        'Move-in · ${DateFormat('dd MMM yyyy').format(_moveIn)}'),
                                    onPressed: _saving
                                        ? null
                                        : () async {
                                            final today = BookingModel.day(
                                                DateTime.now());
                                            final date = await showDatePicker(
                                                context: context,
                                                initialDate: _moveIn,
                                                firstDate: today,
                                                lastDate: DateTime(
                                                    today.year + 5, 12, 31));
                                            if (date != null && mounted) {
                                              setState(() => _moveIn = date);
                                            }
                                          }),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                    key: ValueKey(
                                        '${_moveIn.toIso8601String()}/${selection?.bedId}/${candidates.length}'),
                                    initialValue: selection?.bedId,
                                    isExpanded: true,
                                    decoration:
                                        const InputDecoration(labelText: 'Bed'),
                                    items: candidates.map((bed) {
                                      final room = state.rooms.firstWhere(
                                          (room) => room.roomId == bed.roomId);
                                      final building = state.buildings
                                          .where((building) =>
                                              building.buildingId ==
                                              room.buildingId)
                                          .firstOrNull;
                                      final number = state.beds
                                              .where((other) =>
                                                  other.roomId == bed.roomId &&
                                                  other.bedType == bed.bedType)
                                              .toList()
                                              .indexOf(bed) +
                                          1;
                                      return DropdownMenuItem(
                                          value: bed.bedId,
                                          child: Text(
                                              '${building?.buildingName ?? ''} · ${room.displayName(state.rooms)} · ${bed.bedType.name} $number',
                                              overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    validator: (value) => value == null
                                        ? 'Select an available bed'
                                        : null,
                                    onChanged: _saving
                                        ? null
                                        : (value) => setState(() {
                                              _bedId = value;
                                              final bed = candidates.firstWhere(
                                                  (bed) => bed.bedId == value);
                                              final room = state.rooms
                                                  .firstWhere((room) =>
                                                      room.roomId ==
                                                      bed.roomId);
                                              _rent.text =
                                                  (bed.bedType == BedType.lower
                                                          ? room.lowerBedRent
                                                          : room.upperBedRent)
                                                      .toStringAsFixed(2);
                                            })),
                                const SizedBox(height: 8),
                                const Text(
                                    'For an occupied bed, schedule the current tenant’s checkout on or before the move-in date.'),
                                if (selection != null &&
                                    selection.status == BedStatus.occupied)
                                  const Padding(
                                      padding: EdgeInsets.only(top: 8),
                                      child: Text(
                                          'The current tenant remains checked in until you confirm their checkout.')),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _rent,
                                    enabled: !_saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Monthly rent (AED)'),
                                    validator: (value) =>
                                        _money(value, positive: true)),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _advance,
                                    enabled: !_saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'Advance received (AED)'),
                                    validator: _money),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _rentPaid,
                                    enabled: !_saving,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText:
                                            'Rent received for move-in month (AED)'),
                                    validator: _money),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () async {
                                            final date = await showDatePicker(
                                                context: context,
                                                initialDate: _paidDate,
                                                firstDate: DateTime(2000),
                                                lastDate: BookingModel.day(
                                                    DateTime.now()));
                                            if (date != null && mounted) {
                                              setState(() => _paidDate = date);
                                            }
                                          },
                                    child: Text(
                                        'Payment date · ${DateFormat('dd MMM yyyy').format(_paidDate)}')),
                                const SizedBox(height: 16),
                                TextFormField(
                                    controller: _due,
                                    enabled: !_saving,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                        labelText: 'Rent due day (1–31)'),
                                    validator: (value) {
                                      final day = int.tryParse(value ?? '');
                                      return day == null || day < 1 || day > 31
                                          ? 'Enter a day from 1 to 31'
                                          : null;
                                    }),
                                if (_error != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Text(_error!,
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error))),
                              ])))),
              actions: [
                TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Close')),
                FilledButton(
                    onPressed:
                        _saving ? null : () => _save(state, selection?.bedId),
                    child: Text(_saving ? 'Saving…' : 'Save booking')),
              ],
            ));
      });
}
