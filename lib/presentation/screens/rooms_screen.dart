import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/room/room_bloc.dart';
import '../theme/app_theme.dart';

/// Rooms Screen
/// Shows buildings and rooms with vacancy status
class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.door_front_door),
            tooltip: 'Manage Rooms',
            onPressed: () {
              Navigator.pushNamed(context, '/rooms-management');
            },
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Manage Tenants',
            onPressed: () {
              Navigator.pushNamed(context, '/tenants');
            },
          ),
        ],
      ),
      body: BlocBuilder<RoomBloc, RoomState>(
        builder: (context, state) {
          if (state is RoomLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is RoomError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
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
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is RoomsLoaded) {
            if (state.buildings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.business_outlined, size: 64, color: AppTheme.textColor),
                    const SizedBox(height: 16),
                    const Text(
                      'No buildings found',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.textColor,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<RoomBloc>().add(RoomLoadRequested());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.buildings.length,
                itemBuilder: (context, buildingIndex) {
                  final building = state.buildings[buildingIndex];
                  final rooms = state.roomsByBuilding[building.buildingId] ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      leading: const Icon(Icons.business, color: AppTheme.primaryColor),
                      title: Text(
                        building.buildingName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      subtitle: Text(
                        building.address,
                        style: const TextStyle(
                          color: AppTheme.textColor,
                          fontSize: 12,
                        ),
                      ),
                      children: rooms.isEmpty
                          ? [
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No rooms available',
                                  style: TextStyle(color: AppTheme.textColor),
                                ),
                              ),
                            ]
                          : rooms.map((roomWithStats) {
                              final hasVacancy = roomWithStats.vacantLowerBeds > 0 ||
                                  roomWithStats.vacantUpperBeds > 0;

                              return ListTile(
                                title: Text(
                                  'Room ${roomWithStats.room.roomNumber}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Capacity: ${roomWithStats.room.totalCapacity} beds',
                                      style: const TextStyle(color: AppTheme.textColor),
                                    ),
                                    if (roomWithStats.vacantLowerBeds > 0)
                                      Text(
                                        'Vacant Lower: ${roomWithStats.vacantLowerBeds}',
                                        style: const TextStyle(color: AppTheme.successColor),
                                      ),
                                    if (roomWithStats.vacantUpperBeds > 0)
                                      Text(
                                        'Vacant Upper: ${roomWithStats.vacantUpperBeds}',
                                        style: const TextStyle(color: AppTheme.successColor),
                                      ),
                                  ],
                                ),
                                trailing: hasVacancy
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppTheme.successColor.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'Available',
                                          style: TextStyle(
                                            color: AppTheme.textColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_circle,
                                        color: AppTheme.textColor,
                                      ),
                                onTap: () {
                                  context.read<RoomBloc>().add(
                                        RoomDetailRequested(
                                          roomWithStats.room.roomId ?? '',
                                        ),
                                      );
                                  // Navigate to room detail
                                  // For now, show a dialog
                                  _showRoomDetail(context, roomWithStats);
                                },
                              );
                            }).toList(),
                    ),
                  );
                },
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showRoomDetail(BuildContext context, roomWithStats) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Room ${roomWithStats.room.roomNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capacity: ${roomWithStats.room.totalCapacity}'),
            Text('Lower Beds: ${roomWithStats.room.lowerBedsCount}'),
            Text('Upper Beds: ${roomWithStats.room.upperBedsCount}'),
            Text('Vacant Lower: ${roomWithStats.vacantLowerBeds}'),
            Text('Vacant Upper: ${roomWithStats.vacantUpperBeds}'),
            Text('Lower Rent: ₹${roomWithStats.room.lowerBedRent.toStringAsFixed(0)}'),
            Text('Upper Rent: ₹${roomWithStats.room.upperBedRent.toStringAsFixed(0)}'),
            Text('Utility: ₹${roomWithStats.room.utilityCostMonthly.toStringAsFixed(0)}/month'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

