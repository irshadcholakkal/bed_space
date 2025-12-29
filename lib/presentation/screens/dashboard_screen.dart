import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/dashboard/dashboard_bloc.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

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
              Navigator.pushNamed(context, '/buildings');
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
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${state.message}',
                    style: const TextStyle(color: AppTheme.textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<DashboardBloc>().add(const DashboardLoadRequested());
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
                    const Text(
                      'Overview',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Buildings',
                            value: state.totalBuildings.toString(),
                            icon: Icons.business,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Rooms',
                            value: state.totalRooms.toString(),
                            icon: Icons.door_front_door,
                            color: AppTheme.accentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            title: 'Total Beds',
                            value: state.totalBeds.toString(),
                            icon: Icons.bed,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: StatCard(
                            title: 'Occupied',
                            value: state.occupiedBeds.toString(),
                            icon: Icons.person,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    StatCard(
                      title: 'Vacant Beds',
                      value: state.vacantBeds.toString(),
                      icon: Icons.event_available,
                      color: AppTheme.accentColor,
                      fullWidth: true,
                    ),
                    const SizedBox(height: 32),
                    
                    // Current Month Financials
                    const Text(
                      'Current Month',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
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
                              state.profit >= 0 ? AppTheme.successColor : AppTheme.errorColor,
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

  Widget _buildFinancialRow(String label, String value, Color valueColor, {bool isBold = false}) {
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

