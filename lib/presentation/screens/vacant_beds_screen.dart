import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../theme/app_theme.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/building_model.dart';
import 'tenants_management_screen.dart';

class VacantBedsScreen extends StatefulWidget {
  const VacantBedsScreen({super.key});

  @override
  State<VacantBedsScreen> createState() => _VacantBedsScreenState();
}

class _VacantBedsScreenState extends State<VacantBedsScreen> {
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
                    color: Colors.black.withOpacity(0.05),
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
                    Icons.search,
                    color: AppTheme.softGrey,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
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
            child: BlocBuilder<ManagementBloc, ManagementState>(
              builder: (context, state) {
                if (state is ManagementLoaded) {
                  if (state.isLoading && state.beds.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  // Find vacant beds and filter them
                  final vacantBedsWithInfo = state.beds
                      .where((b) => b.status == BedStatus.vacant)
                      .map((bed) {
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

                        return {'bed': bed, 'room': room, 'building': building};
                      })
                      .where((info) {
                        if (_searchQuery.isEmpty) return true;

                        final building = info['building'] as BuildingModel;
                        final room = info['room'] as RoomModel;
                        final bed = info['bed'] as BedModel;
                        final bedTypeStr = bed.bedType == BedType.lower
                            ? 'lower'
                            : 'upper';

                        return building.buildingName.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            room.roomNumber.toLowerCase().contains(
                              _searchQuery,
                            ) ||
                            bedTypeStr.contains(_searchQuery);
                      })
                      .toList();

                  if (vacantBedsWithInfo.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.bed_outlined
                                : Icons.search_off,
                            size: 64,
                            color: AppTheme.softGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No vacant beds available'
                                : 'No matches found',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(color: AppTheme.softGrey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: vacantBedsWithInfo.length,
                    itemBuilder: (context, index) {
                      final info = vacantBedsWithInfo[index];
                      final bed = info['bed'] as BedModel;
                      final room = info['room'] as RoomModel;
                      final building = info['building'] as BuildingModel;

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
          ),
        ],
      ),
    );
  }
}
