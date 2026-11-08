import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/management/management_bloc.dart';
import '../../data/models/building_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/tenant_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/expense_model.dart';
import '../theme/app_theme.dart';
import '../widgets/sharing_actions.dart';
import '../../data/models/billing_snapshot.dart';

class TenantsManagementScreen extends StatefulWidget {
  const TenantsManagementScreen({super.key});

  @override
  State<TenantsManagementScreen> createState() =>
      _TenantsManagementScreenState();

  static void showAddTenantDialog(
    BuildContext context, {
    String? preSelectedBuildingId,
    String? preSelectedRoomId,
    String? preSelectedBedId,
    double? preSelectedRentAmount,
  }) async {
    final managementBloc = context.read<ManagementBloc>();
    managementBloc.add(const LoadBuildings());
    managementBloc.add(const LoadRooms());

    if (!context.mounted) return;

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final rentController = TextEditingController(
      text: preSelectedRentAmount?.toStringAsFixed(0) ?? '0',
    );
    final advanceController = TextEditingController(text: '0');
    DateTime selectedDate = DateTime.now();
    final dueDayController =
        TextEditingController(text: selectedDate.day.toString());
    String? selectedBuildingId = preSelectedBuildingId;
    String? selectedRoomId = preSelectedRoomId;
    String? selectedBedId = preSelectedBedId;

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
            List<BedModel> allBeds = [];

            if (state is ManagementLoaded) {
              buildings = state.buildings;
              rooms = state.rooms;
              allBeds = state.beds;
            }

            return StatefulBuilder(
              builder: (context, setState) {
                final filteredRooms = selectedBuildingId != null
                    ? rooms
                        .where(
                          (r) =>
                              r.buildingId.trim() == selectedBuildingId!.trim(),
                        )
                        .toList()
                    : <RoomModel>[];

                return Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
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
                        const Text(
                          'Add Tenant',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tenant Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedBuildingId,
                          decoration: const InputDecoration(
                            labelText: 'Building',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          items: buildings
                              .map<DropdownMenuItem<String>>(
                                (b) => DropdownMenuItem<String>(
                                  value: b.buildingId,
                                  child: Text(b.buildingName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            selectedBuildingId = value;
                            selectedRoomId = null;
                            selectedBedId = null;
                          }),
                        ),
                        if (selectedBuildingId != null) ...[
                          const SizedBox(height: 16),
                          if (filteredRooms.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No rooms found for this building.',
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedRoomId,
                              decoration: const InputDecoration(
                                labelText: 'Room',
                                prefixIcon:
                                    Icon(Icons.door_front_door_outlined),
                              ),
                              items: filteredRooms
                                  .map<DropdownMenuItem<String>>(
                                    (r) => DropdownMenuItem<String>(
                                      value: r.roomId,
                                      child: Text(r.displayName(rooms),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() {
                                selectedRoomId = value;
                                selectedBedId = null;
                              }),
                            ),
                        ],
                        if (selectedRoomId != null) ...[
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final beds = allBeds
                                  .where(
                                    (b) =>
                                        b.roomId == selectedRoomId &&
                                        b.status == BedStatus.vacant,
                                  )
                                  .toList();
                              final lowerBeds = beds
                                  .where((b) => b.bedType == BedType.lower)
                                  .toList();
                              final upperBeds = beds
                                  .where((b) => b.bedType == BedType.upper)
                                  .toList();

                              final selectedRoom = rooms.firstWhere(
                                (r) => r.roomId == selectedRoomId,
                                orElse: () => RoomModel(
                                  buildingId: '',
                                  roomNumber: '',
                                  totalCapacity: 0,
                                  lowerBedsCount: 0,
                                  upperBedsCount: 0,
                                  lowerBedRent: 0,
                                  upperBedRent: 0,
                                  utilityCostMonthly: 0,
                                ),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Bed Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ChoiceChip(
                                          label: Text(
                                            'Lower (د.إ${selectedRoom.lowerBedRent.toStringAsFixed(0)})',
                                          ),
                                          selected: selectedBedId != null &&
                                              allBeds
                                                      .firstWhere(
                                                        (b) =>
                                                            b.bedId ==
                                                            selectedBedId,
                                                        orElse: () => BedModel(
                                                          roomId: '',
                                                          bedType:
                                                              BedType.lower,
                                                          status: BedStatus
                                                              .occupied,
                                                        ),
                                                      )
                                                      .bedType ==
                                                  BedType.lower,
                                          onSelected: lowerBeds.isNotEmpty
                                              ? (selected) {
                                                  if (selected) {
                                                    setState(() {
                                                      selectedBedId =
                                                          lowerBeds.first.bedId;
                                                      rentController.text =
                                                          selectedRoom
                                                              .lowerBedRent
                                                              .toString();
                                                    });
                                                  }
                                                }
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ChoiceChip(
                                          label: Text(
                                            'Upper (د.إ${selectedRoom.upperBedRent.toStringAsFixed(0)})',
                                          ),
                                          selected: selectedBedId != null &&
                                              allBeds
                                                      .firstWhere(
                                                        (b) =>
                                                            b.bedId ==
                                                            selectedBedId,
                                                        orElse: () => BedModel(
                                                          roomId: '',
                                                          bedType:
                                                              BedType.lower,
                                                          status: BedStatus
                                                              .occupied,
                                                        ),
                                                      )
                                                      .bedType ==
                                                  BedType.upper,
                                          onSelected: upperBeds.isNotEmpty
                                              ? (selected) {
                                                  if (selected) {
                                                    setState(() {
                                                      selectedBedId =
                                                          upperBeds.first.bedId;
                                                      rentController.text =
                                                          selectedRoom
                                                              .upperBedRent
                                                              .toString();
                                                    });
                                                  }
                                                }
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (lowerBeds.isEmpty && upperBeds.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 8.0),
                                      child: Text(
                                        'No beds available in this room.',
                                        style: TextStyle(
                                          color: AppTheme.errorColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rentController,
                                decoration: const InputDecoration(
                                  labelText: 'Monthly Rent',
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: advanceController,
                                decoration: const InputDecoration(
                                  labelText: 'Advance',
                                  prefixIcon: Icon(Icons.payments_outlined),
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
                                controller: dueDayController,
                                decoration: const InputDecoration(
                                  labelText: 'Rent Due Day',
                                  prefixIcon:
                                      Icon(Icons.calendar_month_outlined),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 180)),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: AppTheme.primaryColor,
                                            onPrimary: Colors.white,
                                            onSurface: AppTheme.textColor,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (date != null) {
                                    setState(() {
                                      selectedDate = date;
                                      dueDayController.text =
                                          date.day.toString();
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Joining Date',
                                    prefixIcon: Icon(Icons.today_outlined),
                                  ),
                                  child: Text(
                                    DateFormat('dd MMM yyyy')
                                        .format(selectedDate),
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: (selectedBuildingId == null ||
                                  selectedRoomId == null ||
                                  selectedBedId == null)
                              ? null
                              : () {
                                  final tenant = TenantModel(
                                    tenantName: nameController.text,
                                    phone: phoneController.text,
                                    buildingId: selectedBuildingId!,
                                    roomId: selectedRoomId!,
                                    bedId: selectedBedId!,
                                    rentAmount:
                                        double.tryParse(rentController.text) ??
                                            0,
                                    advanceAmount: double.tryParse(
                                            advanceController.text) ??
                                        0,
                                    joiningDate: selectedDate,
                                    rentDueDay:
                                        int.tryParse(dueDayController.text) ??
                                            1,
                                    active: true,
                                  );
                                  managementBloc.add(AddTenant(tenant));
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Add Tenant'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TenantsManagementScreenState extends State<TenantsManagementScreen> {
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
          'Manage Tenants',
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
              Icons.person_add_outlined,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'Add Tenant',
            onPressed: () =>
                TenantsManagementScreen.showAddTenantDialog(context),
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
                  hintText: 'Search by name, phone or room...',
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
                  if (state.isLoading && state.tenants.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  if (state.error != null && state.tenants.isEmpty) {
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
                                    const LoadTenants(),
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

                  // Filter active tenants based on search query
                  final activeTenants = state.tenants.where((t) {
                    if (!t.active) return false;
                    if (_searchQuery.isEmpty) return true;

                    final room = state.rooms.firstWhere(
                      (r) => r.roomId == t.roomId,
                      orElse: () => RoomModel(
                        buildingId: '',
                        roomNumber: t.roomId,
                        totalCapacity: 0,
                        lowerBedsCount: 0,
                        upperBedsCount: 0,
                        lowerBedRent: 0,
                        upperBedRent: 0,
                        utilityCostMonthly: 0,
                      ),
                    );

                    return t.tenantName.toLowerCase().contains(_searchQuery) ||
                        t.phone.toLowerCase().contains(_searchQuery) ||
                        room
                            .displayName(state.rooms)
                            .toLowerCase()
                            .contains(_searchQuery);
                  }).toList();

                  if (activeTenants.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off,
                            size: 64,
                            color: AppTheme.softGrey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No tenants found'
                                : 'No matches found',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: AppTheme.softGrey),
                          ),
                          const SizedBox(height: 16),
                          if (_searchQuery.isEmpty)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  TenantsManagementScreen.showAddTenantDialog(
                                context,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Tenant'),
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
                      context.read<ManagementBloc>().add(const LoadTenants());
                      context.read<ManagementBloc>().add(const LoadBuildings());
                      context.read<ManagementBloc>().add(const LoadRooms());
                      context.read<ManagementBloc>().add(const LoadPayments());
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: activeTenants.length,
                      itemBuilder: (context, index) {
                        final tenant = activeTenants[index];
                        // Find the room to get the room number
                        final room = state.rooms.firstWhere(
                          (r) => r.roomId == tenant.roomId,
                          orElse: () => RoomModel(
                            buildingId: '',
                            roomNumber: tenant
                                .roomId, // Fallback to showing ID if room not found
                            totalCapacity: 0,
                            lowerBedsCount: 0,
                            upperBedsCount: 0,
                            lowerBedRent: 0,
                            upperBedRent: 0,
                            utilityCostMonthly: 0,
                          ),
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: AppTheme.cardDecoration,
                          child: ListTile(
                            contentPadding: const EdgeInsets.only(
                              left: 0,
                              right: 0,
                              top: 8,
                              bottom: 8,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor
                                    .withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  tenant.tenantName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                                if (tenant.checkoutDate != null &&
                                    tenant.active) ...[
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.warningColor
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Checkout: ${DateFormat('dd MMM').format(tenant.checkoutDate!)}',
                                        style: const TextStyle(
                                          color: AppTheme.warningColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Ph:${tenant.phone}",
                                    style: const TextStyle(
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${room.displayName(state.rooms)} | Due Day: ${tenant.rentDueDay}',
                                    style: const TextStyle(
                                      color: AppTheme.secondaryTextColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'Rent: د.إ${tenant.rentAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: AppTheme.textColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Adv: د.إ${tenant.advanceAmount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          color: AppTheme.secondaryTextColor,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _TenantsManagementScreenState
                                      ._buildPaymentStatusIndicator(
                                    tenant,
                                    state.payments,
                                  ),
                                ],
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppTheme.textColor,
                              ),
                              onSelected: (value) {
                                switch (value) {
                                  case 'share':
                                    openTenantSharing(context, tenant);
                                    break;
                                  case 'balance':
                                    _navigateToRentBalance(
                                      context,
                                      tenant.tenantId ?? '',
                                    );
                                    break;
                                  case 'edit':
                                    _showEditTenantDialog(context, tenant);
                                    break;
                                  case 'checkout':
                                    _showCheckoutDialog(
                                      context,
                                      tenant,
                                      state.payments,
                                    );
                                    break;
                                  case 'delete':
                                    _showDeleteConfirmation(context, tenant);
                                    break;
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                    value: 'share',
                                    child:
                                        Text('WhatsApp, invoice & receipts')),
                                const PopupMenuItem(
                                  value: 'balance',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.account_balance_wallet_outlined,
                                        color: AppTheme.secondaryColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('View Balance'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: AppTheme.primaryColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Edit Tenant'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'checkout',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.exit_to_app,
                                        color: AppTheme.warningColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Checkout Tenant'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.delete_outlined,
                                        color: AppTheme.errorColor,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Delete Tenant'),
                                    ],
                                  ),
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
          ),
        ],
      ),
    );
  }

  static Widget _buildPaymentStatusIndicator(
    TenantModel tenant,
    List<PaymentModel> allPayments,
  ) {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Get all payments for current month
    final currentMonthPayments = allPayments
        .where(
          (p) =>
              p.tenantId == tenant.tenantId && p.paymentMonth == currentMonth,
        )
        .toList();

    // Calculate total paid this month
    final totalPaid = currentMonthPayments.fold<double>(
      0,
      (sum, p) => sum + p.amount,
    );
    final expectedRent = BillingSnapshot.rentForMonth(tenant, now);
    final balance = expectedRent - totalPaid;

    // Fully paid or overpaid
    if (balance <= 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: AppTheme.successColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            totalPaid > expectedRent ? 'Overpaid' : 'Paid',
            style: const TextStyle(
              color: AppTheme.successColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Partially paid
    if (totalPaid > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.warningColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            'Partial - د.إ${balance.toStringAsFixed(0)} due',
            style: const TextStyle(
              color: AppTheme.warningColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Not paid - check if overdue
    final dueDay = tenant.rentDueDay;
    final currentDay = now.day;

    if (currentDay > dueDay) {
      // Overdue (red)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 14),
          const SizedBox(width: 4),
          Text(
            'Overdue - د.إ${expectedRent.toStringAsFixed(0)}',
            style: const TextStyle(
              color: AppTheme.errorColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    // Pending but not yet due (orange/grey)
    final daysUntilDue = dueDay - currentDay;
    final statusText = daysUntilDue == 0
        ? 'Due Today'
        : 'Due in $daysUntilDue day${daysUntilDue == 1 ? '' : 's'}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.access_time,
          color: daysUntilDue <= 3
              ? AppTheme.warningColor
              : AppTheme.secondaryTextColor,
          size: 14,
        ),
        const SizedBox(width: 4),
        Text(
          statusText,
          style: TextStyle(
            color: daysUntilDue <= 3
                ? AppTheme.warningColor
                : AppTheme.secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _showEditTenantDialog(BuildContext context, TenantModel tenant) async {
    final managementBloc = context.read<ManagementBloc>();
    managementBloc.add(const LoadBuildings());
    managementBloc.add(const LoadRooms());

    if (!context.mounted) return;

    final nameController = TextEditingController(text: tenant.tenantName);
    final phoneController = TextEditingController(text: tenant.phone);
    final rentController = TextEditingController(
      text: tenant.rentAmount.toString(),
    );
    final advanceController = TextEditingController(
      text: tenant.advanceAmount.toString(),
    );
    final dueDayController = TextEditingController(
      text: tenant.rentDueDay.toString(),
    );

    // Initialize with current values
    String? selectedBuildingId = tenant.buildingId;
    String? selectedRoomId = tenant.roomId;
    String? selectedBedId = tenant.bedId;

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
            List<BedModel> allBeds = [];

            if (state is ManagementLoaded) {
              buildings = state.buildings;
              rooms = state.rooms;
              allBeds = state.beds;
            }

            return StatefulBuilder(
              builder: (context, setState) {
                // Calculate filtered rooms based on selected building
                final filteredRooms = selectedBuildingId != null
                    ? rooms
                        .where(
                          (r) =>
                              r.buildingId.trim() == selectedBuildingId!.trim(),
                        )
                        .toList()
                    : <RoomModel>[];

                return Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
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
                        const Text(
                          'Edit Tenant',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor,
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Tenant Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedBuildingId,
                          decoration: const InputDecoration(
                            labelText: 'Building',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          items: buildings
                              .map<DropdownMenuItem<String>>(
                                (b) => DropdownMenuItem<String>(
                                  value: b.buildingId,
                                  child: Text(b.buildingName),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() {
                            selectedBuildingId = value;
                            selectedRoomId = null;
                            selectedBedId = null;
                          }),
                        ),
                        if (selectedBuildingId != null) ...[
                          const SizedBox(height: 16),
                          if (filteredRooms.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                'No rooms found for this building.',
                                style: TextStyle(color: AppTheme.errorColor),
                              ),
                            )
                          else
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedRoomId,
                              decoration: const InputDecoration(
                                labelText: 'Room',
                                prefixIcon:
                                    Icon(Icons.door_front_door_outlined),
                              ),
                              items: filteredRooms
                                  .map<DropdownMenuItem<String>>(
                                    (r) => DropdownMenuItem<String>(
                                      value: r.roomId,
                                      child: Text(r.displayName(rooms),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) => setState(() {
                                selectedRoomId = value;
                                selectedBedId = null;
                              }),
                            ),
                        ],
                        if (selectedRoomId != null) ...[
                          const SizedBox(height: 16),
                          Builder(
                            builder: (context) {
                              final roomBeds = allBeds
                                  .where((b) => b.roomId == selectedRoomId)
                                  .toList();
                              final beds = roomBeds
                                  .where(
                                    (b) =>
                                        b.status == BedStatus.vacant ||
                                        b.bedId == tenant.bedId,
                                  )
                                  .toList();

                              final lowerBeds = beds
                                  .where((b) => b.bedType == BedType.lower)
                                  .toList();
                              final upperBeds = beds
                                  .where((b) => b.bedType == BedType.upper)
                                  .toList();

                              final selectedRoom = rooms.firstWhere(
                                (r) => r.roomId == selectedRoomId,
                                orElse: () => RoomModel(
                                  buildingId: '',
                                  roomNumber: '',
                                  totalCapacity: 0,
                                  lowerBedsCount: 0,
                                  upperBedsCount: 0,
                                  lowerBedRent: 0,
                                  upperBedRent: 0,
                                  utilityCostMonthly: 0,
                                ),
                              );

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Bed Type',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ChoiceChip(
                                          label: Text(
                                            'Lower (د.إ${selectedRoom.lowerBedRent.toStringAsFixed(0)})',
                                          ),
                                          selected: selectedBedId != null &&
                                              allBeds
                                                      .firstWhere(
                                                        (b) =>
                                                            b.bedId ==
                                                            selectedBedId,
                                                        orElse: () => BedModel(
                                                          roomId: '',
                                                          bedType:
                                                              BedType.lower,
                                                          status: BedStatus
                                                              .occupied,
                                                        ),
                                                      )
                                                      .bedType ==
                                                  BedType.lower,
                                          onSelected: lowerBeds.isNotEmpty
                                              ? (selected) {
                                                  if (selected) {
                                                    setState(() {
                                                      selectedBedId =
                                                          lowerBeds.first.bedId;
                                                      rentController.text =
                                                          selectedRoom
                                                              .lowerBedRent
                                                              .toString();
                                                    });
                                                  }
                                                }
                                              : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ChoiceChip(
                                          label: Text(
                                            'Upper (د.إ${selectedRoom.upperBedRent.toStringAsFixed(0)})',
                                          ),
                                          selected: selectedBedId != null &&
                                              allBeds
                                                      .firstWhere(
                                                        (b) =>
                                                            b.bedId ==
                                                            selectedBedId,
                                                        orElse: () => BedModel(
                                                          roomId: '',
                                                          bedType:
                                                              BedType.lower,
                                                          status: BedStatus
                                                              .occupied,
                                                        ),
                                                      )
                                                      .bedType ==
                                                  BedType.upper,
                                          onSelected: upperBeds.isNotEmpty
                                              ? (selected) {
                                                  if (selected) {
                                                    setState(() {
                                                      selectedBedId =
                                                          upperBeds.first.bedId;
                                                      rentController.text =
                                                          selectedRoom
                                                              .upperBedRent
                                                              .toString();
                                                    });
                                                  }
                                                }
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: rentController,
                                decoration: const InputDecoration(
                                  labelText: 'Monthly Rent',
                                  prefixIcon: Icon(Icons.currency_rupee),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: advanceController,
                                decoration: const InputDecoration(
                                  labelText: 'Advance',
                                  prefixIcon: Icon(Icons.payments_outlined),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: dueDayController,
                          decoration: const InputDecoration(
                            labelText: 'Rent Due Day',
                            prefixIcon: Icon(Icons.calendar_month_outlined),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: (selectedBuildingId == null ||
                                  selectedRoomId == null ||
                                  selectedBedId == null)
                              ? null
                              : () {
                                  final updatedTenant = tenant.copyWith(
                                    tenantName: nameController.text,
                                    phone: phoneController.text,
                                    buildingId: selectedBuildingId!,
                                    roomId: selectedRoomId!,
                                    bedId: selectedBedId!,
                                    rentAmount:
                                        double.tryParse(rentController.text) ??
                                            0,
                                    advanceAmount: double.tryParse(
                                            advanceController.text) ??
                                        0,
                                    rentDueDay:
                                        int.tryParse(dueDayController.text) ??
                                            1,
                                  );
                                  managementBloc
                                      .add(UpdateTenant(updatedTenant));
                                  Navigator.pop(context);
                                },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Save Changes'),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showCheckoutDialog(
    BuildContext context,
    TenantModel tenant,
    List<PaymentModel> allPayments,
  ) {
    final managementBloc = context.read<ManagementBloc>();

    // Initial calculation setup
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime checkoutDate = today;
    bool giveBackBalance = false;

    // Fixed calculations for initial static values
    final joiningDate = DateTime(
      tenant.joiningDate.year,
      tenant.joiningDate.month,
      tenant.joiningDate.day,
    );
    final tenantPayments =
        allPayments.where((p) => p.tenantId == tenant.tenantId).toList();
    final totalPaid = tenantPayments.fold<double>(
      0,
      (sum, p) => sum + p.amount,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            // Recalculate based on current state (checkoutDate)
            final stayDuration =
                checkoutDate.difference(joiningDate).inDays + 1;
            final stayDays = stayDuration > 0 ? stayDuration : 0;

            // Prorated Rent Calculation
            // Using 30 days as a standard month for daily rate
            final dailyRate = tenant.rentAmount / 30;
            final totalProratedDue = dailyRate * stayDays;

            // Total amount they should have paid vs what they actually paid
            final rentBalance = totalProratedDue - totalPaid;

            // Advance is always handled separately or added to balance
            final advanceAmount = tenant.advanceAmount;

            // Final settlement calculation
            // positive = Collect more, negative = Refund needed
            final calculatedSettlement = rentBalance - advanceAmount;

            // If giveBackBalance is true and calculatedSettlement is negative,
            // we will record the absolute value as a refund expense.
            final actualRefund = (giveBackBalance && calculatedSettlement < 0)
                ? calculatedSettlement.abs()
                : 0.0;

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
                    children: [
                      const Icon(Icons.exit_to_app,
                          color: AppTheme.warningColor),
                      const SizedBox(width: 12),
                      const Text(
                        'Checkout Tenant',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tenant.tenantName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: checkoutDate,
                        firstDate: joiningDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setModalState(() => checkoutDate = pickedDate);
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Checkout Date',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(checkoutDate),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildSettlementRow('Joining Date',
                      DateFormat('dd MMM yyyy').format(joiningDate)),
                  _buildSettlementRow('Stay Duration', '$stayDays Days'),
                  _buildSettlementRow(
                      'Total Paid', 'د.إ${totalPaid.toStringAsFixed(0)}',
                      valueColor: AppTheme.successColor),
                  _buildSettlementRow('Prorated Rent',
                      'د.إ${totalProratedDue.toStringAsFixed(0)}'),
                  _buildSettlementRow('Advance Amount',
                      'د.إ${advanceAmount.toStringAsFixed(0)}',
                      valueColor: AppTheme.secondaryColor),
                  const Divider(height: 24),
                  _buildSettlementRow(
                    calculatedSettlement >= 0
                        ? 'Collect Remaining'
                        : 'Refund Outstanding',
                    'د.إ${calculatedSettlement.abs().toStringAsFixed(0)}',
                    valueColor: calculatedSettlement >= 0
                        ? AppTheme.errorColor
                        : AppTheme.successColor,
                    isBold: true,
                  ),
                  if (calculatedSettlement < 0) ...[
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      value: giveBackBalance,
                      activeColor: AppTheme.primaryColor,
                      title: const Text(
                        'Give back balance rent',
                        style: TextStyle(fontSize: 14),
                      ),
                      subtitle: Text(
                        'Subtract د.إ${calculatedSettlement.abs().toStringAsFixed(0)} from income',
                        style: const TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() => giveBackBalance = val ?? false);
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final checkoutDateOnly = DateTime(
                        checkoutDate.year,
                        checkoutDate.month,
                        checkoutDate.day,
                      );
                      final isFuture = checkoutDateOnly.isAfter(today);

                      managementBloc.add(CheckoutTenant(
                        tenant,
                        checkoutDate: checkoutDate,
                        refundAmount: actualRefund > 0 ? actualRefund : null,
                      ));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isFuture
                              ? '${tenant.tenantName} checkout scheduled for ${DateFormat('dd MMM yyyy').format(checkoutDate)}'
                              : '${tenant.tenantName} checked out successfully'),
                          backgroundColor: AppTheme.successColor,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.warningColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Confirm Checkout'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
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

  Widget _buildSettlementRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TenantModel tenant) {
    final managementBloc = context.read<ManagementBloc>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: managementBloc,
        child: Container(
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
              const Text(
                'Delete Tenant',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.errorColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete ${tenant.tenantName}? This action cannot be undone, and the bed will be marked as vacant.',
                style: const TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (tenant.tenantId != null) {
                    managementBloc.add(DeleteTenant(tenant.tenantId!));
                  }
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.errorColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Delete Permanently'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToRentBalance(BuildContext context, String tenantId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<ManagementBloc>(),
          child: RentBalanceScreen(tenantId: tenantId),
        ),
      ),
    );
  }
}

class RentBalanceScreen extends StatefulWidget {
  final String tenantId;

  const RentBalanceScreen({super.key, required this.tenantId});

  @override
  State<RentBalanceScreen> createState() => _RentBalanceScreenState();
}

class _RentBalanceScreenState extends State<RentBalanceScreen> {
  @override
  initState() {
    super.initState();
    // Load tenant balance when screen initializes
    context.read<ManagementBloc>().add(LoadTenantBalance(widget.tenantId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Rent Balance',
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
            tooltip: 'Add Payment',
            onPressed: () => _showAddPaymentDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementInitial) {
            context.read<ManagementBloc>().add(
                  LoadTenantBalance(widget.tenantId),
                );
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            );
          }

          if (state is ManagementLoaded) {
            // If we are loading specifically for this screen, show indicator?
            // Logic is tricky because ManagementLoaded is shared.
            // We can check if tenantBalance matches our ID or just show what we have.

            final balance = state.tenantBalance;
            if (balance.isEmpty && state.isLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            // If we have data, show it.
            if (balance.isNotEmpty) {
              final totalDue = balance['totalDue'] as double? ?? 0.0;
              final totalPaid = balance['totalPaid'] as double? ?? 0.0;
              final rentBalance = balance['balance'] as double? ?? 0.0;
              // Check if payments is List<PaymentModel> or List<dynamic>
              final payments =
                  (balance['payments'] as List?)?.cast<PaymentModel>() ?? [];

              final tenant = balance['tenant'] as TenantModel?;
              final totalRefunded = balance['totalRefunded'] as double? ?? 0.0;
              final expenses =
                  (balance['expenses'] as List?)?.cast<ExpenseModel>() ?? [];
              final stayDays = balance['stayDays'] as int? ?? 0;

              if (tenant == null) {
                return const Center(child: Text('Tenant details not found'));
              }

              return RefreshIndicator(
                color: AppTheme.primaryColor,
                onRefresh: () async {
                  context.read<ManagementBloc>().add(
                        LoadTenantBalance(widget.tenantId),
                      );
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero, // Padding moved to internal column
                  child: Column(
                    children: [
                      if (state.isLoading)
                        const LinearProgressIndicator(
                          color: AppTheme.primaryColor,
                          backgroundColor: Colors.transparent,
                          minHeight: 2,
                        ),
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Balance Summary
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppTheme.cardDecoration,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: AppTheme.primaryColor
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                          tenant.tenantName[0].toUpperCase(),
                                          style: const TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tenant.tenantName,
                                              style: const TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.textColor,
                                              ),
                                            ),
                                            if (!tenant.active)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.errorColor
                                                      .withValues(alpha: 0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: const Text(
                                                  'CHECKED OUT',
                                                  style: TextStyle(
                                                    color: AppTheme.errorColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  _buildBalanceRow(
                                    'Total Due',
                                    'د.إ${totalDue.toStringAsFixed(0)}',
                                    AppTheme.textColor,
                                  ),
                                  _buildBalanceRow(
                                    'Total Paid',
                                    'د.إ${totalPaid.toStringAsFixed(0)}',
                                    AppTheme.successColor,
                                  ),
                                  if (totalRefunded > 0)
                                    _buildBalanceRow(
                                      'Amount Returned',
                                      'د.إ${totalRefunded.toStringAsFixed(0)}',
                                      AppTheme.warningColor,
                                    ),
                                  Divider(
                                    height: 32,
                                    color: Colors.grey.withValues(alpha: 0.1),
                                  ),
                                  _buildBalanceRow(
                                    rentBalance > 1
                                        ? 'Net Amount Owed'
                                        : rentBalance < -1
                                            ? 'Net Credit'
                                            : 'Settle Clean',
                                    'د.إ${rentBalance.abs().toStringAsFixed(0)}',
                                    rentBalance > 1
                                        ? AppTheme.errorColor
                                        : rentBalance < -1
                                            ? AppTheme.successColor
                                            : AppTheme.textColor,
                                    isBold: true,
                                  ),
                                  if (rentBalance > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Outstanding (Overdue)',
                                        style: TextStyle(
                                          color: AppTheme.errorColor
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (rentBalance < 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Advance/Overpayment',
                                        style: TextStyle(
                                          color: AppTheme.successColor
                                              .withValues(alpha: 0.8),
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                  if (!tenant.active)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor
                                              .withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppTheme.primaryColor
                                                .withValues(alpha: 0.1),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            _buildBalanceRow(
                                              'Total Stay',
                                              '$stayDays Days',
                                              AppTheme.secondaryTextColor,
                                            ),
                                            _buildBalanceRow(
                                              'Stay Cost',
                                              'د.إ${totalDue.toStringAsFixed(0)}',
                                              AppTheme.secondaryTextColor,
                                            ),
                                            if (totalRefunded > 0)
                                              _buildBalanceRow(
                                                'Money Returned',
                                                'د.إ${totalRefunded.toStringAsFixed(0)}',
                                                AppTheme.warningColor,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Monthly Breakdown
                            Text(
                              'Monthly Breakdown',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            ..._buildMonthlyBreakdown(tenant, payments),
                            const SizedBox(height: 32),

                            // Activity History
                            Text(
                              'Activity History',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                            ),
                            const SizedBox(height: 16),
                            if (payments.isEmpty && expenses.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: AppTheme.cardDecoration,
                                child: const Center(
                                  child: Text(
                                    'No history recorded',
                                    style: TextStyle(
                                      color: AppTheme.secondaryTextColor,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._buildActivityHistory(payments, expenses),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  List<Widget> _buildMonthlyBreakdown(
    TenantModel tenant,
    List<PaymentModel> allPayments,
  ) {
    final now = DateTime.now();
    final joiningDate = tenant.joiningDate;
    final startMonth = DateTime(joiningDate.year, joiningDate.month);
    final currentMonth = DateTime(now.year, now.month);

    List<Widget> monthCards = [];
    DateTime month = currentMonth;

    // Build list from current month backwards to joining month
    while (month.isAfter(startMonth) || month.isAtSameMomentAs(startMonth)) {
      final monthKey =
          '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final monthName = DateFormat('MMMM yyyy').format(month);

      // Calculate expected rent for this month
      final expectedRent = BillingSnapshot.rentForMonth(tenant, month);

      // Calculate total paid for this month
      final monthPayments =
          allPayments.where((p) => p.paymentMonth == monthKey).toList();
      final totalPaid = monthPayments.fold<double>(
        0,
        (sum, p) => sum + p.amount,
      );

      // Calculate balance for this month
      final monthBalance = expectedRent - totalPaid;

      // Determine status color
      Color statusColor;
      String statusText;
      if (monthBalance <= 0) {
        statusColor = AppTheme.successColor;
        statusText = totalPaid > expectedRent ? 'Overpaid' : 'Paid';
      } else if (totalPaid > 0) {
        statusColor = AppTheme.warningColor;
        statusText = 'Partial';
      } else {
        statusColor = AppTheme.errorColor;
        statusText = 'Unpaid';
      }

      monthCards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    monthName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor,
                    ),
                  ),
                  IconButton(
                      tooltip: 'WhatsApp, invoice & receipts',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () =>
                          openTenantSharing(context, tenant, month: monthKey)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Expected:',
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'د.إ${expectedRent.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: AppTheme.textColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Paid:',
                    style: TextStyle(
                      color: AppTheme.secondaryTextColor,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    'د.إ${totalPaid.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: totalPaid > 0
                          ? AppTheme.successColor
                          : AppTheme.secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (monthBalance != 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthBalance > 0 ? 'Balance:' : 'Excess:',
                      style: const TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'د.إ${monthBalance.abs().toStringAsFixed(0)}',
                      style: TextStyle(
                        color: monthBalance > 0
                            ? AppTheme.errorColor
                            : AppTheme.successColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

      // Move to previous month
      month = DateTime(month.year, month.month - 1);
    }

    return monthCards;
  }

  Widget _buildBalanceRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActivityHistory(
      List<PaymentModel> payments, List<ExpenseModel> expenses) {
    // Combine and sort by date descending
    final List<dynamic> combined = [...payments, ...expenses];
    combined.sort((a, b) {
      final dateA = (a is PaymentModel) ? a.paidDate : (a as ExpenseModel).date;
      final dateB = (b is PaymentModel) ? b.paidDate : (b as ExpenseModel).date;
      return dateB.compareTo(dateA);
    });

    return combined.map((item) {
      if (item is PaymentModel) return _buildPaymentItem(item);
      return _buildExpenseItem(item as ExpenseModel);
    }).toList();
  }

  Widget _buildPaymentItem(PaymentModel payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: ListTile(
        onTap: () {
          final state = context.read<ManagementBloc>().state;
          if (state is ManagementLoaded) {
            final tenant = state.tenants
                .where((tenant) => tenant.tenantId == payment.tenantId)
                .firstOrNull;
            if (tenant != null) {
              openTenantSharing(context, tenant, payment: payment);
            }
          }
        },
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check,
            color: AppTheme.successColor,
            size: 20,
          ),
        ),
        title: Text(
          'د.إ${payment.amount.toStringAsFixed(0)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'Rent Payment (${payment.paymentMonth})',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
          ),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            DateFormat('dd MMM yyyy').format(payment.paidDate),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.secondaryTextColor,
            ),
          ),
          IconButton(
              tooltip: 'Payment receipt',
              icon: const Icon(Icons.receipt_long_outlined),
              onPressed: () {
                final state = context.read<ManagementBloc>().state;
                if (state is ManagementLoaded) {
                  final tenant = state.tenants
                      .where((tenant) => tenant.tenantId == payment.tenantId)
                      .firstOrNull;
                  if (tenant != null) {
                    openTenantSharing(context, tenant, payment: payment);
                  }
                }
              })
        ]),
      ),
    );
  }

  Widget _buildExpenseItem(ExpenseModel expense) {
    final isRefund = expense.expenseType == ExpenseType.refund;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isRefund ? AppTheme.warningColor : AppTheme.errorColor)
                .withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isRefund ? Icons.keyboard_return : Icons.money_off,
            color: isRefund ? AppTheme.warningColor : AppTheme.errorColor,
            size: 20,
          ),
        ),
        title: Text(
          'د.إ${expense.amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isRefund ? AppTheme.warningColor : AppTheme.errorColor,
          ),
        ),
        subtitle: Text(
          isRefund
              ? 'Money Returned (Refund)'
              : expense.description ?? 'Expense',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
          ),
        ),
        trailing: Text(
          DateFormat('dd MMM yyyy').format(expense.date),
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryTextColor,
          ),
        ),
      ),
    );
  }

  void _showAddPaymentDialog(BuildContext context) {
    final managementBloc = context.read<ManagementBloc>();
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMonth =
        '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
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
                    const Text(
                      'Add Payment',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Record a new payment for this tenant',
                      style: TextStyle(color: AppTheme.secondaryTextColor),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: amountController,
                      decoration: const InputDecoration(
                        labelText: 'Payment Amount',
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                      keyboardType: TextInputType.number,
                      enabled: !isSubmitting,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: isSubmitting
                          ? null
                          : () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: const ColorScheme.light(
                                        primary: AppTheme.primaryColor,
                                        onPrimary: Colors.white,
                                        onSurface: AppTheme.textColor,
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (date != null) {
                                setState(() {
                                  selectedDate = date;
                                  selectedMonth =
                                      '${date.year}-${date.month.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Payment Date',
                                  style: TextStyle(
                                    color: AppTheme.secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  DateFormat('dd MMM yyyy')
                                      .format(selectedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              if (amountController.text.isEmpty) return;

                              setState(() {
                                isSubmitting = true;
                              });

                              final payment = PaymentModel(
                                tenantId: widget.tenantId,
                                amount:
                                    double.tryParse(amountController.text) ?? 0,
                                paymentMonth: selectedMonth,
                                paidDate: selectedDate,
                              );

                              managementBloc.add(AddPayment(payment));

                              await Future.delayed(
                                  const Duration(milliseconds: 500));

                              if (context.mounted) {
                                Navigator.pop(context);
                                managementBloc.add(
                                  LoadTenantBalance(widget.tenantId),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Confirm Payment'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed:
                          isSubmitting ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
