import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/booking_model.dart';
import '../../data/repositories/management_repository.dart';
import '../blocs/management/management_bloc.dart';
import '../widgets/booking_dialog.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  BookingStatus _filter = BookingStatus.reserved;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel(BookingModel booking) async {
    var refund = '0';
    final form = GlobalKey<FormState>();
    final value = await showDialog<double>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Cancel ${booking.tenantName}’s booking?'),
              content: SizedBox(
                  width: 380,
                  child: Form(
                      key: form,
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                                'Received AED ${(booking.advanceAmount + booking.rentPaid).toStringAsFixed(2)}. Enter the refund paid now. Payment and refund records are retained.'),
                            const SizedBox(height: 16),
                            TextFormField(
                                initialValue: refund,
                                onChanged: (value) => refund = value,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'Refund paid (AED)'),
                                validator: (value) {
                                  final amount = double.tryParse(value ?? '');
                                  return amount == null ||
                                          !amount.isFinite ||
                                          amount < 0 ||
                                          amount >
                                              booking.advanceAmount +
                                                  booking.rentPaid
                                      ? 'Enter an amount up to the total received'
                                      : null;
                                }),
                          ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Keep booking')),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, double.parse(refund));
                      }
                    },
                    child: const Text('Cancel booking')),
              ],
            ));
    if (value != null && mounted) {
      await _run(() => context
          .read<ManagementRepository>()
          .cancelBooking(booking.bookingId, refund: value));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bed bookings'), actions: [
          IconButton(
              tooltip: 'Manage tenants',
              icon: const Icon(Icons.people_outline),
              onPressed: () => context.push('/tenants')),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _busy ? null : () => showBookingDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Book a bed')),
        body: BlocBuilder<ManagementBloc, ManagementState>(
            builder: (context, state) {
          if (state is! ManagementLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final bookings = state.bookings
              .where((booking) => booking.status == _filter)
              .toList()
            ..sort((a, b) => a.moveInDate.compareTo(b.moveInDate));
          return Column(children: [
            Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BookingStatus.values
                        .map((status) => ChoiceChip(
                              label: Text(switch (status) {
                                BookingStatus.reserved => 'Reserved',
                                BookingStatus.checkedIn => 'Checked in',
                                BookingStatus.cancelled => 'Cancelled',
                              }),
                              selected: _filter == status,
                              onSelected: (_) =>
                                  setState(() => _filter = status),
                            ))
                        .toList())),
            if (_busy) const LinearProgressIndicator(),
            Expanded(
                child: RefreshIndicator(
              onRefresh: () => _run(
                  () => context.read<ManagementRepository>().triggerSync()),
              child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (bookings.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('No bookings in this view.',
                              textAlign: TextAlign.center)),
                    for (final booking in bookings) _card(state, booking),
                  ]),
            )),
          ]);
        }),
      );

  Widget _card(ManagementLoaded state, BookingModel booking) {
    final room =
        state.rooms.where((room) => room.roomId == booking.roomId).firstOrNull;
    final building = state.buildings
        .where((building) => building.buildingId == booking.buildingId)
        .firstOrNull;
    final bed =
        state.beds.where((bed) => bed.bedId == booking.bedId).firstOrNull;
    final roomBeds = state.beds
        .where((other) =>
            other.roomId == booking.roomId && other.bedType == bed?.bedType)
        .toList();
    final occupant = state.tenants
        .where((tenant) => tenant.active && tenant.bedId == booking.bedId)
        .firstOrNull;
    final due = !BookingModel.day(booking.moveInDate)
        .isAfter(BookingModel.day(DateTime.now()));
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(booking.tenantName,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(booking.phone),
              Text(
                  '${building?.buildingName ?? ''} · ${room?.displayName(state.rooms) ?? booking.roomId} · ${bed?.bedType.name ?? 'Bed'} ${bed == null ? '' : roomBeds.indexOf(bed) + 1}'),
              const SizedBox(height: 8),
              Text(
                  'Move-in ${DateFormat('dd MMM yyyy').format(booking.moveInDate)}'),
              Text(
                  'Monthly rent AED ${booking.rentAmount.toStringAsFixed(2)} · Due day ${booking.rentDueDay}'),
              Text(
                  'Advance received AED ${booking.advanceAmount.toStringAsFixed(2)}'),
              Text(
                  'Rent received AED ${booking.rentPaid.toStringAsFixed(2)} for ${booking.rentMonth}'),
              if (booking.advanceAmount + booking.rentPaid > 0)
                Text(
                    'Payment date ${DateFormat('dd MMM yyyy').format(booking.paymentDate)}'),
              if (booking.status == BookingStatus.cancelled)
                Text(
                    'Refund paid AED ${booking.refundAmount.toStringAsFixed(2)}'),
              if (booking.status == BookingStatus.reserved) ...[
                if (occupant != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          'Current tenant ${occupant.tenantName} · Checkout ${occupant.checkoutDate == null ? 'pending' : DateFormat('dd MMM yyyy').format(occupant.checkoutDate!)}')),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FilledButton(
                      onPressed: _busy || !due || occupant != null
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                        title: Text(
                                            'Check in ${booking.tenantName}?'),
                                        content: Text(
                                            'The tenant account will use the booked move-in date ${DateFormat('dd MMM yyyy').format(booking.moveInDate)} and the saved advance and rent payment.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Close')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text(
                                                  'Confirm check-in')),
                                        ],
                                      ));
                              if (confirmed == true && mounted) {
                                await _run(() => context
                                    .read<ManagementRepository>()
                                    .checkInBooking(booking.bookingId));
                              }
                            },
                      child: const Text('Check in')),
                  TextButton(
                      onPressed: _busy ? null : () => _cancel(booking),
                      child: const Text('Cancel booking')),
                ]),
                if (!due) const Text('Check-in opens on the move-in date.'),
                if (due && occupant != null)
                  const Text(
                      'Confirm the current tenant’s checkout in Manage Tenants.'),
              ],
            ])));
  }
}
