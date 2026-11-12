import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/tenant_model.dart';
import '../blocs/management/management_bloc.dart';

Future<void> showTenantTransfer(
    BuildContext context, TenantModel tenant) async {
  final bloc = context.read<ManagementBloc>();
  String? selected;
  final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, update) => BlocBuilder<ManagementBloc,
                  ManagementState>(
              bloc: bloc,
              builder: (context, state) {
                if (state is! ManagementLoaded) {
                  return const AlertDialog(
                      content: Text('Please wait for tenant data.'));
                }
                final beds = state.beds
                    .where((b) =>
                        b.status == BedStatus.vacant &&
                        b.bedId != tenant.bedId &&
                        b.bedId != null &&
                        state.rooms.any((r) =>
                            r.roomId == b.roomId &&
                            r.isAvailable(state.rooms)) &&
                        !state.tenants
                            .any((t) => t.active && t.bedId == b.bedId))
                    .toList();
                final valid = beds.any((b) => b.bedId == selected);
                return AlertDialog(
                  title: Text('Transfer ${tenant.tenantName}'),
                  content: SizedBox(
                      width: 420,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text(
                            'Choose a vacant bed. The tenant keeps their rent, advance and payment records.'),
                        const SizedBox(height: 20),
                        if (beds.isEmpty)
                          const Text('No vacant beds in available rooms.')
                        else
                          DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: valid ? selected : null,
                              icon: const Icon(CupertinoIcons.chevron_down),
                              decoration: const InputDecoration(
                                  labelText: 'Destination bed'),
                              items: beds.map((bed) {
                                final room = state.rooms
                                    .firstWhere((r) => r.roomId == bed.roomId);
                                final building = state.buildings
                                    .where(
                                        (b) => b.buildingId == room.buildingId)
                                    .firstOrNull;
                                return DropdownMenuItem(
                                    value: bed.bedId,
                                    child: Text(
                                        '${building?.buildingName ?? ''} · ${room.displayName(state.rooms)} · ${bed.bedType.name} (${bed.bedId})',
                                        overflow: TextOverflow.ellipsis));
                              }).toList(),
                              onChanged: (value) =>
                                  update(() => selected = value)),
                      ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed:
                            valid ? () => Navigator.pop(context, true) : null,
                        child: const Text('Transfer'))
                  ],
                );
              })));
  if (confirm != true || !context.mounted) return;
  final state = bloc.state;
  if (state is! ManagementLoaded) return;
  final bed = state.beds.where((b) => b.bedId == selected).firstOrNull;
  final room = state.rooms.where((r) => r.roomId == bed?.roomId).firstOrNull;
  if (bed == null ||
      room == null ||
      bed.status != BedStatus.vacant ||
      !room.isAvailable(state.rooms)) {
    return;
  }
  bloc.add(UpdateTenant(tenant.copyWith(
      buildingId: room.buildingId, roomId: room.roomId, bedId: bed.bedId)));
}
