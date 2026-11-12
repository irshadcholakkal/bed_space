import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/room/room_bloc.dart';
import '../theme/app_theme.dart';
import '../../data/models/bed_model.dart'; // Added

/// Rooms Screen
/// Shows buildings and rooms with vacancy status
class RoomOccupancyScreen extends StatefulWidget {
  const RoomOccupancyScreen({super.key});

  @override
  State<RoomOccupancyScreen> createState() => _RoomOccupancyScreenState();
}

class _RoomOccupancyScreenState extends State<RoomOccupancyScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Rooms',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textColor,
                fontWeight: FontWeight.bold,
              ),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.rectangle_split_3x1,
              color: AppTheme.textColor,
            ),
            tooltip: 'Manage Rooms',
            onPressed: () {
              context.push('/rooms/manage');
            },
          ),
          IconButton(
            icon:
                const Icon(CupertinoIcons.person_2, color: AppTheme.textColor),
            tooltip: 'Manage Tenants',
            onPressed: () {
              context.push('/tenants');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search by building or room...',
                  prefixIcon: const Icon(
                    CupertinoIcons.search,
                    color: AppTheme.softGrey,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            CupertinoIcons.xmark,
                            color: AppTheme.softGrey,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 15,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<RoomBloc, RoomState>(
              builder: (context, state) {
                final buildings = state.buildings;
                final roomsByBuilding = state.roomsByBuilding;
                final allRooms = roomsByBuilding.values
                    .expand((rooms) => rooms)
                    .map((item) => item.room)
                    .toList();

                if (state is RoomLoading && buildings.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    ),
                  );
                }

                if (state is RoomError && buildings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.exclamationmark_circle,
                          size: 64,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error: ${state.message}',
                          style: const TextStyle(color: AppTheme.textColor),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            context.read<RoomBloc>().add(
                                  const RoomLoadRequested(),
                                );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (buildings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.building_2_fill,
                          size: 64,
                          color: AppTheme.softGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No buildings found',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppTheme.softGrey),
                        ),
                      ],
                    ),
                  );
                }

                // Filter logic
                final filteredBuildings = buildings.where((building) {
                  if (_searchQuery.isEmpty) return true;

                  final nameMatch = building.buildingName
                      .toLowerCase()
                      .contains(_searchQuery);
                  final addressMatch = building.address.toLowerCase().contains(
                        _searchQuery,
                      );

                  if (nameMatch || addressMatch) return true;

                  // Check if any room in this building matches
                  final rooms = roomsByBuilding[building.buildingId] ?? [];
                  return rooms.any(
                    (r) => r.room
                        .displayName(allRooms)
                        .toLowerCase()
                        .contains(_searchQuery),
                  );
                }).toList();

                if (filteredBuildings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          CupertinoIcons.search,
                          size: 64,
                          color: AppTheme.softGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matches found',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(color: AppTheme.softGrey),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  color: AppTheme.primaryColor,
                  onRefresh: () async {
                    context.read<RoomBloc>().add(RoomLoadRequested());
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: filteredBuildings.length,
                    itemBuilder: (context, buildingIndex) {
                      final building = filteredBuildings[buildingIndex];
                      var rooms = roomsByBuilding[building.buildingId] ?? [];

                      // If searching, filter rooms too if the building itself wasn't the only match
                      if (_searchQuery.isNotEmpty) {
                        final buildingMatch =
                            building.buildingName.toLowerCase().contains(
                                      _searchQuery,
                                    ) ||
                                building.address.toLowerCase().contains(
                                      _searchQuery,
                                    );

                        if (!buildingMatch) {
                          rooms = rooms
                              .where(
                                (r) => r.room
                                    .displayName(allRooms)
                                    .toLowerCase()
                                    .contains(
                                      _searchQuery,
                                    ),
                              )
                              .toList();
                        }
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: AppTheme.cardDecoration,
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            iconColor: AppTheme.primaryColor,
                            collapsedIconColor: AppTheme.textColor,
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 8,
                            ),
                            initiallyExpanded: _searchQuery.isNotEmpty ||
                                buildings.length == 1,
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                CupertinoIcons.building_2_fill,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Text(
                              building.buildingName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppTheme.textColor,
                              ),
                            ),
                            subtitle: Text(
                              building.address,
                              style: const TextStyle(
                                color: AppTheme.secondaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                            children: rooms.isEmpty
                                ? [
                                    const Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                        'No rooms available',
                                        style: TextStyle(
                                          color: AppTheme.secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                  ]
                                : rooms.map((roomWithStats) {
                                    final hasVacancy =
                                        roomWithStats.vacantLowerBeds > 0 ||
                                            roomWithStats.vacantUpperBeds > 0;

                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.grey
                                                .withValues(alpha: 0.1),
                                          ),
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 8,
                                        ),
                                        title: Text(
                                          roomWithStats.room
                                              .displayName(allRooms),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                            color: AppTheme.textColor,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Capacity: ${roomWithStats.room.totalCapacity} beds',
                                                style: const TextStyle(
                                                  color: AppTheme
                                                      .secondaryTextColor,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              if (roomWithStats
                                                      .vacantLowerBeds >
                                                  0)
                                                Text(
                                                  'Vacant Lower: ${roomWithStats.vacantLowerBeds}',
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.secondaryColor,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              if (roomWithStats
                                                      .vacantUpperBeds >
                                                  0)
                                                Text(
                                                  'Vacant Upper: ${roomWithStats.vacantUpperBeds}',
                                                  style: const TextStyle(
                                                    color:
                                                        AppTheme.secondaryColor,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        trailing: hasVacancy
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.secondaryColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'Available',
                                                  style: TextStyle(
                                                    color:
                                                        AppTheme.secondaryColor,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              )
                                            : const Icon(
                                                CupertinoIcons.checkmark_circle,
                                                color: AppTheme.softGrey,
                                              ),
                                        onTap: () => widget._showRoomDetail(
                                          context,
                                          roomWithStats,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

extension on RoomOccupancyScreen {
  void _showRoomDetail(BuildContext context, RoomWithStats roomWithStats) {
    final roomBloc = context.read<RoomBloc>();
    roomBloc.add(RoomDetailRequested(roomWithStats.room.roomId ?? ''));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: roomBloc,
        child: BlocBuilder<RoomBloc, RoomState>(
          builder: (context, state) {
            final isLoading = state is RoomsLoaded && state.isDetailsLoading;
            final details =
                state is RoomsLoaded ? state.selectedRoomDetails : null;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                          child: Text(
                        roomWithStats.room.displayName(state
                            .roomsByBuilding.values
                            .expand((rooms) => rooms)
                            .map((item) => item.room)),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      )),
                      if (isLoading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _detailRow(
                    'Total Capacity',
                    '${roomWithStats.room.totalCapacity} Beds',
                  ),
                  _detailRow(
                    'Lower Bed Rent',
                    'د.إ${roomWithStats.room.lowerBedRent.toStringAsFixed(0)}',
                  ),
                  _detailRow(
                    'Upper Bed Rent',
                    'د.إ${roomWithStats.room.upperBedRent.toStringAsFixed(0)}',
                  ),
                  const Divider(height: 32),
                  const Text(
                    'Bed Availability',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (details == null && !isLoading)
                    const Center(
                      child: Text(
                        'Failed to load bed details',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                    )
                  else if (details != null)
                    ...details.map(
                      (bedDetail) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bedDetail.bed.status == BedStatus.vacant
                              ? AppTheme.secondaryColor.withValues(alpha: 0.05)
                              : AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: (bedDetail.bed.status == BedStatus.vacant
                                    ? AppTheme.secondaryColor
                                    : AppTheme.primaryColor)
                                .withValues(alpha: 0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (bedDetail.bed.status == BedStatus.vacant
                                        ? AppTheme.secondaryColor
                                        : AppTheme.primaryColor)
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                bedDetail.bed.bedType == BedType.lower
                                    ? CupertinoIcons.arrow_down
                                    : CupertinoIcons.arrow_up,
                                size: 16,
                                color: bedDetail.bed.status == BedStatus.vacant
                                    ? AppTheme.secondaryColor
                                    : AppTheme.primaryColor,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${bedDetail.bed.bedType == BedType.lower ? "Lower" : "Upper"} Bed',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    bedDetail.bed.status == BedStatus.vacant
                                        ? 'Available'
                                        : 'Occupied by ${bedDetail.tenantName ?? "Unknown"}',
                                    style: TextStyle(
                                      color: bedDetail.bed.status ==
                                              BedStatus.vacant
                                          ? AppTheme.secondaryColor
                                          : AppTheme.secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppTheme.secondaryTextColor),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }
}
