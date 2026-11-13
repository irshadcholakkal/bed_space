import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/management_repository.dart';
import '../../data/services/status_message_service.dart';
import '../blocs/management/management_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/booking_dialog.dart';
import '../widgets/room_sharing_actions.dart';
import 'tenants_management_screen.dart';

class VacantBedsScreen extends StatefulWidget {
  const VacantBedsScreen({super.key});

  @override
  State<VacantBedsScreen> createState() => _VacantBedsScreenState();
}

class _VacantBedsScreenState extends State<VacantBedsScreen> {
  final _search = TextEditingController();
  String? _buildingId;
  BedType? _bedType;
  String? _refreshError;
  bool _refreshing = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshError = null;
      _refreshing = true;
    });
    try {
      await context.read<ManagementRepository>().triggerSync();
    } catch (error) {
      if (mounted) setState(() => _refreshError = error.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _clearFilters() => setState(() {
        _search.clear();
        _buildingId = null;
        _bedType = null;
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        appBar: AppBar(
            title: Text('Available rooms',
                style: Theme.of(context).textTheme.titleLarge),
            actions: [
              IconButton(
                  tooltip: 'Refresh availability',
                  icon: const Icon(CupertinoIcons.refresh),
                  onPressed: _refreshing ? null : _refresh),
            ]),
        body: SafeArea(
            top: false,
            child: BlocBuilder<ManagementBloc, ManagementState>(
              builder: (context, state) {
                if (state is! ManagementLoaded ||
                    (state.isLoading && state.rooms.isEmpty)) {
                  return const Center(child: CircularProgressIndicator());
                }
                final buildings = {
                  for (final building in state.buildings)
                    building.buildingId: building
                };
                final reserved = state.reservedBedIds;
                final occupied = state.tenants
                    .where((tenant) => tenant.active)
                    .map((tenant) => tenant.bedId)
                    .toSet();
                final bedsByRoom = <String, List<BedModel>>{};
                for (final bed in state.beds) {
                  if (bed.status == BedStatus.vacant &&
                      !reserved.contains(bed.bedId) &&
                      !occupied.contains(bed.bedId)) {
                    bedsByRoom.putIfAbsent(bed.roomId, () => []).add(bed);
                  }
                }
                final allRooms = state.rooms
                    .where((room) =>
                        room.isAvailable(state.rooms) &&
                        (bedsByRoom[room.roomId]?.isNotEmpty ?? false))
                    .toList()
                  ..sort((a, b) {
                    final building =
                        (buildings[a.buildingId]?.buildingName ?? a.buildingId)
                            .compareTo(buildings[b.buildingId]?.buildingName ??
                                b.buildingId);
                    return building != 0
                        ? building
                        : a
                            .displayName(state.rooms)
                            .compareTo(b.displayName(state.rooms));
                  });
                final buildingIds =
                    allRooms.map((room) => room.buildingId).toSet().toList();
                final selectedBuilding =
                    buildingIds.contains(_buildingId) ? _buildingId : null;
                final query = _search.text.trim().toLowerCase();
                List<BedModel> matchingBeds(RoomModel room) {
                  final building = buildings[room.buildingId];
                  final matchesRoom =
                      '${room.displayName(state.rooms)} ${building?.buildingName ?? room.buildingId} ${building?.address ?? ''}'
                          .toLowerCase()
                          .contains(query);
                  return bedsByRoom[room.roomId]!
                      .where((bed) =>
                          (_bedType == null || bed.bedType == _bedType) &&
                          (matchesRoom || bed.bedType.name.contains(query)))
                      .toList();
                }

                final rooms = allRooms
                    .where((room) =>
                        (selectedBuilding == null ||
                            room.buildingId == selectedBuilding) &&
                        matchingBeds(room).isNotEmpty)
                    .toList();
                final bedCount = rooms.fold<int>(
                    0, (sum, room) => sum + matchingBeds(room).length);
                final hasFilters = query.isNotEmpty ||
                    selectedBuilding != null ||
                    _bedType != null;
                final error = _refreshError ?? state.error;
                return Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              sliver: SliverToBoxAdapter(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    TextField(
                                        controller: _search,
                                        onChanged: (_) => setState(() {}),
                                        textInputAction: TextInputAction.search,
                                        decoration: InputDecoration(
                                          hintText: 'Search room or building',
                                          prefixIcon:
                                              const Icon(CupertinoIcons.search),
                                          suffixIcon: _search.text.isEmpty
                                              ? null
                                              : IconButton(
                                                  tooltip: 'Clear search',
                                                  onPressed: () =>
                                                      setState(_search.clear),
                                                  icon: const Icon(
                                                      CupertinoIcons.xmark)),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16)),
                                        )),
                                    const SizedBox(height: 12),
                                    if (buildingIds.length > 1)
                                      DropdownButtonFormField<String>(
                                        key: ValueKey(selectedBuilding),
                                        initialValue: selectedBuilding,
                                        isExpanded: true,
                                        hint: const Text('All buildings'),
                                        decoration: const InputDecoration(
                                            labelText: 'Building',
                                            filled: true,
                                            fillColor: Colors.white),
                                        items: [
                                          const DropdownMenuItem(
                                              value: null,
                                              child: Text('All buildings')),
                                          for (final id in buildingIds)
                                            DropdownMenuItem(
                                                value: id,
                                                child: Text(
                                                    buildings[id]
                                                            ?.buildingName ??
                                                        id,
                                                    overflow:
                                                        TextOverflow.ellipsis)),
                                        ],
                                        onChanged: (id) =>
                                            setState(() => _buildingId = id),
                                      ),
                                    if (buildingIds.length > 1)
                                      const SizedBox(height: 12),
                                    Wrap(spacing: 8, runSpacing: 4, children: [
                                      for (final type in [
                                        null,
                                        ...BedType.values
                                      ])
                                        ChoiceChip(
                                          label: Text(type == null
                                              ? 'All beds'
                                              : type == BedType.lower
                                                  ? 'Lower beds'
                                                  : 'Upper beds'),
                                          selected: _bedType == type,
                                          onSelected: (_) =>
                                              setState(() => _bedType = type),
                                          visualDensity: VisualDensity.standard,
                                        ),
                                    ]),
                                    const SizedBox(height: 12),
                                    Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 12,
                                        children: [
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              child: Text(
                                                  '${rooms.length} ${rooms.length == 1 ? 'room' : 'rooms'} · $bedCount ${bedCount == 1 ? 'bed' : 'beds'} available',
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600))),
                                          if (hasFilters)
                                            TextButton(
                                                onPressed: _clearFilters,
                                                child: const Text(
                                                    'Clear filters')),
                                        ]),
                                    if (error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Text(
                                              'Could not refresh availability. $error',
                                              style: const TextStyle(
                                                  color: AppTheme.errorColor))),
                                    if (state.isLoading || _refreshing)
                                      const LinearProgressIndicator(),
                                  ]))),
                          if (rooms.isEmpty)
                            SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                              hasFilters
                                                  ? CupertinoIcons.search
                                                  : CupertinoIcons.bed_double,
                                              size: 40,
                                              color:
                                                  AppTheme.secondaryTextColor),
                                          const SizedBox(height: 16),
                                          Text(
                                              hasFilters
                                                  ? 'No matching rooms'
                                                  : 'No rooms available right now',
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge),
                                          const SizedBox(height: 8),
                                          Text(
                                              hasFilters
                                                  ? 'Try another building or bed type.'
                                                  : 'Rooms with vacant, unreserved beds appear here.',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                  color: AppTheme
                                                      .secondaryTextColor)),
                                          if (hasFilters)
                                            TextButton(
                                                onPressed: _clearFilters,
                                                child: const Text(
                                                    'Show all available rooms')),
                                        ]))),
                          SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                              sliver: SliverList.builder(
                                  itemCount: rooms.length,
                                  itemBuilder: (context, index) => _roomCard(
                                      state,
                                      rooms[index],
                                      matchingBeds(rooms[index])))),
                        ],
                      )),
                ));
              },
            )),
      );

  Widget _roomCard(ManagementLoaded data, RoomModel room, List<BedModel> beds) {
    final building = data.buildings
        .where((building) => building.buildingId == room.buildingId)
        .firstOrNull;
    return Container(
      key: ValueKey('available-room-${room.roomId}'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE4E7EB))),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(building?.buildingName ?? room.buildingId,
                    style: const TextStyle(
                        color: AppTheme.secondaryTextColor, fontSize: 13)),
                const SizedBox(height: 6),
                Text(room.displayName(data.rooms),
                    style: const TextStyle(
                        color: AppTheme.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEAF6F2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        '${beds.length} ${beds.length == 1 ? 'bed' : 'beds'} available',
                        style: const TextStyle(
                            color: Color(0xFF09634E),
                            fontWeight: FontWeight.w600))),
                const SizedBox(height: 14),
                for (final type in BedType.values)
                  if (beds.any((bed) => bed.bedType == type))
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(spacing: 8, runSpacing: 4, children: [
                          Text(
                              '${beds.where((bed) => bed.bedType == type).length} ${type.name}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              'AED ${(type == BedType.lower ? room.lowerBedRent : room.upperBedRent).toStringAsFixed(0)} / month',
                              style: const TextStyle(
                                  color: AppTheme.secondaryTextColor)),
                        ])),
              ],
            )),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                    onPressed: () => openRoomShare(context, room),
                    icon: const Icon(CupertinoIcons.square_arrow_up, size: 18),
                    label: Text(room.media.isEmpty
                        ? 'Share room details'
                        : 'Share room and media')))),
        ExpansionTile(
          key: PageStorageKey('available-beds-${room.roomId}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          shape: const Border(),
          collapsedShape: const Border(),
          title: const Text('Choose a bed',
              style: TextStyle(
                  color: AppTheme.textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          children: [for (final bed in beds) _bedActions(data, room, bed)],
        ),
      ]),
    );
  }

  Widget _bedActions(ManagementLoaded data, RoomModel room, BedModel bed) {
    final building = data.buildings
        .where((building) => building.buildingId == room.buildingId)
        .firstOrNull;
    final number = data.beds
            .where((other) =>
                other.roomId == room.roomId && other.bedType == bed.bedType)
            .toList()
            .indexOf(bed) +
        1;
    final rent =
        bed.bedType == BedType.lower ? room.lowerBedRent : room.upperBedRent;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEEF0F2)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${bed.bedType == BedType.lower ? 'Lower' : 'Upper'} bed $number',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.event_available_outlined, size: 18),
                  label: const Text('Book'),
                  onPressed: bed.bedId == null || bed.bedId!.isEmpty
                      ? null
                      : () => showBookingDialog(context, bedId: bed.bedId)),
              OutlinedButton.icon(
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add tenant'),
                  onPressed: bed.bedId == null || bed.bedId!.isEmpty
                      ? null
                      : () => TenantsManagementScreen.showAddTenantDialog(
                          context,
                          preSelectedBuildingId: room.buildingId,
                          preSelectedRoomId: room.roomId,
                          preSelectedBedId: bed.bedId,
                          preSelectedRentAmount: rent)),
              IconButton(
                  tooltip: 'Share vacancy',
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  icon: const Icon(CupertinoIcons.square_arrow_up, size: 20),
                  onPressed: () => showRoomShareDraft(context,
                      media: room.media,
                      message: StatusMessageService.vacancy(
                          building: building?.buildingName ?? room.buildingId,
                          address: building?.address ?? '',
                          room: room.displayName(data.rooms),
                          bedType:
                              bed.bedType == BedType.lower ? 'Lower' : 'Upper',
                          rent: rent))),
            ]),
      ]),
    );
  }
}
