import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/financial/financial_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../theme/app_theme.dart';
import 'tenants_management_screen.dart';

/// Financials Screen
/// Shows tenant payments and room-wise totals for selected month
class FinancialsScreen extends StatefulWidget {
  const FinancialsScreen({super.key});

  @override
  State<FinancialsScreen> createState() => _FinancialsScreenState();
}

class _FinancialsScreenState extends State<FinancialsScreen> {
  late String _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'Financials',
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
            icon: const Icon(Icons.calendar_today_outlined, color: AppTheme.textColor),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
          IconButton(
            icon: const Icon(Icons.people_outline, color: AppTheme.textColor),
            tooltip: 'Manage Tenants',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ManagementBloc>(),
                    child: const TenantsManagementScreen(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<FinancialBloc, FinancialState>(
        builder: (context, state) {
          if (state is FinancialInitial) {
            context.read<FinancialBloc>().add(
                  FinancialLoadRequested(month: _selectedMonth),
                );
          }

          if (state is FinancialLoading) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
          }

          if (state is FinancialError) {
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
                      context.read<FinancialBloc>().add(
                            FinancialLoadRequested(month: _selectedMonth),
                          );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (state is FinancialLoaded) {
            final unpaidTenants = state.tenantPayments.where((tp) => !tp.hasPaid).toList();
            final paidTenants = state.tenantPayments.where((tp) => tp.hasPaid).toList();

            return RefreshIndicator(
              color: AppTheme.primaryColor,
              onRefresh: () async {
                context.read<FinancialBloc>().add(
                      FinancialLoadRequested(month: _selectedMonth),
                    );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Selector
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: AppTheme.cardDecoration,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Overview For',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.secondaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMonth(state.month),
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.calendar_month, color: AppTheme.primaryColor),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Unpaid Tenants
                    if (unpaidTenants.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
                          const SizedBox(width: 8),
                          Text(
                            'Pending Payments',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${unpaidTenants.length}',
                              style: const TextStyle(
                                color: AppTheme.warningColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...unpaidTenants.map((tp) => _buildTenantCard(tp, false)),
                      const SizedBox(height: 32),
                    ],

                    // Paid Tenants
                    if (paidTenants.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppTheme.successColor),
                          const SizedBox(width: 8),
                          Text(
                            'Received Payments',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.successColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${paidTenants.length}',
                              style: const TextStyle(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...paidTenants.map((tp) => _buildTenantCard(tp, true)),
                      const SizedBox(height: 32),
                    ],

                    // Summary
                    Text(
                      'Monthly Summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryRow(
                            context,
                            'Total Tenants',
                            state.tenantPayments.length.toString(),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                          _buildSummaryRow(
                            context,
                            'Paid Count',
                            paidTenants.length.toString(),
                            valueColor: AppTheme.successColor,
                          ),
                          _buildSummaryRow(
                            context,
                            'Unpaid Count',
                            unpaidTenants.length.toString(),
                            valueColor: AppTheme.errorColor,
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                          _buildSummaryRow(
                            context,
                            'Expected Revenue',
                            '₹${state.tenantPayments.fold<double>(0, (sum, tp) => sum + tp.amount).toStringAsFixed(0)}',
                            isBold: true,
                          ),
                          _buildSummaryRow(
                            context,
                            'Collected Revenue',
                            '₹${paidTenants.fold<double>(0, (sum, tp) => sum + tp.amount).toStringAsFixed(0)}',
                            valueColor: AppTheme.successColor,
                            isBold: true,
                          ),
                        ],
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

  Widget _buildTenantCard(tp, bool isPaid) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration.copyWith(
        border: Border.all(
          color: isPaid ? AppTheme.successColor.withOpacity(0.3) : AppTheme.warningColor.withOpacity(0.3),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isPaid ? AppTheme.successColor.withOpacity(0.1) : AppTheme.warningColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isPaid ? Icons.check : Icons.priority_high,
            color: isPaid ? AppTheme.successColor : AppTheme.warningColor,
            size: 20,
          ),
        ),
        title: Text(
          tp.tenant.tenantName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textColor,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Room ${tp.tenant.roomId} • ${tp.tenant.phone}',
              style: const TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
            ),
            if (isPaid && tp.paidDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Paid: ${DateFormat('dd MMM').format(tp.paidDate!)}',
                  style: const TextStyle(color: AppTheme.successColor, fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
        trailing: Text(
          '₹${tp.amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isPaid ? AppTheme.successColor : AppTheme.textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, String value, {Color? valueColor, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.secondaryTextColor,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? AppTheme.textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonth(String month) {
    try {
      final parts = month.split('-');
      final year = int.parse(parts[0]);
      final monthNum = int.parse(parts[1]);
      final date = DateTime(year, monthNum);
      return DateFormat('MMMM yyyy').format(date);
    } catch (e) {
      return month;
    }
  }

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1, 1);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: firstDate,
      lastDate: lastDate,
      initialDatePickerMode: DatePickerMode.year,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              onSurface: AppTheme.textColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedMonth = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
      context.read<FinancialBloc>().add(
            FinancialMonthChanged(_selectedMonth),
          );
    }
  }
}

