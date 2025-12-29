import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../../data/models/building_model.dart';
import '../theme/app_theme.dart';

class BuildingsManagementScreen extends StatelessWidget {
  const BuildingsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Buildings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddBuildingDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementInitial) {
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
                      context.read<ManagementBloc>().add(const LoadBuildings());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is BuildingsLoaded) {
            if (state.buildings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.business_outlined, size: 64, color: AppTheme.textColor),
                    const SizedBox(height: 16),
                    const Text('No buildings found'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddBuildingDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Building'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ManagementBloc>().add(const LoadBuildings());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.buildings.length,
                itemBuilder: (context, index) {
                  final building = state.buildings[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.business, color: AppTheme.primaryColor),
                      title: Text(
                        building.buildingName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(building.address),
                          Text('Rooms: ${building.totalRooms}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: () => _showEditBuildingDialog(context, building),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                            onPressed: () => _showDeleteConfirmation(context, building),
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

  void _showAddBuildingDialog(BuildContext context) {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final roomsController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Building Name'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextField(
              controller: roomsController,
              decoration: const InputDecoration(labelText: 'Total Rooms'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final building = BuildingModel(
                buildingName: nameController.text,
                address: addressController.text,
                totalRooms: int.tryParse(roomsController.text) ?? 0,
              );
              context.read<ManagementBloc>().add(AddBuilding(building));
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditBuildingDialog(BuildContext context, BuildingModel building) {
    final nameController = TextEditingController(text: building.buildingName);
    final addressController = TextEditingController(text: building.address);
    final roomsController = TextEditingController(text: building.totalRooms.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Building'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Building Name'),
            ),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
            TextField(
              controller: roomsController,
              decoration: const InputDecoration(labelText: 'Total Rooms'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updated = building.copyWith(
                buildingName: nameController.text,
                address: addressController.text,
                totalRooms: int.tryParse(roomsController.text) ?? 0,
              );
              context.read<ManagementBloc>().add(UpdateBuilding(updated));
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, BuildingModel building) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Building?'),
        content: Text('Are you sure you want to delete ${building.buildingName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (building.buildingId != null) {
                context.read<ManagementBloc>().add(DeleteBuilding(building.buildingId!));
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

