import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/management/management_bloc.dart';
import '../blocs/auth/auth_bloc.dart';
import '../../data/models/tenant_model.dart';
import '../../data/models/building_model.dart';
import '../../data/models/room_model.dart';
import '../../data/models/bed_model.dart';
import '../../data/models/payment_model.dart';
import '../../data/services/google_sheets_service.dart';
import '../theme/app_theme.dart';

class TenantsManagementScreen extends StatelessWidget {
  const TenantsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Tenants'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddTenantDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementInitial) {
            context.read<ManagementBloc>().add(const LoadTenants());
            context.read<ManagementBloc>().add(const LoadBuildings());
            context.read<ManagementBloc>().add(const LoadRooms());
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
                      context.read<ManagementBloc>().add(const LoadTenants());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is TenantsLoaded) {
            final activeTenants = state.tenants.where((t) => t.active).toList();
            
            if (activeTenants.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_outline, size: 64, color: AppTheme.textColor),
                    const SizedBox(height: 16),
                    const Text('No tenants found'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _showAddTenantDialog(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Tenant'),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ManagementBloc>().add(const LoadTenants());
              },
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: activeTenants.length,
                itemBuilder: (context, index) {
                  final tenant = activeTenants[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.person, color: AppTheme.primaryColor),
                      title: Text(
                        tenant.tenantName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Phone: ${tenant.phone}'),
                          Text('Room: ${tenant.roomId}'),
                          Text('Rent: ₹${tenant.rentAmount.toStringAsFixed(0)}/month'),
                          Text('Due Day: ${tenant.rentDueDay}'),
                          Text('Joined: ${DateFormat('dd MMM yyyy').format(tenant.joiningDate)}'),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.account_balance_wallet, color: AppTheme.accentColor),
                            onPressed: () => _navigateToRentBalance(context, tenant.tenantId ?? ''),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                            onPressed: () => _showEditTenantDialog(context, tenant),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                            onPressed: () => _showDeleteConfirmation(context, tenant),
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

  Future<List<BedModel>> _getAvailableBeds(BuildContext context, String roomId) async {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      final sheetsService = GoogleSheetsService(
        accessToken: authState.accessToken,
        sheetId: authState.sheetId,
      );
      final beds = await sheetsService.getBeds();
      return beds.where((bed) => bed.roomId == roomId && bed.status == BedStatus.vacant).toList();
    }
    return [];
  }

  void _showAddTenantDialog(BuildContext context) async {
    context.read<ManagementBloc>().add(const LoadBuildings());
    context.read<ManagementBloc>().add(const LoadRooms());
    
    await Future.delayed(const Duration(milliseconds: 500));

    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final rentController = TextEditingController(text: '0');
    final dueDayController = TextEditingController(text: '1');
    DateTime selectedDate = DateTime.now();
    String? selectedBuildingId;
    String? selectedRoomId;
    String? selectedBedId;

    showDialog(
      context: context,
      builder: (context) => BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          List<BuildingModel> buildings = [];
          List<RoomModel> rooms = [];
          if (state is BuildingsLoaded) {
            buildings = state.buildings;
          }
          if (state is RoomsLoaded) {
            rooms = state.rooms;
          }

          final filteredRooms = selectedBuildingId != null
              ? rooms.where((r) => r.buildingId == selectedBuildingId).toList()
              : [];

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('Add Tenant'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Tenant Name'),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                    DropdownButtonFormField<String>(
                      value: selectedBuildingId,
                      decoration: const InputDecoration(labelText: 'Building'),
                      items: buildings.map<DropdownMenuItem<String>>((b) => DropdownMenuItem<String>(
                        value: b.buildingId,
                        child: Text(b.buildingName),
                      )).toList(),
                      onChanged: (value) => setState(() {
                        selectedBuildingId = value;
                        selectedRoomId = null;
                        selectedBedId = null;
                      }),
                    ),
                    if (selectedBuildingId != null)
                      DropdownButtonFormField<String>(
                        value: selectedRoomId,
                        decoration: const InputDecoration(labelText: 'Room'),
                        items: filteredRooms.map<DropdownMenuItem<String>>((r) => DropdownMenuItem<String>(
                            value: r.roomId,
                            child: Text('Room ${r.roomNumber}'),
                          )).toList(),
                        onChanged: (value) => setState(() {
                          selectedRoomId = value;
                          selectedBedId = null;
                        }),
                      ),
                    if (selectedRoomId != null)
                      FutureBuilder<List<BedModel>>(
                        future: _getAvailableBeds(context, selectedRoomId!),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircularProgressIndicator();
                          }
                          final beds = snapshot.data ?? [];
                          if (beds.isEmpty) {
                            return const Text('No available beds in this room', style: TextStyle(color: AppTheme.errorColor));
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedBedId,
                            decoration: const InputDecoration(labelText: 'Bed'),
                            items: beds.map<DropdownMenuItem<String>>((bed) => DropdownMenuItem<String>(
                              value: bed.bedId,
                              child: Text('${bed.bedType == BedType.lower ? "Lower" : "Upper"} Bed'),
                            )).toList(),
                            onChanged: (value) => setState(() => selectedBedId = value),
                          );
                        },
                      ),
                    TextField(
                      controller: rentController,
                      decoration: const InputDecoration(labelText: 'Rent Amount (Monthly)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextField(
                      controller: dueDayController,
                      decoration: const InputDecoration(labelText: 'Rent Due Day (1-31)'),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      title: const Text('Joining Date'),
                      subtitle: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (date != null) {
                          setState(() => selectedDate = date);
                        }
                      },
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
                  onPressed: (selectedBuildingId == null || selectedRoomId == null || selectedBedId == null) ? null : () {
                    final tenant = TenantModel(
                      tenantName: nameController.text,
                      phone: phoneController.text,
                      buildingId: selectedBuildingId!,
                      roomId: selectedRoomId!,
                      bedId: selectedBedId!,
                      rentAmount: double.tryParse(rentController.text) ?? 0,
                      joiningDate: selectedDate,
                      rentDueDay: int.tryParse(dueDayController.text) ?? 1,
                      active: true,
                    );
                    context.read<ManagementBloc>().add(AddTenant(tenant));
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

  void _showEditTenantDialog(BuildContext context, TenantModel tenant) {
    final nameController = TextEditingController(text: tenant.tenantName);
    final phoneController = TextEditingController(text: tenant.phone);
    final rentController = TextEditingController(text: tenant.rentAmount.toString());
    final dueDayController = TextEditingController(text: tenant.rentDueDay.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tenant Name'),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              TextField(
                controller: rentController,
                decoration: const InputDecoration(labelText: 'Rent Amount (Monthly)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: dueDayController,
                decoration: const InputDecoration(labelText: 'Rent Due Day (1-31)'),
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
              final updated = TenantModel(
                tenantId: tenant.tenantId,
                tenantName: nameController.text,
                phone: phoneController.text,
                buildingId: tenant.buildingId,
                roomId: tenant.roomId,
                bedId: tenant.bedId,
                rentAmount: double.tryParse(rentController.text) ?? 0,
                joiningDate: tenant.joiningDate,
                rentDueDay: int.tryParse(dueDayController.text) ?? 1,
                active: tenant.active,
              );
              context.read<ManagementBloc>().add(UpdateTenant(updated));
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, TenantModel tenant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Tenant?'),
        content: Text('Are you sure you want to remove ${tenant.tenantName}? The bed will be marked as vacant.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (tenant.tenantId != null) {
                context.read<ManagementBloc>().add(DeleteTenant(tenant.tenantId!));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _navigateToRentBalance(BuildContext context, String tenantId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RentBalanceScreen(tenantId: tenantId),
      ),
    );
  }
}

class RentBalanceScreen extends StatelessWidget {
  final String tenantId;

  const RentBalanceScreen({super.key, required this.tenantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Rent Balance & Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPaymentDialog(context),
          ),
        ],
      ),
      body: BlocBuilder<ManagementBloc, ManagementState>(
        builder: (context, state) {
          if (state is ManagementInitial) {
            context.read<ManagementBloc>().add(LoadTenantBalance(tenantId));
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
                      context.read<ManagementBloc>().add(LoadTenantBalance(tenantId));
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is TenantBalanceLoaded) {
            final balance = state.balance;
            final totalDue = balance['totalDue'] as double;
            final totalPaid = balance['totalPaid'] as double;
            final rentBalance = balance['balance'] as double;
            final payments = balance['payments'] as List<PaymentModel>;
            final tenant = balance['tenant'] as TenantModel;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ManagementBloc>().add(LoadTenantBalance(tenantId));
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balance Summary Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tenant.tenantName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildBalanceRow('Total Due', '₹${totalDue.toStringAsFixed(0)}', AppTheme.textColor),
                            _buildBalanceRow('Total Paid', '₹${totalPaid.toStringAsFixed(0)}', AppTheme.successColor),
                            const Divider(),
                            _buildBalanceRow(
                              'Balance',
                              '₹${rentBalance.abs().toStringAsFixed(0)}',
                              rentBalance >= 0 ? AppTheme.successColor : AppTheme.errorColor,
                              isBold: true,
                            ),
                            if (rentBalance < 0)
                              Text(
                                'Overdue Amount',
                                style: TextStyle(
                                  color: AppTheme.errorColor,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Payment History
                    const Text(
                      'Payment History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (payments.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No payments recorded'),
                        ),
                      )
                    else
                      ...payments.map((payment) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.payment, color: AppTheme.successColor),
                          title: Text('₹${payment.amount.toStringAsFixed(0)}'),
                          subtitle: Text('Month: ${payment.paymentMonth}'),
                          trailing: Text(
                            DateFormat('dd MMM yyyy').format(payment.paidDate),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      )),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildBalanceRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: AppTheme.textColor,
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

  void _showAddPaymentDialog(BuildContext context) {
    final amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    String selectedMonth = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Payment Month'),
                subtitle: Text(selectedMonth),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      selectedDate = date;
                      selectedMonth = '${date.year}-${date.month.toString().padLeft(2, '0')}';
                    });
                  }
                },
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
                final payment = PaymentModel(
                  tenantId: tenantId,
                  amount: double.tryParse(amountController.text) ?? 0,
                  paymentMonth: selectedMonth,
                  paidDate: selectedDate,
                );
                context.read<ManagementBloc>().add(AddPayment(payment));
                Navigator.pop(context);
                // Reload balance
                context.read<ManagementBloc>().add(LoadTenantBalance(tenantId));
              },
              child: const Text('Add Payment'),
            ),
          ],
        ),
      ),
    );
  }
}

