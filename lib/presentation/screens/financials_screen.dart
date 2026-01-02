import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/financial/financial_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../../data/models/payment_model.dart';
import '../theme/app_theme.dart';
import 'tenants_management_screen.dart';

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
      body: SafeArea(
        child: BlocBuilder<FinancialBloc, FinancialState>(
          builder: (context, state) {
            if (state is FinancialInitial) {
              context.read<FinancialBloc>().add(
                FinancialLoadRequested(month: _selectedMonth),
              );
              return const Center(child: CircularProgressIndicator());
            }

            if (state is FinancialLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
            }

            if (state is FinancialError) {
              return Center(child: Text('Error: ${state.message}'));
            }

            if (state is FinancialLoaded) {
              final paidTenants = state.tenantPayments
                  .where((tp) => tp.status == PaymentStatus.paid)
                  .toList();
              final partialTenants = state.tenantPayments
                  .where((tp) => tp.status == PaymentStatus.partial)
                  .toList();
              final overdueTenants = state.tenantPayments
                  .where((tp) => tp.status == PaymentStatus.overdue)
                  .toList();

              final totalRentalIncome = state.tenantPayments.fold<double>(
                0,
                (sum, tp) => sum + tp.rentAmount,
              );

              final totalCollected = state.tenantPayments.fold<double>(
                0,
                (sum, tp) => sum + tp.paidAmount,
              );

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<FinancialBloc>().add(
                    FinancialLoadRequested(month: _selectedMonth),
                  );
                },
                child: CustomScrollView(
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMonthSelector(state.month),
                            const SizedBox(height: 24),
                            _buildRevenueSummary(
                              totalCollected,
                              totalRentalIncome,
                              state.expenses,
                              state.profit,
                            ),
                            const SizedBox(height: 32),
                            _buildChartsSection(
                              paidTenants,
                              partialTenants,
                              overdueTenants,
                            ),
                            const SizedBox(height: 32),
                            if (overdueTenants.isEmpty &&
                                partialTenants.isEmpty &&
                                paidTenants.isEmpty)
                              const Center(
                                child: Text("No data for this month"),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (overdueTenants.isNotEmpty)
                      _buildTenantSection(
                        'Overdue',
                        overdueTenants,
                        PaymentStatus.overdue,
                      ),
                    if (partialTenants.isNotEmpty)
                      _buildTenantSection(
                        'Partially Paid',
                        partialTenants,
                        PaymentStatus.partial,
                      ),
                    if (paidTenants.isNotEmpty)
                      _buildTenantSection(
                        'Paid',
                        paidTenants,
                        PaymentStatus.paid,
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      expandedHeight: 120,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: false,
        titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Text(
          'Financials',
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24, // Explicit size for consistency
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.people_outline, color: AppTheme.textColor),
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
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMonthSelector(String currentMonth) {
    return GestureDetector(
      onTap: _selectMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _formatMonth(currentMonth),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              color: AppTheme.secondaryTextColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRevenueSummary(
    double collected,
    double expected,
    double expenses,
    double profit,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Collected Revenue',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${collected.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Net Profit',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${profit.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildSummaryChip('Expected', '₹${expected.toStringAsFixed(0)}'),
              const Spacer(),
              _buildSummaryChip('Expenses', '₹${expenses.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: expected > 0 ? collected / expected : 0,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              expected > 0
                  ? '${((collected / expected) * 100).toStringAsFixed(1)}%'
                  : '0%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.normal,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(List paid, List partial, List overdue) {
    // Safety check if all empty
    if (paid.isEmpty && partial.isEmpty && overdue.isEmpty)
      return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: Row(
        children: [
          // Pie Chart
          Expanded(
            flex: 4,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  if (paid.isNotEmpty)
                    PieChartSectionData(
                      color: AppTheme.successColor,
                      value: paid.length.toDouble(),
                      title: '',
                      radius: 25,
                    ),
                  if (partial.isNotEmpty)
                    PieChartSectionData(
                      color: Colors.orange,
                      value: partial.length.toDouble(),
                      title: '',
                      radius: 22,
                    ),
                  if (overdue.isNotEmpty)
                    PieChartSectionData(
                      color: AppTheme.errorColor, // Red for overdue
                      value: overdue.length.toDouble(),
                      title: '',
                      radius: 20,
                    ),
                ],
              ),
            ),
          ),
          // Legend/Stats
          Expanded(
            flex: 6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(
                  AppTheme.successColor,
                  'Paid',
                  paid.length.toString(),
                ),
                const SizedBox(height: 8),
                _buildLegendItem(
                  Colors.orange,
                  'Partial',
                  partial.length.toString(),
                ),
                const SizedBox(height: 8),
                _buildLegendItem(
                  AppTheme.errorColor,
                  'Overdue',
                  overdue.length.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  SliverList _buildTenantSection(
    String title,
    List items,
    PaymentStatus status,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case PaymentStatus.paid:
        statusColor = AppTheme.successColor;
        statusIcon = Icons.check;
        break;
      case PaymentStatus.partial:
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_filled; // Or similar
        break;
      case PaymentStatus.overdue:
        statusColor = AppTheme.errorColor;
        statusIcon = Icons.priority_high;
        break;
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        final TenantPaymentStatus item =
            items[index - 1]; // Cast for safety if needed, but list is typed
        final dueAmount = item.rentAmount - item.paidAmount;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: InkWell(
              onTap: status == PaymentStatus.paid
                  ? null // No action if already fully paid
                  : () => _showAddPaymentDialog(
                      context,
                      item.tenant.tenantId!,
                      item.tenant.tenantName,
                      _selectedMonth,
                      dueAmount,
                    ),
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                title: Text(
                  item.tenant.tenantName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Building :${item.buildingName ?? "Unknown"}',
                      style: const TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Room :${item.roomNumber ?? item.tenant.roomId}',
                      style: const TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),

                    if (status == PaymentStatus.partial)
                      Text(
                        'Paid: ₹${item.paidAmount.toStringAsFixed(0)} / ₹${item.rentAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${item.rentAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textColor,
                      ),
                    ),
                    if (status == PaymentStatus.overdue)
                      const Text(
                        'Tap to Pay',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (status == PaymentStatus.partial)
                      Text(
                        'Due: ₹${dueAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppTheme.errorColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }, childCount: items.length + 1),
    );
  }

  void _showAddPaymentDialog(
    BuildContext context,
    String tenantId,
    String tenantName,
    String month,
    double dueAmount,
  ) {
    final managementBloc = context.read<ManagementBloc>();
    final amountController = TextEditingController(
      text: dueAmount.toInt().toString(),
    );
    DateTime selectedDate = DateTime.now();

    // Parse month string to get correct year/month for the payment
    try {
      // Validate month format just in case
      month.split('-');
      // If we are paying for a past month, default date to end of that month or today?
      // Usually payment date is TODAY even if it's for a past month.
      // So selectedDate = DateTime.now() is correct for "Paid Date".
    } catch (_) {}

    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text(
            'Add Payment for $tenantName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  labelStyle: TextStyle(color: AppTheme.secondaryTextColor),
                  prefixText: '₹ ',
                ),
                keyboardType: TextInputType.number,
                enabled: !isSubmitting,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Payment Month',
                  style: TextStyle(color: AppTheme.secondaryTextColor),
                ),
                subtitle: Text(
                  _formatMonth(month),
                  style: const TextStyle(
                    color: AppTheme.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(
                  Icons.calendar_today,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (amountController.text.isEmpty) return;

                      setState(() {
                        isSubmitting = true;
                      });

                      final payment = PaymentModel(
                        tenantId: tenantId,
                        amount: double.tryParse(amountController.text) ?? 0,
                        paymentMonth: month, // The month of the report
                        paidDate: selectedDate, // The actual date paid
                      );

                      managementBloc.add(AddPayment(payment));

                      await Future.delayed(const Duration(milliseconds: 500));

                      if (context.mounted) {
                        Navigator.pop(context);
                        // Refresh Financial Data
                        context.read<FinancialBloc>().add(
                          FinancialLoadRequested(month: _selectedMonth),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                disabledBackgroundColor: AppTheme.primaryColor.withOpacity(0.6),
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
                  : const Text('Add Payment'),
            ),
          ],
        ),
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
        _selectedMonth =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
      context.read<FinancialBloc>().add(FinancialMonthChanged(_selectedMonth));
    }
  }
}
