import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../../data/models/room_model.dart';
import '../../data/models/building_model.dart';
import '../theme/app_theme.dart';

class RoomsManagementScreen extends StatelessWidget {
  const RoomsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Manage Rooms',
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
              Icons.add_circle_outline,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'Add Room',
            onPressed: () => _showAddRoomDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementLoaded) {
            if (state.isLoading && state.rooms.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (state.error != null && state.rooms.isEmpty) {
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
                      'Error: ${state.error}',
                      style: const TextStyle(color: AppTheme.textColor),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        context.read<ManagementBloc>().add(const LoadRooms());
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

            if (state.rooms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 64,
                      color: AppTheme.softGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No rooms found',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.softGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRoomDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Room'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                context.read<ManagementBloc>().add(const LoadRooms());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: state.rooms.length,
                itemBuilder: (context, index) {
                  final room = state.rooms[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: AppTheme.cardDecoration,
                    child: ListTile(
                      onTap: () => _showEditRoomDialog(context, room),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.door_front_door,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      title: Text(
                        'Room ${room.roomNumber}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.textColor,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Capacity: ${room.totalCapacity} beds',
                              style: const TextStyle(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Lower: ${room.lowerBedsCount} | Upper: ${room.upperBedsCount}',
                              style: const TextStyle(
                                color: AppTheme.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rent: L ₹${room.lowerBedRent.toStringAsFixed(0)} | U ₹${room.upperBedRent.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: AppTheme.textColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                     
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

  void _showAddRoomDialog(BuildContext context) async {
    final managementBloc = context.read<ManagementBloc>();
    // Load buildings first
    managementBloc.add(const LoadBuildings());

    // Check if context is still valid
    if (!context.mounted) return;

    final roomNumberController = TextEditingController();
    final capacityController = TextEditingController(text: '2');
    final lowerBedsController = TextEditingController(text: '1');
    final upperBedsController = TextEditingController(text: '1');
    final lowerRentController = TextEditingController(text: '650');
    final upperRentController = TextEditingController(text: '600');
    final utilityController = TextEditingController(text: '0');

    String? selectedBuildingId;

    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: BlocBuilder<ManagementBloc, ManagementState>(
          builder: (context, state) {
            List<BuildingModel> buildings = [];
            if (state is ManagementLoaded) {
              buildings = state.buildings;
            }

            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                title: const Text(
                  'Add Room',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    spacing: 10,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: selectedBuildingId,
                        decoration: const InputDecoration(
                          labelText: 'Building',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        items: buildings
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.buildingId,
                                child: Text(b.buildingName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedBuildingId = value),
                      ),
                      TextField(
                        controller: roomNumberController,
                        decoration: const InputDecoration(
                          labelText: 'Room Number',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                      ),
                      TextField(
                        controller: capacityController,
                        decoration: const InputDecoration(
                          labelText: 'Total Capacity',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: lowerBedsController,
                        decoration: const InputDecoration(
                          labelText: 'Lower Beds Count',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: upperBedsController,
                        decoration: const InputDecoration(
                          labelText: 'Upper Beds Count',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: lowerRentController,
                        decoration: const InputDecoration(
                          labelText: 'Lower Bed Rent',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: upperRentController,
                        decoration: const InputDecoration(
                          labelText: 'Upper Bed Rent',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      TextField(
                        controller: utilityController,
                        decoration: const InputDecoration(
                          labelText: 'Utility Cost (Monthly)',
                          labelStyle: TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppTheme.secondaryTextColor),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: selectedBuildingId == null
                        ? null
                        : () {
                            final room = RoomModel(
                              buildingId: selectedBuildingId!,
                              roomNumber: roomNumberController.text,
                              totalCapacity:
                                  int.tryParse(capacityController.text) ?? 2,
                              lowerBedsCount:
                                  int.tryParse(lowerBedsController.text) ?? 1,
                              upperBedsCount:
                                  int.tryParse(upperBedsController.text) ?? 1,
                              lowerBedRent:
                                  double.tryParse(lowerRentController.text) ??
                                  0,
                              upperBedRent:
                                  double.tryParse(upperRentController.text) ??
                                  0,
                              utilityCostMonthly:
                                  double.tryParse(utilityController.text) ?? 0,
                            );
                            managementBloc.add(AddRoom(room));
                            Navigator.pop(context);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                    child: const Text('Add'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditRoomDialog(BuildContext context, RoomModel room) {
    final managementBloc = context.read<ManagementBloc>();
    final roomNumberController = TextEditingController(text: room.roomNumber);
    final capacityController = TextEditingController(
      text: room.totalCapacity.toString(),
    );
    final lowerBedsController = TextEditingController(
      text: room.lowerBedsCount.toString(),
    );
    final upperBedsController = TextEditingController(
      text: room.upperBedsCount.toString(),
    );
    final lowerRentController = TextEditingController(
      text: room.lowerBedRent.toString(),
    );
    final upperRentController = TextEditingController(
      text: room.upperBedRent.toString(),
    );
    final utilityController = TextEditingController(
      text: room.utilityCostMonthly.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Edit Room',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

                 Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppTheme.errorColor,
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }
                                _showDeleteConfirmation(context, room);
                    },
                  );
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              spacing: 10,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: roomNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                ),
                TextField(
                  controller: capacityController,
                  decoration: const InputDecoration(
                    labelText: 'Total Capacity',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: lowerBedsController,
                  decoration: const InputDecoration(
                    labelText: 'Lower Beds Count',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: upperBedsController,
                  decoration: const InputDecoration(
                    labelText: 'Upper Beds Count',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: lowerRentController,
                  decoration: const InputDecoration(
                    labelText: 'Lower Bed Rent',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: upperRentController,
                  decoration: const InputDecoration(
                    labelText: 'Upper Bed Rent',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: utilityController,
                  decoration: const InputDecoration(
                    labelText: 'Utility Cost (Monthly)',
                    labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = RoomModel(
                  roomId: room.roomId,
                  buildingId: room.buildingId,
                  roomNumber: roomNumberController.text,
                  totalCapacity: int.tryParse(capacityController.text) ?? 2,
                  lowerBedsCount: int.tryParse(lowerBedsController.text) ?? 1,
                  upperBedsCount: int.tryParse(upperBedsController.text) ?? 1,
                  lowerBedRent: double.tryParse(lowerRentController.text) ?? 0,
                  upperBedRent: double.tryParse(upperRentController.text) ?? 0,
                  utilityCostMonthly:
                      double.tryParse(utilityController.text) ?? 0,
                );
                managementBloc.add(UpdateRoom(updated));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, RoomModel room) {
    final managementBloc = context.read<ManagementBloc>();
    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text(
            'Delete Room?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete Room ${room.roomNumber}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (room.roomId != null) {
                  managementBloc.add(DeleteRoom(room.roomId!));
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}
