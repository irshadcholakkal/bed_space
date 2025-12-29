import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/financial/financial_bloc.dart';
import '../theme/app_theme.dart';

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
        title: const Text('Financials'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectMonth,
            tooltip: 'Select Month',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Manage Tenants',
            onPressed: () {
              Navigator.pushNamed(context, '/tenants');
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
            return const Center(child: CircularProgressIndicator());
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
              onRefresh: () async {
                context.read<FinancialBloc>().add(
                      FinancialLoadRequested(month: _selectedMonth),
                    );
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Selector
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Selected Month:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor,
                              ),
                            ),
                            Text(
                              _formatMonth(state.month),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Unpaid Tenants
                    if (unpaidTenants.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.warning, color: AppTheme.warningColor),
                          const SizedBox(width: 8),
                          Text(
                            'Unpaid (${unpaidTenants.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...unpaidTenants.map((tp) => _buildTenantCard(tp, false)),
                      const SizedBox(height: 24),
                    ],

                    // Paid Tenants
                    if (paidTenants.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppTheme.successColor),
                          const SizedBox(width: 8),
                          Text(
                            'Paid (${paidTenants.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...paidTenants.map((tp) => _buildTenantCard(tp, true)),
                    ],

                    // Summary
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'Total Tenants',
                              state.tenantPayments.length.toString(),
                            ),
                            _buildSummaryRow(
                              'Paid',
                              paidTenants.length.toString(),
                              AppTheme.successColor,
                            ),
                            _buildSummaryRow(
                              'Unpaid',
                              unpaidTenants.length.toString(),
                              AppTheme.errorColor,
                            ),
                            const Divider(),
                            _buildSummaryRow(
                              'Total Expected',
                              '₹${state.tenantPayments.fold<double>(0, (sum, tp) => sum + tp.amount).toStringAsFixed(0)}',
                            ),
                            _buildSummaryRow(
                              'Total Collected',
                              '₹${paidTenants.fold<double>(0, (sum, tp) => sum + tp.amount).toStringAsFixed(0)}',
                              AppTheme.successColor,
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

  Widget _buildTenantCard(tp, bool isPaid) {
    return Card(
      color: isPaid
          ? AppTheme.successColor.withOpacity(0.2)
          : AppTheme.errorColor.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isPaid ? Icons.check_circle : Icons.pending,
          color: isPaid ? AppTheme.successColor : AppTheme.errorColor,
        ),
        title: Text(
          tp.tenant.tenantName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room: ${tp.tenant.roomId}'),
            Text('Phone: ${tp.tenant.phone}'),
            if (isPaid && tp.paidDate != null)
              Text('Paid: ${DateFormat('dd MMM yyyy').format(tp.paidDate!)}'),
          ],
        ),
        trailing: Text(
          '₹${tp.amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isPaid ? AppTheme.successColor : AppTheme.errorColor,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.normal,
              color: AppTheme.textColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
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

