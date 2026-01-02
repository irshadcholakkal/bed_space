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
        title: Text(
          'Manage Buildings',
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
            tooltip: 'Add Building',
            onPressed: () => _showAddBuildingDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementLoaded) {
            if (state.isLoading && state.buildings.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (state.error != null && state.buildings.isEmpty) {
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
                        context.read<ManagementBloc>().add(
                          const LoadBuildings(),
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

            if (state.buildings.isEmpty) {
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.softGrey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddBuildingDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Building'),
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
                context.read<ManagementBloc>().add(const LoadBuildings());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: state.buildings.length,
                itemBuilder: (context, index) {
                  final building = state.buildings[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: AppTheme.cardDecoration,
                    child: ListTile(
                      onTap: () => _showEditBuildingDialog(context, building),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
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
                              building.address,
                              style: const TextStyle(
                                color: AppTheme.secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Total Rooms: ${building.totalRooms}',
                              style: const TextStyle(
                                color: AppTheme.secondaryTextColor,
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

  void _showAddBuildingDialog(BuildContext context) {
    final managementBloc = context.read<ManagementBloc>();
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final roomsController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: const Text(
            'Add Building',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Building Name',

                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                ),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                ),
              ),
              TextField(
                controller: roomsController,
                decoration: const InputDecoration(
                  labelText: 'Total Rooms',
                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
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
                final building = BuildingModel(
                  buildingName: nameController.text,
                  address: addressController.text,
                  totalRooms: int.tryParse(roomsController.text) ?? 0,
                );
                managementBloc.add(AddBuilding(building));
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditBuildingDialog(BuildContext context, BuildingModel building) {
    final managementBloc = context.read<ManagementBloc>();
    final nameController = TextEditingController(text: building.buildingName);
    final addressController = TextEditingController(text: building.address);
    final roomsController = TextEditingController(
      text: building.totalRooms.toString(),
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
                'Edit Building',
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
                      _showDeleteConfirmation(context, building);
                    },
                  );
                },
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Building Name',
                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                ),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                ),
              ),
              TextField(
                controller: roomsController,
                decoration: const InputDecoration(
                  labelText: 'Total Rooms',
                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
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
                final updated = building.copyWith(
                  buildingName: nameController.text,
                  address: addressController.text,
                  totalRooms: int.tryParse(roomsController.text) ?? 0,
                );
                managementBloc.add(UpdateBuilding(updated));
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

  void _showDeleteConfirmation(BuildContext context, BuildingModel building) {
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
            'Delete Building?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Are you sure you want to delete ${building.buildingName}?',
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
                if (building.buildingId != null) {
                  managementBloc.add(DeleteBuilding(building.buildingId!));
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
