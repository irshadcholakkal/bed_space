import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../../data/models/room_model.dart';
import '../../data/models/building_model.dart';
import '../theme/app_theme.dart';

class RoomsManagementScreen extends StatefulWidget {
  const RoomsManagementScreen({super.key});

  @override
  State<RoomsManagementScreen> createState() => _RoomsManagementScreenState();
}

class _RoomsManagementScreenState extends State<RoomsManagementScreen> {
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
            final filteredRooms = state.rooms.where((room) {
              final query = _searchQuery.toLowerCase();
              final roomNo = room.displayName(state.rooms).toLowerCase();
              // Also try to find the building name if possible
              final buildingName = state.buildings
                  .firstWhere((b) => b.buildingId == room.buildingId,
                      orElse: () => BuildingModel(
                          buildingId: '',
                          buildingName: '',
                          address: '',
                          totalRooms: 0))
                  .buildingName
                  .toLowerCase();

              return roomNo.contains(query) || buildingName.contains(query);
            }).toList()
              ..sort((a, b) => a
                  .displayName(state.rooms)
                  .compareTo(b.displayName(state.rooms)));

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

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                          _searchQuery = value;
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
                  child: state.rooms.isEmpty
                      ? Center(
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
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
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
                        )
                      : filteredRooms.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: AppTheme.softGrey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No matching rooms',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: AppTheme.softGrey,
                                        ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              color: AppTheme.primaryColor,
                              onRefresh: () async {
                                context
                                    .read<ManagementBloc>()
                                    .add(const LoadRooms());
                              },
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 0, 24, 24),
                                itemCount: filteredRooms.length,
                                itemBuilder: (context, index) {
                                  final room = filteredRooms[index];
                                  final buildingName = state.buildings
                                      .firstWhere(
                                          (b) =>
                                              b.buildingId == room.buildingId,
                                          orElse: () => BuildingModel(
                                              buildingId: '',
                                              buildingName: 'Unknown',
                                              address: '',
                                              totalRooms: 0))
                                      .buildingName;

                                  return Container(
                                    margin: EdgeInsets.only(
                                        bottom: 16,
                                        left: room.isSubroom ? 20 : 0),
                                    decoration: AppTheme.cardDecoration,
                                    child: Material(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      child: ListTile(
                                        onTap: () {
                                          context.push(
                                              '/rooms/${Uri.encodeComponent(room.roomId ?? '')}/expenses');
                                        },

                                        //  => _showEditRoomDialog(context, room),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.door_front_door,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                        title: Text(
                                          room.displayName(state.rooms),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppTheme.textColor,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (!room.isSubroom &&
                                                  state.rooms.any((child) =>
                                                      child.parentRoomId ==
                                                      room.roomId))
                                                Text(
                                                    '${state.rooms.where((child) => child.parentRoomId == room.roomId).length} subrooms'),
                                              Text(
                                                'Building: $buildingName',
                                                style: const TextStyle(
                                                  color: AppTheme
                                                      .secondaryTextColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Capacity: ${room.totalCapacity} beds',
                                                style: const TextStyle(
                                                  color: AppTheme
                                                      .secondaryTextColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Lower: ${room.lowerBedsCount} | Upper: ${room.upperBedsCount}',
                                                style: const TextStyle(
                                                  color: AppTheme
                                                      .secondaryTextColor,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Rent: L د.إ${room.lowerBedRent.toStringAsFixed(0)} | U د.إ${room.upperBedRent.toStringAsFixed(0)}',
                                                style: const TextStyle(
                                                  color: AppTheme.textColor,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        trailing: room.isSubroom
                                            ? null
                                            : IconButton(
                                                icon: const Icon(
                                                    Icons.add_home_outlined),
                                                tooltip: 'Add Subroom',
                                                onPressed: () =>
                                                    _showAddRoomDialog(context,
                                                        parentRoom: room),
                                              ),
                                        // trailing: IconButton(
                                        //   icon: const Icon(
                                        //     Icons.account_balance_wallet_outlined,
                                        //     color: AppTheme.primaryColor,
                                        //   ),
                                        //   tooltip: 'Finance & Expenses',
                                        //   onPressed: () {
                                        //     final bloc = context.read<ManagementBloc>();
                                        //     Navigator.push(
                                        //       context,
                                        //       MaterialPageRoute(
                                        //         builder: (context) => BlocProvider.value(
                                        //           value: bloc,
                                        //           child: RoomExpensesScreen(room: room),
                                        //         ),
                                        //       ),
                                        //     );
                                        //   },
                                        // ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showAddRoomDialog(BuildContext context, {RoomModel? parentRoom}) async {
    final managementBloc = context.read<ManagementBloc>();
    managementBloc.add(const LoadBuildings());

    if (!context.mounted) return;

    final roomNumberController = TextEditingController();
    final capacityController = TextEditingController(text: '2');
    final lowerBedsController = TextEditingController(text: '1');
    final upperBedsController = TextEditingController(text: '1');
    final lowerRentController = TextEditingController(text: '650');
    final upperRentController = TextEditingController(text: '600');

    String? selectedBuildingId = parentRoom?.buildingId;
    String? selectedParentId = parentRoom?.roomId;
    String? validationError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: BlocBuilder<ManagementBloc, ManagementState>(
          builder: (context, state) {
            List<BuildingModel> buildings = [];
            List<RoomModel> rooms = [];
            if (state is ManagementLoaded) {
              buildings = state.buildings;
              rooms = state.rooms;
            }

            return StatefulBuilder(
              builder: (context, setState) => Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
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
                      Text(
                        selectedParentId == null ? 'Add Room' : 'Add Subroom',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<String>(
                        initialValue: selectedBuildingId,
                        decoration: const InputDecoration(
                          labelText: 'Building',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        items: buildings
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.buildingId,
                                child: Text(b.buildingName),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedBuildingId = value;
                          selectedParentId = null;
                        }),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey('$selectedBuildingId/$selectedParentId'),
                        initialValue: selectedParentId ?? '',
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Inside room (optional)',
                          helperText:
                              'Leave as main room, or choose a room for this subroom.',
                          helperMaxLines: 2,
                          prefixIcon: Icon(Icons.account_tree_outlined),
                        ),
                        items: [
                          const DropdownMenuItem(
                              value: '', child: Text('Main room')),
                          ...rooms
                              .where((room) =>
                                  !room.isSubroom &&
                                  room.buildingId == selectedBuildingId &&
                                  room.roomId != null)
                              .map((room) => DropdownMenuItem(
                                  value: room.roomId,
                                  child: Text('Room ${room.roomNumber}'))),
                        ],
                        onChanged: selectedBuildingId == null
                            ? null
                            : (value) => setState(() {
                                  selectedParentId = value == '' ? null : value;
                                }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: roomNumberController,
                        decoration: InputDecoration(
                          labelText: selectedParentId == null
                              ? 'Room Number / Name'
                              : 'Subroom Number / Name',
                          prefixIcon:
                              const Icon(Icons.door_front_door_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: capacityController,
                              decoration: const InputDecoration(
                                labelText: 'Capacity',
                                prefixIcon: Icon(Icons.people_outline),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lowerBedsController,
                              decoration: const InputDecoration(
                                labelText: 'Lower Beds',
                                prefixIcon: Icon(Icons.bed_outlined),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: upperBedsController,
                              decoration: const InputDecoration(
                                labelText: 'Upper Beds',
                                prefixIcon: Icon(Icons.bed_outlined),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: lowerRentController,
                              decoration: const InputDecoration(
                                labelText: 'Lower Rent',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: upperRentController,
                              decoration: const InputDecoration(
                                labelText: 'Upper Rent',
                                prefixIcon: Icon(Icons.currency_rupee),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      if (validationError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(validationError!,
                              style:
                                  const TextStyle(color: AppTheme.errorColor)),
                        ),
                      ElevatedButton(
                        onPressed: selectedBuildingId == null
                            ? null
                            : () {
                                final lower =
                                    int.tryParse(lowerBedsController.text);
                                final upper =
                                    int.tryParse(upperBedsController.text);
                                final capacity =
                                    int.tryParse(capacityController.text);
                                final lowerRent =
                                    double.tryParse(lowerRentController.text);
                                final upperRent =
                                    double.tryParse(upperRentController.text);
                                if (roomNumberController.text.trim().isEmpty ||
                                    lower == null ||
                                    upper == null ||
                                    lower < 0 ||
                                    upper < 0 ||
                                    capacity != lower + upper ||
                                    lowerRent == null ||
                                    upperRent == null ||
                                    !lowerRent.isFinite ||
                                    !upperRent.isFinite ||
                                    lowerRent < 0 ||
                                    upperRent < 0) {
                                  setState(() => validationError =
                                      'Enter a name, non-negative beds and rents. Capacity must equal lower + upper beds. Use 0 beds for a room that only contains subrooms.');
                                  return;
                                }
                                final room = RoomModel(
                                  buildingId: selectedBuildingId!,
                                  parentRoomId: selectedParentId,
                                  roomNumber: roomNumberController.text.trim(),
                                  totalCapacity:
                                      int.tryParse(capacityController.text) ??
                                          2,
                                  lowerBedsCount:
                                      int.tryParse(lowerBedsController.text) ??
                                          1,
                                  upperBedsCount:
                                      int.tryParse(upperBedsController.text) ??
                                          1,
                                  lowerBedRent: double.tryParse(
                                          lowerRentController.text) ??
                                      0,
                                  upperBedRent: double.tryParse(
                                          upperRentController.text) ??
                                      0,
                                  utilityCostMonthly: 0,
                                );
                                try {
                                  room.validateHierarchy(rooms);
                                } on ArgumentError catch (error) {
                                  setState(() => validationError =
                                      error.message.toString());
                                  return;
                                }
                                managementBloc.add(AddRoom(room));
                                Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(selectedParentId == null
                            ? 'Add Room'
                            : 'Add Subroom'),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // void _showEditRoomDialog(BuildContext context, RoomModel room) {
  //   final managementBloc = context.read<ManagementBloc>();
  //   final roomNumberController = TextEditingController(text: room.roomNumber);
  //   final capacityController = TextEditingController(
  //     text: room.totalCapacity.toString(),
  //   );
  //   final lowerBedsController = TextEditingController(
  //     text: room.lowerBedsCount.toString(),
  //   );
  //   final upperBedsController = TextEditingController(
  //     text: room.upperBedsCount.toString(),
  //   );
  //   final lowerRentController = TextEditingController(
  //     text: room.lowerBedRent.toString(),
  //   );
  //   final upperRentController = TextEditingController(
  //     text: room.upperBedRent.toString(),
  //   );

  //   showModalBottomSheet(
  //     context: context,
  //     isScrollControlled: true,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => BlocProvider.value(
  //       value: managementBloc,
  //       child: Container(
  //         padding: EdgeInsets.only(
  //           bottom: MediaQuery.of(context).viewInsets.bottom,
  //         ),
  //         decoration: const BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //         ),
  //         child: SingleChildScrollView(
  //           padding: const EdgeInsets.all(24),
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.stretch,
  //             children: [
  //               Center(
  //                 child: Container(
  //                   width: 40,
  //                   height: 4,
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.shade300,
  //                     borderRadius: BorderRadius.circular(2),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(height: 24),
  //               Row(
  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //                 children: [
  //                   const Text(
  //                     'Edit Room',
  //                     style: TextStyle(
  //                       fontSize: 20,
  //                       fontWeight: FontWeight.bold,
  //                       color: AppTheme.textColor,
  //                     ),
  //                   ),
  //                   IconButton(
  //                     icon: const Icon(
  //                       Icons.delete_outline,
  //                       color: AppTheme.errorColor,
  //                     ),
  //                     onPressed: () {
  //                       Navigator.pop(context);
  //                       _showDeleteConfirmation(context, room);
  //                     },
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 24),
  //               TextField(
  //                 controller: roomNumberController,
  //                 decoration: const InputDecoration(
  //                   labelText: 'Room Number',
  //                   prefixIcon: Icon(Icons.door_front_door_outlined),
  //                 ),
  //               ),
  //               const SizedBox(height: 16),
  //               TextField(
  //                 controller: capacityController,
  //                 decoration: const InputDecoration(
  //                   labelText: 'Total Capacity',
  //                   prefixIcon: Icon(Icons.people_outline),
  //                 ),
  //                 keyboardType: TextInputType.number,
  //               ),
  //               const SizedBox(height: 16),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: TextField(
  //                       controller: lowerBedsController,
  //                       decoration: const InputDecoration(
  //                         labelText: 'Lower Beds',
  //                         prefixIcon: Icon(Icons.bed_outlined),
  //                       ),
  //                       keyboardType: TextInputType.number,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   Expanded(
  //                     child: TextField(
  //                       controller: upperBedsController,
  //                       decoration: const InputDecoration(
  //                         labelText: 'Upper Beds',
  //                         prefixIcon: Icon(Icons.bed_outlined),
  //                       ),
  //                       keyboardType: TextInputType.number,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 16),
  //               Row(
  //                 children: [
  //                   Expanded(
  //                     child: TextField(
  //                       controller: lowerRentController,
  //                       decoration: const InputDecoration(
  //                         labelText: 'Lower Rent',
  //                         prefixIcon: Icon(Icons.currency_rupee),
  //                       ),
  //                       keyboardType: TextInputType.number,
  //                     ),
  //                   ),
  //                   const SizedBox(width: 16),
  //                   Expanded(
  //                     child: TextField(
  //                       controller: upperRentController,
  //                       decoration: const InputDecoration(
  //                         labelText: 'Upper Rent',
  //                         prefixIcon: Icon(Icons.currency_rupee),
  //                       ),
  //                       keyboardType: TextInputType.number,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //               const SizedBox(height: 32),
  //               ElevatedButton(
  //                 onPressed: () {
  //                   final updated = RoomModel(
  //                     roomId: room.roomId,
  //                     buildingId: room.buildingId,
  //                     roomNumber: roomNumberController.text,
  //                     totalCapacity: int.tryParse(capacityController.text) ?? 2,
  //                     lowerBedsCount:
  //                         int.tryParse(lowerBedsController.text) ?? 1,
  //                     upperBedsCount:
  //                         int.tryParse(upperBedsController.text) ?? 1,
  //                     lowerBedRent:
  //                         double.tryParse(lowerRentController.text) ?? 0,
  //                     upperBedRent:
  //                         double.tryParse(upperRentController.text) ?? 0,
  //                     utilityCostMonthly: 0,
  //                   );
  //                   managementBloc.add(UpdateRoom(updated));
  //                   Navigator.pop(context);
  //                 },
  //                 style: ElevatedButton.styleFrom(
  //                   padding: const EdgeInsets.symmetric(vertical: 16),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(12),
  //                   ),
  //                 ),
  //                 child: const Text('Save Changes'),
  //               ),
  //               const SizedBox(height: 16),
  //             ],
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // void _showDeleteConfirmation(BuildContext context, RoomModel room) {
  //   final managementBloc = context.read<ManagementBloc>();
  //   showModalBottomSheet(
  //     context: context,
  //     backgroundColor: Colors.transparent,
  //     builder: (context) => Container(
  //       padding: const EdgeInsets.all(24),
  //       decoration: const BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  //       ),
  //       child: Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.stretch,
  //         children: [
  //           Center(
  //             child: Container(
  //               width: 40,
  //               height: 4,
  //               decoration: BoxDecoration(
  //                 color: Colors.grey.shade300,
  //                 borderRadius: BorderRadius.circular(2),
  //               ),
  //             ),
  //           ),
  //           const SizedBox(height: 24),
  //           const Text(
  //             'Delete Room?',
  //             textAlign: TextAlign.center,
  //             style: TextStyle(
  //               fontSize: 20,
  //               fontWeight: FontWeight.bold,
  //               color: AppTheme.errorColor,
  //             ),
  //           ),
  //           const SizedBox(height: 16),
  //           Text(
  //             'Are you sure you want to delete Room ${room.roomNumber}? This action cannot be undone.',
  //             textAlign: TextAlign.center,
  //             style: const TextStyle(
  //               color: AppTheme.secondaryTextColor,
  //               fontSize: 16,
  //             ),
  //           ),
  //           const SizedBox(height: 32),
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: OutlinedButton(
  //                   onPressed: () => Navigator.pop(context),
  //                   style: OutlinedButton.styleFrom(
  //                     padding: const EdgeInsets.symmetric(vertical: 16),
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                   ),
  //                   child: const Text('Cancel'),
  //                 ),
  //               ),
  //               const SizedBox(width: 16),
  //               Expanded(
  //                 child: ElevatedButton(
  //                   onPressed: () {
  //                     if (room.roomId != null) {
  //                       managementBloc.add(DeleteRoom(room.roomId!));
  //                     }
  //                     Navigator.pop(context);
  //                   },
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: AppTheme.errorColor,
  //                     padding: const EdgeInsets.symmetric(vertical: 16),
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(12),
  //                     ),
  //                   ),
  //                   child: const Text(
  //                     'Delete',
  //                     style: TextStyle(color: Colors.white),
  //                   ),
  //                 ),
  //               ),
  //             ],
  //           ),
  //           const SizedBox(height: 16),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
