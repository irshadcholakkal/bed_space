import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/models/bed_model.dart';
import '../../data/repositories/management_repository.dart';
import '../../data/models/property_financials.dart';
import '../../data/models/room_model.dart';
import '../blocs/management/management_bloc.dart';
import '../theme/app_theme.dart';

const _paper = AppTheme.backgroundColor;
const _ink = AppTheme.textColor;
const _muted = AppTheme.secondaryTextColor;
const _green = AppTheme.successColor;
const _cost = AppTheme.errorColor;

/// Shared building > room > subroom navigation for property and finance views.
class PropertyPortfolioScreen extends StatefulWidget {
  final bool financial;
  final String? buildingId;
  final String? roomId;
  final String? period;
  const PropertyPortfolioScreen(
      {super.key,
      this.financial = false,
      this.buildingId,
      this.roomId,
      this.period});
  @override
  State<PropertyPortfolioScreen> createState() =>
      _PropertyPortfolioScreenState();
}

class _PropertyPortfolioScreenState extends State<PropertyPortfolioScreen> {
  late String? _month = widget.period == 'all' ||
          (widget.period == null && widget.buildingId != null)
      ? null
      : RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(widget.period ?? '')
          ? widget.period
          : DateFormat('yyyy-MM').format(DateTime.now());
  String _search = '';
  bool _showAll = false;
  bool _showActivity = false;
  String get _base => widget.financial ? '/financials' : '/rooms';
  String _money(double value) =>
      'AED ${NumberFormat('#,##0.00').format(value)}';

  void _open({String? building, String? room}) {
    context.push(Uri(path: _base, queryParameters: {
      'period': _month ?? 'all',
      if (building != null) 'building': building,
      if (room != null) 'room': room,
    }).toString());
  }

