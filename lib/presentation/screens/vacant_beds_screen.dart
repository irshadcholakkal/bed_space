import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../theme/app_theme.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/building_model.dart';
import 'tenants_management_screen.dart';

class VacantBedsScreen extends StatelessWidget {
  const VacantBedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Available Beds',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementLoaded) {
            if (state.isLoading && state.beds.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }
            final vacantBeds = state.beds
                .where((b) => b.status == BedStatus.vacant)
                .toList();

            if (vacantBeds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.bed_outlined,
                      size: 64,
                      color: AppTheme.softGrey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No vacant beds available',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.softGrey,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: vacantBeds.length,
              itemBuilder: (context, index) {
                final bed = vacantBeds[index];

                // Find associated room and building
                final room = state.rooms.firstWhere(
                  (r) => r.roomId == bed.roomId,
                  orElse: () => RoomModel(
                    buildingId: '',
                    roomNumber: 'Unknown',
                    totalCapacity: 0,
                    lowerBedsCount: 0,
                    upperBedsCount: 0,
                    lowerBedRent: 0,
                    upperBedRent: 0,
                    utilityCostMonthly: 0,
                  ),
                );

                final building = state.buildings.firstWhere(
                  (b) => b.buildingId == room.buildingId,
                  orElse: () => BuildingModel(
                    buildingName: 'Unknown',
                    address: '',
                    totalRooms: 0,
                  ),
                );

                final rentAmount = bed.bedType == BedType.lower
                    ? room.lowerBedRent
                    : room.upperBedRent;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: AppTheme.cardDecoration,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        bed.bedType == BedType.lower
                            ? Icons.south
                            : Icons.north,
                        color: AppTheme.secondaryColor,
                      ),
                    ),
                    title: Text(
                      '${building.buildingName} - Room ${room.roomNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          '${bed.bedType == BedType.lower ? "Lower" : "Upper"} Bed',
                          style: const TextStyle(
                            color: AppTheme.secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rent: ₹${rentAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.person_add_outlined,
                      color: AppTheme.primaryColor,
                    ),
                    onTap: () {
                      TenantsManagementScreen.showAddTenantDialog(
                        context,
                        preSelectedBuildingId: building.buildingId,
                        preSelectedRoomId: room.roomId,
                        preSelectedBedId: bed.bedId,
                        preSelectedRentAmount: rentAmount,
                      );
                    },
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
