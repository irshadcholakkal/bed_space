import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/management_repository.dart';
import '../blocs/management/management_bloc.dart';

Future<void> showRoomEditSheet(BuildContext context, RoomModel room,
    {VoidCallback? onDelete}) {
  final repository = context.read<ManagementRepository>();
  final state = context.read<ManagementBloc>().state;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _RoomEditor(
        room: room,
        onDelete: onDelete,
        repository: repository,
        rooms: state is ManagementLoaded ? state.rooms : [room]),
  );
}

class _RoomEditor extends StatefulWidget {
  final VoidCallback? onDelete;
  final RoomModel room;
  final ManagementRepository repository;
  final List<RoomModel> rooms;
  const _RoomEditor(
      {required this.room,
      required this.repository,
      required this.rooms,
      this.onDelete});
  @override
  State<_RoomEditor> createState() => _RoomEditorState();
}

class _RoomEditorState extends State<_RoomEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.room.roomNumber);
  late final _lower =
      TextEditingController(text: '${widget.room.lowerBedsCount}');
  late final _upper =
      TextEditingController(text: '${widget.room.upperBedsCount}');
  late final _rent = TextEditingController(text: '${widget.room.lowerBedRent}');
  late final _upperRent =
      TextEditingController(text: '${widget.room.upperBedRent}');
  late final _landlordRent =
      TextEditingController(text: '${widget.room.monthlyRent}');
  late RoomType _type = widget.room.roomType;
  late bool _available = widget.room.available;
  late String? _parent = widget.room.parentRoomId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _lower,
      _upper,
      _rent,
      _upperRent,
      _landlordRent
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Widget _number(TextEditingController controller, String label,
          {bool count = false}) =>
      Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TextFormField(
            controller: controller,
            enabled: !_saving,
            keyboardType: TextInputType.numberWithOptions(decimal: !count),
            decoration: InputDecoration(labelText: label),
            onChanged: count ? (_) => setState(() {}) : null,
            validator: (text) {
              final value = count
                  ? int.tryParse(text ?? '')
                  : double.tryParse(text ?? '');
              return value == null || !value.isFinite || value < 0
                  ? 'Enter a non-negative ${count ? 'whole number' : 'amount'}'
                  : null;
            },
          ));

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final whole = _type != RoomType.bedspace;
      final lower = whole ? 1 : int.parse(_lower.text);
      final upper = whole ? 0 : int.parse(_upper.text);
      final room = widget.room;
      final updated = RoomModel(
          roomId: room.roomId,
          roomType: _type,
          buildingId: room.buildingId,
          roomNumber: _name.text.trim(),
          parentRoomId: _parent,
          available: _available,
          media: room.media,
          totalCapacity: lower + upper,
          lowerBedsCount: lower,
          upperBedsCount: upper,
          lowerBedRent: double.parse(_rent.text),
          upperBedRent: whole ? 0 : double.parse(_upperRent.text),
          utilityCostMonthly: room.utilityCostMonthly,
          monthlyRent: double.parse(_landlordRent.text));
      updated.validateHierarchy(widget.rooms);
      await widget.repository.updateRoom(updated);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error =
              error is ArgumentError ? '${error.message}' : error.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final whole = _type != RoomType.bedspace;
    final hasChildren =
        widget.rooms.any((room) => room.parentRoomId == widget.room.roomId);
    return PopScope(
        canPop: !_saving,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Form(
              key: _form,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Edit room, beds & rent',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                    if (widget.onDelete != null)
                      TextButton.icon(
                          onPressed: _saving
                              ? null
                              : () {
                                  Navigator.pop(context);
                                  widget.onDelete!();
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete room')),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<RoomType>(
                      initialValue: _type,
                      isExpanded: true,
                      decoration:
                          const InputDecoration(labelText: 'Rental type'),
                      items: [
                        for (final type in RoomType.values)
                          DropdownMenuItem(value: type, child: Text(type.label))
                      ],
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _type = value!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                            labelText: 'Room / unit name'),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? 'Enter a name'
                            : null),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                        initialValue: _parent ?? '',
                        isExpanded: true,
                        isDense: false,
                        itemHeight: null,
                        decoration: const InputDecoration(
                            labelText: 'Inside room (optional)'),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Main room')),
                          for (final room in widget.rooms.where((room) =>
                              !room.isSubroom &&
                              room.roomId != widget.room.roomId &&
                              room.buildingId == widget.room.buildingId))
                            DropdownMenuItem(
                                value: room.roomId,
                                child: Text(room.displayName(widget.rooms)))
                        ],
                        onChanged: _saving || hasChildren
                            ? null
                            : (value) => setState(
                                () => _parent = value == '' ? null : value)),
                    if (!whole) ...[
                      _number(_lower, 'Lower beds', count: true),
                      _number(_upper, 'Upper beds', count: true),
                      const SizedBox(height: 12),
                      Text(
                          'Total capacity: ${(int.tryParse(_lower.text) ?? 0) + (int.tryParse(_upper.text) ?? 0)} beds'),
                    ] else
                      const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: Text(
                              'Rented as one complete unit with one rent amount.')),
                    _number(
                        _rent, whole ? 'Monthly unit rent' : 'Lower bed rent'),
                    if (!whole) _number(_upperRent, 'Upper bed rent'),
                    _number(_landlordRent, 'Monthly rent paid to landlord'),
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available for rent'),
                        value: _available,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _available = value)),
                    const Text(
                        'Rent changes apply to future selections. Existing tenant and booking rents stay as agreed.'),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    const SizedBox(height: 16),
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? 'Saving…' : 'Save changes')),
                  ])),
        ));
  }
}