  TextStyle _heading(double size) => TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: size.clamp(20, 28).toDouble(),
      height: 1.15,
      letterSpacing: -.7,
      color: _ink);

  @override
  Widget build(BuildContext context) => Theme(
        data: AppTheme.theme,
        child: Scaffold(
            backgroundColor: _paper,
            appBar: AppBar(
              title: Text(widget.roomId != null
                  ? 'Room details'
                  : widget.buildingId != null
                      ? 'Building overview'
                      : 'Properties'),
            ),
            body: SafeArea(child: BlocBuilder<ManagementBloc, ManagementState>(
                builder: (context, state) {
              if (state is! ManagementLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.isLoading && state.buildings.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final room = state.rooms
                  .where((r) => r.roomId == widget.roomId)
                  .firstOrNull;
              final buildingId = room?.buildingId ?? widget.buildingId;
              final building = state.buildings
                  .where((b) => b.buildingId == buildingId)
                  .firstOrNull;
              if ((widget.roomId != null && room == null) ||
                  (buildingId != null && building == null)) {
                return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('This space is no longer available.'),
                  TextButton(
                      onPressed: () => context.go(_base),
                      child: const Text('View all buildings')),
                ]));
              }
              final report = PropertyFinancials(
                  rooms: state.rooms,
                  tenants: state.tenants,
                  payments: state.payments,
                  expenses: state.expenses,
                  month: _month);
              final ids =
                  report.roomIds(buildingId: buildingId, roomId: room?.roomId);
              final totals = report.totals(ids);
              final subrooms = room == null
                  ? <RoomModel>[]
                  : state.rooms
                      .where((r) =>
                          r.parentRoomId == room.roomId &&
                          r.buildingId == room.buildingId)
                      .toList();
              final title = room?.displayName(state.rooms) ??
                  building?.buildingName ??
                  (widget.financial
                      ? 'Every space.\nEvery dirham.'
                      : 'Your spaces.\nIn perspective.');
              final transactions = report.transactions(ids);
              final scopedRooms =
                  state.rooms.where((r) => ids.contains(r.roomId)).toList();
              final beds =
                  state.beds.where((b) => ids.contains(b.roomId)).toList();
              final vacant =
                  beds.where((b) => b.status == BedStatus.vacant).length;
              return RefreshIndicator(
                onRefresh: () =>
                    context.read<ManagementRepository>().triggerSync(),
                child: ListView(
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            MediaQuery.sizeOf(context).width >= 960 ? 48 : 20,
                        vertical: 24),
                    children: [
                      Center(
                          child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(title, style: _heading(40)),
                                    const SizedBox(height: 12),
                                    Text(
                                        room != null
                                            ? (room.isSubroom
                                                ? 'Income and expenses for this subroom only.'
                                                : 'This room and its subrooms, together with a clear breakdown.')
                                            : building != null
                                                ? 'All rooms and subrooms in this building, in one place.'
                                                : 'Follow your buildings into rooms and subrooms. See what each space earns and costs.',
                                        style: const TextStyle(
                                            color: _muted, height: 1.7)),
                                    const SizedBox(height: 24),
                                    if (building != null && room == null) ...[
                                      ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          leading: const Icon(
                                              CupertinoIcons.location,
                                              color: _muted,
                                              size: 20),
                                          title: const Text('Building details',
                                              style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          subtitle: Text(
                                              '${building.address.trim().isEmpty ? 'No address added' : building.address}\n${state.tenants.where((t) => t.active && ids.contains(t.roomId)).length} active tenants',
                                              style: const TextStyle(
                                                  color: _muted,
                                                  fontSize: 12,
                                                  height: 1.5))),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(children: [
                                      Expanded(child: _periodControl(state)),
                                      PopupMenuButton<String>(
                                        tooltip: 'More actions',
                                        icon: const Icon(
                                            CupertinoIcons.ellipsis_vertical),
                                        onSelected: (path) =>
                                            context.push(path),
                                        itemBuilder: (_) => [
                                          if (room != null)
                                            PopupMenuItem(
                                                value:
                                                    '/rooms/${room.roomId}/expenses',
                                                child: const Text(
                                                    'Add or view expenses')),
                                          const PopupMenuItem(
                                              value: '/financials/tenants',
                                              child: Text('Tenant payments')),
                                          const PopupMenuItem(
                                              value: '/rooms/occupancy',
                                              child:
                                                  Text('Beds & availability')),
                                          PopupMenuItem(
                                              value: building == null
                                                  ? '/buildings'
                                                  : '/rooms/manage',
                                              child: Text(building == null
                                                  ? 'Manage buildings'
                                                  : 'Manage rooms')),
                                        ],
                                      ),
                                    ]),
                                    const SizedBox(height: 16),
                                    if (state.isLoading)
                                      const LinearProgressIndicator(
                                          minHeight: 2),
                                    if (state.error != null)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 16),
                                          child: Text(
                                              'Could not refresh: ${state.error}',
                                              style: const TextStyle(
                                                  color: _cost))),
                                    _summary(
                                        totals,
                                        '${scopedRooms.where((r) => !r.isSubroom).length} rooms  |  '
                                        '${scopedRooms.where((r) => r.isSubroom).length} subrooms  |  $vacant vacant / ${beds.length} beds'),
                                    const SizedBox(height: 12),
                                    const Text(
                                        'Income: recorded payments for the rent month. Expenses: dated in the selected month, including refunds. Net = income - expenses.',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: _muted,
                                            height: 1.7)),
                                    const SizedBox(height: 32),
                                    if (room == null ||
                                        subrooms.isNotEmpty) ...[
                                      Text(
                                          building == null
                                              ? 'Explore your buildings'
                                              : room == null
                                                  ? 'Rooms in this building'
                                                  : 'Room breakdown',
                                          style: _heading(25)),
                                      const SizedBox(height: 8),
                                      Text(
                                          room != null
                                              ? 'The room itself and each subroom are shown separately below.'
                                              : 'Open a space to see its breakdown and transactions.',
                                          style: const TextStyle(
                                              color: _muted, height: 1.6)),
                                      const SizedBox(height: 16),
                                      if (scopedRooms.length > 6 ||
                                          building == null)
                                        TextField(
                                            onChanged: (value) => setState(() =>
                                                _search =
                                                    value.trim().toLowerCase()),
                                            decoration: const InputDecoration(
                                                prefixIcon:
                                                    Icon(CupertinoIcons.search),
                                                hintText:
                                                    'Find a building, room or subroom')),
                                      const SizedBox(height: 16),
                                      ..._spaceCards(state, report, buildingId,
                                          room, subrooms),
                                      const SizedBox(height: 24),
                                    ],
                                    TextButton.icon(
                                      onPressed: () => setState(
                                          () => _showActivity = !_showActivity),
                                      icon: Icon(
                                          _showActivity
                                              ? CupertinoIcons.chevron_up
                                              : CupertinoIcons.chevron_down,
                                          size: 16),
                                      label: Text(_showActivity
                                          ? 'Hide transactions'
                                          : 'View transactions (${transactions.length})'),
                                    ),
                                    if (_showActivity) ...[
                                      if (transactions.isEmpty)
                                        _empty('No transactions in this period',
                                            'Choose another month or record a payment or expense.'),
                                      if (transactions.isNotEmpty)
                                        Container(
                                            decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Column(
                                                children: transactions
                                                    .take(_showAll
                                                        ? transactions.length
                                                        : 15)
                                                    .map((entry) {
                                              final source = state.rooms
                                                  .where((r) =>
                                                      r.roomId == entry.roomId)
                                                  .firstOrNull;
                                              return ListTile(
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 6),
                                                leading: CircleAvatar(
                                                    backgroundColor: (entry
                                                                .isIncome
                                                            ? _green
                                                            : _cost)
                                                        .withValues(alpha: .1),
                                                    child: Icon(
                                                        entry.isIncome
                                                            ? CupertinoIcons
                                                                .arrow_down_left
                                                            : CupertinoIcons
                                                                .arrow_up_right,
                                                        color: entry.isIncome
                                                            ? _green
                                                            : _cost,
                                                        size: 18)),
                                                title: Text(entry.title,
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                                subtitle: Text(
                                                    '${source?.displayName(state.rooms) ?? 'Unknown room'} | ${DateFormat('d MMM yyyy').format(entry.date)}',
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: _muted)),
                                                trailing: Text(
                                                    '${entry.isIncome ? '+' : '-'}${_money(entry.amount)}',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: entry.isIncome
                                                            ? _green
                                                            : _cost)),
                                              );
                                            }).toList())),
                                      if (transactions.length > 15)
                                        TextButton(
                                            onPressed: () => setState(
                                                () => _showAll = !_showAll),
                                            child: Text(_showAll
                                                ? 'Show less'
                                                : 'Show all ${transactions.length} transactions')),
                                    ],
                                    const SizedBox(height: 48),
                                  ]))),
                    ]),
              );
            }))),
      );

  Widget _periodControl(ManagementLoaded state) {
    final current = DateTime.now();
    final months = <String>{
      DateFormat('yyyy-MM').format(current),
      if (_month != null) _month!,
      for (var i = 0; i < 12; i++)
        DateFormat('yyyy-MM').format(DateTime(current.year, current.month - i)),
      ...state.payments
          .map((p) => p.paymentMonth)
          .where((m) => RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(m)),
      ...state.expenses.map((e) => DateFormat('yyyy-MM').format(e.date)),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(30)),
        child: DropdownButton<String>(
            isExpanded: true,
            value: _month ?? 'all',
            underline: const SizedBox.shrink(),
            icon: const Icon(CupertinoIcons.chevron_down, size: 18),
            items: [
              const DropdownMenuItem(value: 'all', child: Text('All time')),
              ...months.map((m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                      DateFormat('MMMM yyyy').format(DateTime.parse('$m-01')))))
            ],
            onChanged: (value) => setState(() {
                  _month = value == 'all' ? null : value;
                  _showAll = false;
                })));
  }

  Widget _summary(PropertyTotals totals, String caption) => Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.cardDecoration,
      child: Column(children: [
        _totalRow('Income', totals.income, AppTheme.secondaryColor),
        const SizedBox(height: 12),
        _totalRow('Expenses', totals.expenses, AppTheme.primaryColor),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
        _totalRow('Balance', totals.net, _ink, bold: true),
        const SizedBox(height: 16),
        Text(caption,
            style: const TextStyle(color: _muted, fontSize: 11, height: 1.5)),
      ]));

  Widget _totalRow(String label, double value, Color color,
          {bool bold = false}) =>
      Row(children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
        Flexible(
            child: Text(_money(value),
                style: TextStyle(
                    color: color,
                    fontSize: bold ? 20 : 16,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500))),
      ]);
  List<Widget> _spaceCards(ManagementLoaded state, PropertyFinancials report,
      String? buildingId, RoomModel? room, List<RoomModel> subrooms) {
    final result = <Widget>[];
    if (buildingId == null) {
      for (final building in state.buildings) {
        final children = state.rooms
            .where((r) => r.buildingId == building.buildingId)
            .toList();
        if (!building.buildingName.toLowerCase().contains(_search) &&
            !children
                .any((r) => r.roomNumber.toLowerCase().contains(_search))) {
          continue;
        }
        result.add(_card(
            building.buildingName,
            '${children.where((r) => !r.isSubroom).length} rooms | ${children.where((r) => r.isSubroom).length} subrooms',
            report.totals(report.roomIds(buildingId: building.buildingId)),
            CupertinoIcons.building_2_fill,
            () => _open(building: building.buildingId)));
      }
    } else if (room == null) {
      final children = state.rooms
          .where((r) => r.buildingId == buildingId && !r.isSubroom)
          .toList()
        ..sort((a, b) => a.roomNumber.compareTo(b.roomNumber));
      for (final child in children) {
        final subs =
            state.rooms.where((r) => r.parentRoomId == child.roomId).toList();
        if (!child.roomNumber.toLowerCase().contains(_search) &&
            !subs.any((r) => r.roomNumber.toLowerCase().contains(_search))) {
          continue;
        }
        result.add(_card(
            'Room ${child.roomNumber}',
            '${subs.length} subrooms | Totals include subrooms',
            report.totals(report.roomIds(roomId: child.roomId)),
            CupertinoIcons.rectangle_split_3x1,
            () => _open(building: buildingId, room: child.roomId)));
        for (final sub in subs) {
          if (_search.isNotEmpty &&
              !child.roomNumber.toLowerCase().contains(_search) &&
              !sub.roomNumber.toLowerCase().contains(_search)) {
            continue;
          }
          result.add(Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                  border: Border(
                      left: BorderSide(color: Color(0xffcbd5ce), width: 2))),
              child: _card(
                  'Subroom ${sub.roomNumber}',
                  'Branch of Room ${child.roomNumber} | This subroom only',
                  report.totals(report.roomIds(roomId: sub.roomId)),
                  CupertinoIcons.arrow_turn_down_right,
                  () => _open(building: buildingId, room: sub.roomId)),
            ),
          ));
        }
      }
    } else {
      if ('room ${room.roomNumber}'.toLowerCase().contains(_search)) {
        result.add(_card(
            'Room ${room.roomNumber} | Own activity',
            'This room only, excluding subrooms',
            report.totals(
                report.roomIds(roomId: room.roomId, includeSubrooms: false)),
            CupertinoIcons.rectangle_split_3x1,
            () => context.push('/rooms/${room.roomId}/expenses')));
      }
      for (final sub in subrooms) {
        if (!sub.roomNumber.toLowerCase().contains(_search)) continue;
        result.add(_card(
            'Subroom ${sub.roomNumber}',
            'Only this subroom',
            report.totals(report.roomIds(roomId: sub.roomId)),
            CupertinoIcons.arrow_turn_down_right,
            () => _open(building: buildingId, room: sub.roomId)));
      }
    }
    if (result.isEmpty) {
      result.add(_empty(
          _search.isNotEmpty ? 'No matching spaces' : 'A little room to grow',
          _search.isNotEmpty
              ? 'Try another building or room number.'
              : 'Add your buildings and rooms using the manage buttons above.'));
    }
    return result;
  }

  Widget _card(String title, String subtitle, PropertyTotals totals,
          IconData icon, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.withValues(alpha: .1)),
              ),
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: .08),
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                      color: _paper,
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icon, size: 22, color: _ink)),
                              const SizedBox(width: 14),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(title,
                                        style: const TextStyle(
                                            color: _ink,
                                            fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 5),
                                    Text(subtitle,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: _muted,
                                            height: 1.5)),
                                  ])),
                              const Icon(CupertinoIcons.arrow_right,
                                  size: 18, color: _muted)
                            ]),
                            const SizedBox(height: 20),
                            Wrap(spacing: 28, runSpacing: 12, children: [
                              _smallMetric('Income', totals.income, _green),
                              _smallMetric('Expenses', totals.expenses, _cost),
                              _smallMetric('Net', totals.net, _ink),
                            ]),
                          ])))));

  Widget _smallMetric(String label, double amount, Color color) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 5),
        Text(_money(amount),
            style: TextStyle(
                fontSize: 14, color: color, fontWeight: FontWeight.w500)),
      ]);

  Widget _empty(String title, String detail) => Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        const Icon(CupertinoIcons.sparkles, color: _muted),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(detail,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, height: 1.7)),
      ]));
}
