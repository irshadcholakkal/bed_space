import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/financial/financial_bloc.dart';
import '../blocs/management/management_bloc.dart';
import '../../data/models/payment_model.dart';
import '../../data/models/expense_model.dart';
import '../theme/app_theme.dart';
import '../widgets/sharing_actions.dart';

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
    // Trigger load on entry to avoid stale data from other months
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context
            .read<FinancialBloc>()
            .add(FinancialLoadRequested(month: _selectedMonth));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: BlocBuilder<FinancialBloc, FinancialState>(
          builder: (context, state) {
            if (state is FinancialInitial) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              );
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
                  context
                      .read<FinancialBloc>()
                      .add(FinancialLoadRequested(month: _selectedMonth));
                  // Wait a brief moment to show the spinner, but don't block forever
                  await Future.delayed(const Duration(seconds: 1));
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
                              totalCollected - state.totalRefunds,
                              totalRentalIncome,
                              state.expenses,
                              state.totalRefunds,
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
                    if (state.monthExpenses.isNotEmpty)
                      _buildExpensesSection(state.monthExpenses),
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
            context.push('/tenants');
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildMonthSelector(String currentMonth) {
    return GestureDetector(
      onTap: () => _selectMonth(currentMonth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
    double refunds,
    double profit,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
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
                    'Net Revenue',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'د.إ${collected.toStringAsFixed(0)}',
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
                    'د.إ${profit.toStringAsFixed(0)}',
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSummaryChip(
                  'Expected', 'د.إ${expected.toStringAsFixed(0)}'),
              _buildSummaryChip(
                  'Expenses', 'د.إ${expenses.toStringAsFixed(0)}'),
              _buildSummaryChip('Refunds', 'د.إ${refunds.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: expected > 0 ? collected / expected : 0,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
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
        color: Colors.white.withValues(alpha: 0.2),
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
    if (paid.isEmpty && partial.isEmpty && overdue.isEmpty) {
      return const SizedBox.shrink();
    }

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
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
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
                  backgroundColor: statusColor.withValues(alpha: 0.1),
                  child: Icon(statusIcon, color: statusColor, size: 18),
                ),
                title: Text(
                  '${item.tenant.tenantName}${!item.tenant.active ? " (Checked Out)" : ""}',
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
                      item.roomNumber ?? 'Room ${item.tenant.roomId}',
                      style: const TextStyle(
                        color: AppTheme.secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                    if (status == PaymentStatus.partial)
                      Text(
                        'Paid: د.إ${item.paidAmount.toStringAsFixed(0)} / د.إ${item.rentAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'د.إ${item.rentAmount.toStringAsFixed(0)}',
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
                          'Due: د.إ${dueAmount.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                      tooltip: 'WhatsApp, invoice & receipts',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () => openTenantSharing(context, item.tenant,
                          month: _selectedMonth)),
                ]),
              ),
            ),
          ),
        );
      }, childCount: items.length + 1),
    );
  }

  SliverList _buildExpensesSection(List<ExpenseModel> expenses) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Text(
              'EXPENSES & REFUNDS',
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          );
        }
        final expense = expenses[index - 1];
        final isRefund = expense.expenseType == ExpenseType.refund;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor:
                    (isRefund ? AppTheme.warningColor : AppTheme.errorColor)
                        .withValues(alpha: 0.1),
                child: Icon(
                  isRefund ? Icons.keyboard_return : Icons.money_off,
                  color: isRefund ? AppTheme.warningColor : AppTheme.errorColor,
                  size: 18,
                ),
              ),
              title: Text(
                isRefund ? 'Money Returned (Refund)' : expense.description!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor,
                ),
              ),
              subtitle: Text(
                DateFormat('dd MMM yyyy').format(expense.date),
                style: const TextStyle(
                  color: AppTheme.secondaryTextColor,
                  fontSize: 13,
                ),
              ),
              trailing: Text(
                'د.إ${expense.amount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isRefund ? AppTheme.warningColor : AppTheme.errorColor,
                ),
              ),
            ),
          ),
        );
      }, childCount: expenses.length + 1),
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
                    Text(
                      'Add Payment',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recording payment for $tenantName',
                      style:
                          const TextStyle(color: AppTheme.secondaryTextColor),
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
                    Container(
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
                                'Payment Month',
                                style: TextStyle(
                                  color: AppTheme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                _formatMonth(month),
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
                                tenantId: tenantId,
                                amount:
                                    double.tryParse(amountController.text) ?? 0,
                                paymentMonth: month,
                                paidDate: selectedDate,
                              );

                              managementBloc.add(AddPayment(payment));

                              await Future.delayed(
                                  const Duration(milliseconds: 500));

                              if (context.mounted) {
                                Navigator.pop(context);
                                context.read<FinancialBloc>().add(
                                      FinancialLoadRequested(
                                          month: _selectedMonth),
                                    );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
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

  Future<void> _selectMonth(String currentMonth) async {
    final financialBloc = context.read<FinancialBloc>();
    final parts = currentMonth.split('-');
    int selectedYear = int.parse(parts[0]);
    int selectedMonth = int.parse(parts[1]);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (sheetContext) => BlocProvider.value(
        value: financialBloc,
        child: StatefulBuilder(
          builder: (stateContext, setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Text(
                    'Select Month',
                    style:
                        Theme.of(stateContext).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textColor,
                            ),
                  ),
                  const SizedBox(height: 24),
                  // Year Selector
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left,
                              color: AppTheme.primaryColor),
                          onPressed: () => setModalState(() => selectedYear--),
                        ),
                        Text(
                          '$selectedYear',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right,
                              color: AppTheme.primaryColor),
                          onPressed: () => setModalState(() => selectedYear++),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Month Grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: 12,
                    itemBuilder: (gridContext, index) {
                      final monthIndex = index + 1;
                      final isSelected = selectedMonth == monthIndex;
                      final monthName =
                          DateFormat('MMMM').format(DateTime(2022, monthIndex));

                      // Check if the month is in the future
                      final now = DateTime.now();
                      final isFuture = selectedYear > now.year ||
                          (selectedYear == now.year && monthIndex > now.month);

                      return InkWell(
                        onTap: isFuture
                            ? null
                            : () async {
                                setModalState(() => selectedMonth = monthIndex);
                                final newMonthStr =
                                    '$selectedYear-${monthIndex.toString().padLeft(2, '0')}';

                                setState(() {
                                  _selectedMonth = newMonthStr;
                                });

                                // Use the captured bloc directly
                                // financialBloc.add(FinancialMonthChanged(newMonthStr));
                                financialBloc.add(
                                    FinancialLoadRequested(month: newMonthStr));
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                                if (!sheetContext.mounted) return;
                                Navigator.pop(sheetContext);
                              },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor
                                : isFuture
                                    ? Colors.grey.shade50
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : isFuture
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade200,
                              width: 1.5,
                            ),
                            boxShadow: (isSelected && !isFuture)
                                ? [
                                    BoxShadow(
                                      color: AppTheme.primaryColor
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    )
                                  ]
                                : null,
                          ),
                          child: Text(
                            monthName,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : isFuture
                                      ? Colors.grey.shade400
                                      : AppTheme.textColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
