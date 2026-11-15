import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/room_model.dart';
import '../../data/repositories/management_repository.dart';
import '../blocs/management/management_bloc.dart';
import 'property_portfolio_screen.dart';
import 'room_occupancy_screen.dart';
import '../blocs/room/room_bloc.dart';
import '../theme/app_theme.dart';
import 'buildings_management_screen.dart';
import 'rooms_management_screen.dart';
import 'tenants_management_screen.dart';

enum _RoomFilter { all, available, unavailable, full, noBeds, rooms, subrooms }

class RoomsScreen extends StatefulWidget {
  final String? buildingId;
  final String? roomId;
  final String? period;
  const RoomsScreen({super.key, this.buildingId, this.roomId, this.period});
  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  static const _ink = AppTheme.textColor;
  static const _muted = AppTheme.secondaryTextColor;
  static const _paper = AppTheme.backgroundColor;
  final _search = TextEditingController();
  _RoomFilter _filter = _RoomFilter.all;
  final _expandedRooms = <String>{};

  Widget _roomCard(
      BuildContext context,
      RoomModel room,
      ManagementLoaded state,
      Map<String?, String> buildingNames,
      List<BedModel> Function(RoomModel) beds,
      int Function(RoomModel) vacant,
      {List<RoomModel> children = const []}) {
    final roomBeds = beds(room);
    final available = room.isAvailable(state.rooms) ? vacant(room) : 0;
    final lower = roomBeds
        .where((bed) =>
            bed.bedType == BedType.lower &&
            bed.status == BedStatus.vacant &&
            !state.reservedBedIds.contains(bed.bedId) &&
            !state.tenants
                .any((tenant) => tenant.active && tenant.bedId == bed.bedId))
        .length;
    final status = !room.isAvailable(state.rooms)
        ? 'Unavailable'
        : roomBeds.isEmpty
            ? 'No beds'
            : available > 0
                ? 'Available'
                : roomBeds.any((bed) =>
                        bed.status == BedStatus.vacant &&
                        state.reservedBedIds.contains(bed.bedId))
                    ? 'Reserved'
                    : 'Full';
    final color = available > 0 ? AppTheme.secondaryColor : _muted;
    final expanded = _expandedRooms.contains(room.roomId);
    return Padding(
      key: ValueKey('room-card-${room.roomId}'),
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.grey.withValues(alpha: .15))),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          InkWell(
            onTap: () => showRoomDetailBottomSheet(
                context,
                RoomWithStats(
                    room: room,
                    vacantLowerBeds: lower,
                    vacantUpperBeds:
                        available > lower ? available - lower : 0)),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(
                            room.isSubroom
                                ? CupertinoIcons.arrow_turn_down_right
                                : Icons.meeting_room_outlined,
                            color: _ink),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(room.displayName(state.rooms),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: _ink))),
                        if (children.isNotEmpty)
                          IconButton(
                              tooltip: expanded
                                  ? 'Collapse subrooms'
                                  : 'Expand subrooms',
                              onPressed: () => setState(() {
                                    if (expanded) {
                                      _expandedRooms.remove(room.roomId);
                                    } else {
                                      _expandedRooms.add(room.roomId!);
                                    }
                                  }),
                              icon: Icon(expanded
                                  ? Icons.expand_less
                                  : Icons.expand_more)),
                        PopupMenuButton<String>(
                            tooltip: 'Room options',
                            icon: const Icon(CupertinoIcons.ellipsis_vertical),
                            onSelected: (_) => context
                                    .push(Uri(path: '/rooms', queryParameters: {
                                  'building': room.buildingId,
                                  'room': room.roomId ?? '',
                                  if (widget.period != null)
                                    'period': widget.period!
                                }).toString()),
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'details', child: Text('Details'))
                                ]),
                      ]),
                      Text(buildingNames[room.buildingId] ?? 'Unknown building',
                          style: const TextStyle(color: _muted, fontSize: 12)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 16, runSpacing: 8, children: [
                        Text(status,
                            style: TextStyle(color: color, fontSize: 12)),
                        Text('$available / ${roomBeds.length} beds available',
                            style: TextStyle(color: color, fontSize: 12)),
                        Text(
                            '${roomBeds.where((bed) => bed.status == BedStatus.occupied).length} occupied',
                            style:
                                const TextStyle(color: _muted, fontSize: 12)),
                        if (roomBeds.any(
                            (bed) => state.reservedBedIds.contains(bed.bedId)))
                          Text(
                              '${roomBeds.where((bed) => state.reservedBedIds.contains(bed.bedId)).length} booked',
                              style:
                                  const TextStyle(color: _muted, fontSize: 12)),
                        if (available > 0)
                          Text(
                              '$lower lower | ${available - lower} upper vacant',
                              style:
                                  const TextStyle(color: _muted, fontSize: 12)),
                        if (children.isNotEmpty)
                          Text('${children.length} subrooms',
                              style:
                                  const TextStyle(color: _muted, fontSize: 12)),
                      ]),
                    ])),
          ),
          if (children.isNotEmpty && expanded)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Column(children: [
                  const Divider(),
                  for (final child in children)
                    _roomCard(
                        context, child, state, buildingNames, beds, vacant),
                ])),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId != null || widget.buildingId != null) {
      return PropertyPortfolioScreen(
          buildingId: widget.buildingId,
          roomId: widget.roomId,
          period: widget.period);
    }
    return Theme(
        data: AppTheme.theme,
        child: Scaffold(
            backgroundColor: _paper,
            appBar: AppBar(title: const Text('Rooms'), actions: [
              IconButton(
                  tooltip: 'Available rooms',
                  onPressed: () => context.push('/rooms/available'),
                  icon: const Icon(CupertinoIcons.bed_double)),
              PopupMenuButton<String>(
                tooltip: 'Add building, room or tenant',
                icon: const Icon(CupertinoIcons.ellipsis_vertical),
                onSelected: (action) {
                  switch (action) {
                    case 'bookings':
                      context.push('/bookings');
                    case 'building':
                      BuildingsManagementScreen.showAddBuildingDialog(context);
                    case 'room':
                      RoomsManagementScreen.showAddRoomDialog(context);
                    case 'tenant':
                      TenantsManagementScreen.showAddTenantDialog(context,
                          preSelectedBuildingId: widget.buildingId);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'bookings', child: Text('Bed bookings')),
                  PopupMenuItem(value: 'building', child: Text('Add Building')),
                  PopupMenuItem(value: 'room', child: Text('Add Rooms')),
                  PopupMenuItem(value: 'tenant', child: Text('Add Tenant')),
                ],
              ),
            ]),
            body: SafeArea(child: BlocBuilder<ManagementBloc, ManagementState>(
                builder: (context, state) {
              if (state is! ManagementLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.isLoading && state.rooms.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final buildingNames = {
                for (final building in state.buildings)
                  building.buildingId: building.buildingName
              };
              final reservedBedIds = state.reservedBedIds;
              final occupiedBedIds = state.tenants
                  .where((tenant) => tenant.active)
                  .map((tenant) => tenant.bedId)
                  .toSet();
              final bedsByRoom = <String, List<BedModel>>{};
              for (final bed in state.beds) {
                bedsByRoom.putIfAbsent(bed.roomId, () => []).add(bed);
              }
              List<BedModel> beds(RoomModel room) =>
                  bedsByRoom[room.roomId] ?? [];
              int vacant(RoomModel room) => beds(room)
                  .where((bed) =>
                      bed.status == BedStatus.vacant &&
                      !reservedBedIds.contains(bed.bedId) &&
                      !occupiedBedIds.contains(bed.bedId))
                  .length;
              bool matches(RoomModel room, _RoomFilter filter) =>
                  switch (filter) {
                    _RoomFilter.all => true,
                    _RoomFilter.available =>
                      room.isAvailable(state.rooms) && vacant(room) > 0,
                    _RoomFilter.unavailable => !room.isAvailable(state.rooms),
                    _RoomFilter.full => room.isAvailable(state.rooms) &&
                        beds(room).isNotEmpty &&
                        vacant(room) == 0,
                    _RoomFilter.noBeds => beds(room).isEmpty,
                    _RoomFilter.rooms => !room.isSubroom,
                    _RoomFilter.subrooms => room.isSubroom,
                  };
              final query = _search.text.trim().toLowerCase();
              final candidates = state.rooms.where((room) {
                if (widget.buildingId != null &&
                    room.buildingId != widget.buildingId) {
                  return false;
                }
                return query.isEmpty ||
                    '${room.displayName(state.rooms)} ${buildingNames[room.buildingId] ?? ''}'
                        .toLowerCase()
                        .contains(query);
              }).toList()
                ..sort((a, b) {
                  final building = (buildingNames[a.buildingId] ?? '')
                      .compareTo(buildingNames[b.buildingId] ?? '');
                  return building != 0
                      ? building
                      : a
                          .displayName(state.rooms)
                          .compareTo(b.displayName(state.rooms));
                });
              final filtered =
                  candidates.where((room) => matches(room, _filter)).toList();
              final visibleIds = filtered.map((room) => room.roomId).toSet();
              final cards = filtered
                  .where((room) =>
                      !room.isSubroom ||
                      !visibleIds.contains(room.parentRoomId))
                  .toList();
              final labels = <_RoomFilter, String>{
                _RoomFilter.all: 'All',
                _RoomFilter.available: 'Available',
                _RoomFilter.unavailable: 'Unavailable',
                _RoomFilter.full: 'Full',
                _RoomFilter.noBeds: 'No beds',
                _RoomFilter.rooms: 'Rooms',
                _RoomFilter.subrooms: 'Subrooms'
              };
              return Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 4, 20, 16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                            child: Text(
                                                widget.buildingId == null
                                                    ? 'All rooms'
                                                    : buildingNames[widget
                                                            .buildingId] ??
                                                        'Rooms',
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 24,
                                                    color: _ink))),
                                        IconButton(
                                            tooltip: 'Beds & availability',
                                            onPressed: () => context
                                                .push('/rooms/occupancy'),
                                            icon: const Icon(
                                                CupertinoIcons.bed_double)),
                                        IconButton(
                                            tooltip: 'Manage rooms',
                                            onPressed: () =>
                                                context.push('/rooms/manage'),
                                            icon: const Icon(
                                                CupertinoIcons.plus_circle)),
                                      ]),
                                      const SizedBox(height: 8),
                                      const Text(
                                          'Find a room, check its beds, and open its details.',
                                          style: TextStyle(
                                              color: _muted, height: 1.6)),
                                      const SizedBox(height: 20),
                                      TextField(
                                          controller: _search,
                                          onChanged: (_) => setState(() {}),
                                          decoration: InputDecoration(
                                              hintText:
                                                  'Search room, subroom or building',
                                              prefixIcon: const Icon(
                                                  CupertinoIcons.search),
                                              suffixIcon: _search
                                                      .text.isNotEmpty
                                                  ? IconButton(
                                                      tooltip: 'Clear search',
                                                      icon: const Icon(
                                                          CupertinoIcons.xmark),
                                                      onPressed: () => setState(
                                                          _search.clear))
                                                  : null,
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide: BorderSide(
                                                      color: Colors.grey
                                                          .withValues(
                                                              alpha: .2))))),
                                      const SizedBox(height: 14),
                                      SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(children: [
                                            for (final entry in labels.entries)
                                              Padding(
                                                  padding: const EdgeInsets.only(
                                                      right: 8),
                                                  child: ChoiceChip(
                                                      label: Text(
                                                          '${entry.value} (${candidates.where((room) => matches(room, entry.key)).length})'),
                                                      selected:
                                                          _filter == entry.key,
                                                      onSelected: (_) => setState(() =>
                                                          _filter = entry.key),
                                                      selectedColor:
                                                          AppTheme.primaryColor,
                                                      backgroundColor:
                                                          Colors.white,
                                                      showCheckmark: false,
                                                      labelStyle: TextStyle(
                                                          color:
                                                              _filter == entry.key
                                                                  ? Colors.white
                                                                  : _ink),
                                                      shape:
                                                          const StadiumBorder(),
                                                      side: BorderSide(
                                                          color: Colors.grey
                                                              .withValues(alpha: .2)))),
                                          ])),
                                      const SizedBox(height: 12),
                                      Text(
                                          '${filtered.length} of ${candidates.length} spaces',
                                          style: const TextStyle(
                                              color: _muted, fontSize: 12)),
                                      if (state.error != null)
                                        Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Text(
                                                'Could not refresh rooms: ${state.error}',
                                                style: const TextStyle(
                                                    color: Colors.red))),
                                    ])),
                            if (state.isLoading)
                              const LinearProgressIndicator(minHeight: 2),
                            Expanded(
                                child: RefreshIndicator(
                                    onRefresh: () => context
                                        .read<ManagementRepository>()
                                        .triggerSync(),
                                    child: filtered.isEmpty
                                        ? ListView(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            padding: const EdgeInsets.all(32),
                                            children: [
                                                const Icon(
                                                    CupertinoIcons.search,
                                                    size: 40,
                                                    color: _muted),
                                                const SizedBox(height: 16),
                                                Text(
                                                    state.rooms.isEmpty
                                                        ? 'No rooms yet'
                                                        : 'No matching rooms',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                const SizedBox(height: 8),
                                                Text(
                                                    state.rooms.isEmpty
                                                        ? 'Add a room to start managing your spaces.'
                                                        : 'Try another search or availability filter.',
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        color: _muted,
                                                        height: 1.6)),
                                                TextButton(
                                                    onPressed: () {
                                                      if (state.rooms.isEmpty) {
                                                        context.push(
                                                            '/rooms/manage');
                                                      } else {
                                                        setState(() {
                                                          _search.clear();
                                                          _filter =
                                                              _RoomFilter.all;
                                                        });
                                                      }
                                                    },
                                                    child: Text(
                                                        state.rooms.isEmpty
                                                            ? 'Add room'
                                                            : 'Reset filters')),
                                              ])
                                        : ListView.builder(
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            padding: const EdgeInsets.fromLTRB(
                                                20, 0, 20, 24),
                                            itemCount: cards.length,
                                            itemBuilder: (context, index) {
                                              final room = cards[index];
                                              return _roomCard(
                                                  context,
                                                  room,
                                                  state,
                                                  buildingNames,
                                                  beds,
                                                  vacant,
                                                  children: filtered
                                                      .where((child) =>
                                                          room.roomId != null &&
                                                          child.parentRoomId ==
                                                              room.roomId &&
                                                          child.buildingId ==
                                                              room.buildingId)
                                                      .toList());
                                            }))),
                          ])));
            }))));
  }
}
