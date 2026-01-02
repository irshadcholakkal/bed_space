import 'package:bed_space/presentation/blocs/room/room_bloc.dart';
import 'package:bed_space/presentation/screens/rooms_management_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../blocs/management/management_bloc.dart' as management_bloc;
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import 'buildings_management_screen.dart';
import 'rooms_screen.dart';
import 'tenants_management_screen.dart';
import 'vacant_beds_screen.dart';

/// Dashboard Screen
/// Shows overview statistics and current month financials
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.business),
            tooltip: 'Manage Buildings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ManagementBloc>(),
                    child: const BuildingsManagementScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is DashboardError) {
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
                    'Error: ${state.message}',
                    style: const TextStyle(color: AppTheme.textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DashboardBloc>().add(
                        const DashboardLoadRequested(),
                      );
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is DashboardLoaded) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(DashboardLoadRequested());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview Stats
                    Text(
                      'Overview',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor,
                          ),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // We can add a filter or date selector here later akin to Airbnb
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Buildings',
                            value: state.totalBuildings.toString(),
                            icon: Icons.apartment, // More Airbnb-like icon
                            color: AppTheme.primaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<ManagementBloc>(),
                                    child: const BuildingsManagementScreen(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            title: 'Rooms',
                            value: state.totalRooms.toString(),
                            icon: Icons.meeting_room,
                            color: AppTheme.secondaryColor,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context.read<RoomBloc>(),
                                    child: const RoomsScreen(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Total Beds',
                            value: state.totalBeds.toString(),
                            icon: Icons.single_bed,
                            color: AppTheme.textColor, // Neutral for total
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatCard(
                            title: 'Occupied',
                            value: state.occupiedBeds.toString(),
                            icon: Icons.people,
                            color: AppTheme.successColor,

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider.value(
                                    value: context
                                        .read<management_bloc.ManagementBloc>(),
                                    child: const TenantsManagementScreen(),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    StatCard(
                      title: 'Available Beds',
                      value: state.vacantBeds.toString(),
                      icon: Icons.event_available,
                      color: AppTheme.primaryColor, // Highlight availability
                      fullWidth: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: context.read<ManagementBloc>(),
                              child: const VacantBedsScreen(),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 48),

                    // Current Month Financials
                    Text(
                      'Financials',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textColor,
                          ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildFinancialRow(
                              'Rent Collected',
                              '₹${state.rentCollected.toStringAsFixed(0)}',
                              AppTheme.successColor,
                            ),
                            const Divider(),
                            _buildFinancialRow(
                              'Utility Expenses',
                              '₹${state.utilityExpenses.toStringAsFixed(0)}',
                              AppTheme.textColor,
                            ),
                            const Divider(),
                            _buildFinancialRow(
                              state.profit >= 0 ? 'Profit' : 'Loss',
                              '₹${state.profit.abs().toStringAsFixed(0)}',
                              state.profit >= 0
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                              isBold: true,
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildFinancialRow(
    String label,
    String value,
    Color valueColor, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
}
