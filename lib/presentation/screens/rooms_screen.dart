import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/room/room_bloc.dart';
import '../blocs/management/management_bloc.dart' as management_bloc;
import '../theme/app_theme.dart';
import '../../data/models/bed_model.dart'; // Added
import 'rooms_management_screen.dart';
import 'tenants_management_screen.dart';

/// Rooms Screen
/// Shows buildings and rooms with vacancy status
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

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
              Icons.meeting_room_outlined,
              color: AppTheme.textColor,
            ), // Modern icon
            tooltip: 'Manage Rooms',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<management_bloc.ManagementBloc>(),
                    child: const RoomsManagementScreen(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.people_outline,
              color: AppTheme.textColor,
            ), // Modern icon
            tooltip: 'Manage Tenants',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<management_bloc.ManagementBloc>(),
                    child: const TenantsManagementScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          final buildings = state.buildings;
          final roomsByBuilding = state.roomsByBuilding;

          if (state is RoomLoading && buildings.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (state is RoomError && buildings.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
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
                      context.read<RoomBloc>().add(const RoomLoadRequested());
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
                    Icons.business_outlined,
                    size: 64,
                    color: AppTheme.softGrey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No buildings found',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: AppTheme.softGrey),
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
              padding: const EdgeInsets.all(24),
              itemCount: buildings.length,
              itemBuilder: (context, buildingIndex) {
                final building = buildings[buildingIndex];
                final rooms = roomsByBuilding[building.buildingId] ?? [];

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
                      initiallyExpanded: buildings.length == 1,
                      leading: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.business,
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
                              Padding(
                                padding: const EdgeInsets.all(24),
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
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  title: Text(
                                    'Room ${roomWithStats.room.roomNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: AppTheme.textColor,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Capacity: ${roomWithStats.room.totalCapacity} beds',
                                          style: const TextStyle(
                                            color: AppTheme.secondaryTextColor,
                                            fontSize: 13,
                                          ),
                                        ),
                                        if (roomWithStats.vacantLowerBeds > 0)
                                          Text(
                                            'Vacant Lower: ${roomWithStats.vacantLowerBeds}',
                                            style: const TextStyle(
                                              color: AppTheme.secondaryColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                        if (roomWithStats.vacantUpperBeds > 0)
                                          Text(
                                            'Vacant Upper: ${roomWithStats.vacantUpperBeds}',
                                            style: const TextStyle(
                                              color: AppTheme.secondaryColor,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  trailing: hasVacancy
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.secondaryColor
                                                .withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: const Text(
                                            'Available',
                                            style: TextStyle(
                                              color: AppTheme.secondaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline,
                                          color: AppTheme.softGrey,
                                        ),
                                  onTap: () =>
                                      _showRoomDetail(context, roomWithStats),
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
    );
  }

  void _showRoomDetail(BuildContext context, RoomWithStats roomWithStats) {
    final roomBloc = context.read<RoomBloc>();
    roomBloc.add(RoomDetailRequested(roomWithStats.room.roomId ?? ''));

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: roomBloc,
        child: BlocBuilder<RoomBloc, RoomState>(
          builder: (context, state) {
            final isLoading = state is RoomsLoaded && state.isDetailsLoading;
            final details = state is RoomsLoaded
                ? state.selectedRoomDetails
                : null;

            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Room ${roomWithStats.room.roomNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow(
                      'Capacity',
                      '${roomWithStats.room.totalCapacity}',
                    ),
                    const Divider(),
                    _detailRow(
                      'Lower Rent',
                      '₹${roomWithStats.room.lowerBedRent.toStringAsFixed(0)}',
                    ),
                    _detailRow(
                      'Upper Rent',
                      '₹${roomWithStats.room.upperBedRent.toStringAsFixed(0)}',
                    ),
                    _detailRow(
                      'Utility',
                      '₹${roomWithStats.room.utilityCostMonthly.toStringAsFixed(0)}/month',
                    ),
                    const Divider(),
                    const Text(
                      'Beds Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (details == null && !isLoading)
                      const Text(
                        'Failed to load bed details',
                        style: TextStyle(color: AppTheme.errorColor),
                      )
                    else if (details != null)
                      ...details.map(
                        (bedDetail) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bedDetail.bed.status == BedStatus.vacant
                                ? AppTheme.secondaryColor.withOpacity(0.05)
                                : AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  (bedDetail.bed.status == BedStatus.vacant
                                          ? AppTheme.secondaryColor
                                          : AppTheme.primaryColor)
                                      .withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                bedDetail.bed.bedType == BedType.lower
                                    ? Icons.south
                                    : Icons.north,
                                size: 16,
                                color: bedDetail.bed.status == BedStatus.vacant
                                    ? AppTheme.secondaryColor
                                    : AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${bedDetail.bed.bedType == BedType.lower ? "Lower" : "Upper"} Bed',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      bedDetail.bed.status == BedStatus.vacant
                                          ? 'Vacant'
                                          : 'Occupied by ${bedDetail.tenantName ?? "Unknown"}',
                                      style: TextStyle(
                                        color:
                                            bedDetail.bed.status ==
                                                BedStatus.vacant
                                            ? AppTheme.secondaryColor
                                            : AppTheme.textColor,
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
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'Fetching bed assignments...',
                            style: TextStyle(
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
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
