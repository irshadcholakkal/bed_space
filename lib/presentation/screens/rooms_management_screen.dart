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
        title: const Text('Rooms'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRoomDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementInitial) {
            context.read<ManagementBloc>().add(const LoadRooms());
            context.read<ManagementBloc>().add(const LoadBuildings());
          }

          if (state is ManagementLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is ManagementError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: 16),
                  Text('Error: ${state.message}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ManagementBloc>().add(const LoadRooms());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is RoomsLoaded) {
            if (state.rooms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.door_front_door_outlined, size: 64, color: AppTheme.textColor),
                    const SizedBox(height: 16),
                    const Text('No rooms found'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRoomDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Room'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ManagementBloc>().add(const LoadRooms());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.rooms.length,
                itemBuilder: (context, index) {
                  final room = state.rooms[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.door_front_door, color: AppTheme.primaryColor),
                      title: Text(
                        'Room ${room.roomNumber}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Capacity: ${room.totalCapacity} beds'),
                          Text('Lower: ${room.lowerBedsCount} | Upper: ${room.upperBedsCount}'),
                          Text('Rent: Lower ₹${room.lowerBedRent.toStringAsFixed(0)} | Upper ₹${room.upperBedRent.toStringAsFixed(0)}'),
                          Text('Utility: ₹${room.utilityCostMonthly.toStringAsFixed(0)}/month'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: () => _showEditRoomDialog(context, room),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                            onPressed: () => _showDeleteConfirmation(context, room),
                          ),
                        ],
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
    // Load buildings first
    context.read<ManagementBloc>().add(const LoadBuildings());
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    final buildingIdController = TextEditingController();
    final roomNumberController = TextEditingController();
    final capacityController = TextEditingController(text: '2');
    final lowerBedsController = TextEditingController(text: '1');
    final upperBedsController = TextEditingController(text: '1');
    final lowerRentController = TextEditingController(text: '0');
    final upperRentController = TextEditingController(text: '0');
    final utilityController = TextEditingController(text: '0');

    String? selectedBuildingId;

    showDialog(
      context: context,
      builder: (context) => BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          List<BuildingModel> buildings = [];
          if (state is BuildingsLoaded) {
            buildings = state.buildings;
          }

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Add Room'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedBuildingId,
                      decoration: const InputDecoration(labelText: 'Building'),
                      items: buildings.map((b) => DropdownMenuItem(
                        value: b.buildingId,
                        child: Text(b.buildingName),
                      )).toList(),
                      onChanged: (value) => setState(() => selectedBuildingId = value),
                    ),
                    TextField(
                      controller: roomNumberController,
                      decoration: const InputDecoration(labelText: 'Room Number'),
                    ),
                    TextField(
                      controller: capacityController,
                      decoration: const InputDecoration(labelText: 'Total Capacity'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: lowerBedsController,
                      decoration: const InputDecoration(labelText: 'Lower Beds Count'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: upperBedsController,
                      decoration: const InputDecoration(labelText: 'Upper Beds Count'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: lowerRentController,
                      decoration: const InputDecoration(labelText: 'Lower Bed Rent'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: upperRentController,
                      decoration: const InputDecoration(labelText: 'Upper Bed Rent'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: utilityController,
                      decoration: const InputDecoration(labelText: 'Utility Cost (Monthly)'),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedBuildingId == null ? null : () {
                    final room = RoomModel(
                      buildingId: selectedBuildingId!,
                      roomNumber: roomNumberController.text,
                      totalCapacity: int.tryParse(capacityController.text) ?? 2,
                      lowerBedsCount: int.tryParse(lowerBedsController.text) ?? 1,
                      upperBedsCount: int.tryParse(upperBedsController.text) ?? 1,
                      lowerBedRent: double.tryParse(lowerRentController.text) ?? 0,
                      upperBedRent: double.tryParse(upperRentController.text) ?? 0,
                      utilityCostMonthly: double.tryParse(utilityController.text) ?? 0,
                    );
                    context.read<ManagementBloc>().add(AddRoom(room));
                    Navigator.pop(context);
                  },
                  child: const Text('Add'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditRoomDialog(BuildContext context, RoomModel room) {
    final roomNumberController = TextEditingController(text: room.roomNumber);
    final capacityController = TextEditingController(text: room.totalCapacity.toString());
    final lowerBedsController = TextEditingController(text: room.lowerBedsCount.toString());
    final upperBedsController = TextEditingController(text: room.upperBedsCount.toString());
    final lowerRentController = TextEditingController(text: room.lowerBedRent.toString());
    final upperRentController = TextEditingController(text: room.upperBedRent.toString());
    final utilityController = TextEditingController(text: room.utilityCostMonthly.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
              ),
              TextField(
                controller: capacityController,
                decoration: const InputDecoration(labelText: 'Total Capacity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: lowerBedsController,
                decoration: const InputDecoration(labelText: 'Lower Beds Count'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: upperBedsController,
                decoration: const InputDecoration(labelText: 'Upper Beds Count'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: lowerRentController,
                decoration: const InputDecoration(labelText: 'Lower Bed Rent'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: upperRentController,
                decoration: const InputDecoration(labelText: 'Upper Bed Rent'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: utilityController,
                decoration: const InputDecoration(labelText: 'Utility Cost (Monthly)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
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
                utilityCostMonthly: double.tryParse(utilityController.text) ?? 0,
              );
              context.read<ManagementBloc>().add(UpdateRoom(updated));
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, RoomModel room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room?'),
        content: Text('Are you sure you want to delete Room ${room.roomNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (room.roomId != null) {
                context.read<ManagementBloc>().add(DeleteRoom(room.roomId!));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

