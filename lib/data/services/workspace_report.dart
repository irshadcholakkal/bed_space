import 'package:intl/intl.dart';

import '../models/room_media_model.dart';

class ReportTable {
  final String title;
  final List<String> headings;
  final List<List<Object>> rows;

  const ReportTable(this.title, this.headings, this.rows);
}

List<ReportTable> workspaceReport(Map<String, dynamic> tabs) {
  List<_Record> records(String title) => (tabs[title] as List)
      .skip(1)
      .map((row) => _Record(row as List))
      .where((row) => row.text(0).isNotEmpty)
      .toList();

  final buildings = records('Buildings');
  final rooms = records('Rooms');
  final beds = records('Beds');
  final tenants = records('Tenants');
  final buildingsById = {for (final row in buildings) row.text(0): row};
  final roomsById = {for (final row in rooms) row.text(0): row};
  final tenantsById = {for (final row in tenants) row.text(0): row};
  final bookings = records('Bookings');

  String building(String id) =>
      buildingsById[id]?.text(1) ?? (id.isEmpty ? '' : 'Unknown property');
  String room(String id) {
    final record = roomsById[id];
    if (record == null) return id.isEmpty ? '' : 'Unknown room';
    final parent = roomsById[record.text(10)];
    return parent == null
        ? record.text(2)
        : '${parent.text(2)} / ${record.text(2)}';
  }

  String tenant(String id) =>
      tenantsById[id]?.text(1) ?? (id.isEmpty ? '' : 'Unknown tenant');
  String roomBuilding(String id) => building(roomsById[id]?.text(1) ?? '');

  final bedNames = <String, String>{};
  final bedNumbers = <(String, String), int>{};
  for (final bed in beds) {
    final key = (bed.text(1), bed.label(2));
    final number = (bedNumbers[key] ?? 0) + 1;
    bedNumbers[key] = number;
    bedNames[bed.text(0)] = '${key.$2} $number';
  }
  String bed(String id) => bedNames[id] ?? (id.isEmpty ? '' : 'Unknown bed');

  return [
    ReportTable('Properties', [
      'Property',
      'Address',
      'Total rooms'
    ], [
      for (final row in buildings) [row.text(1), row.text(2), row.number(3)],
    ]),
    ReportTable('Rooms', [
      'Property',
      'Room',
      'Type',
      'Availability',
      'Capacity',
      'Lower beds',
      'Upper beds',
      'Lower bed rent (AED)',
      'Upper bed rent (AED)',
      'Monthly rent (AED)',
      'Monthly utilities (AED)',
      'Media',
    ], [
      for (final row in rooms)
        [
          building(row.text(1)),
          room(row.text(0)),
          row.text(13).isEmpty ? 'Bed space' : row.label(13),
          row.yes(11, fallback: true) ? 'Available' : 'Unavailable',
          row.number(3),
          row.number(4),
          row.number(5),
          row.number(6),
          row.number(7),
          row.number(9),
          row.number(8),
          row.media(12),
        ],
    ]),
    ReportTable('Beds', [
      'Property',
      'Room',
      'Bed',
      'Status'
    ], [
      for (final row in beds)
        [
          roomBuilding(row.text(1)),
          room(row.text(1)),
          bed(row.text(0)),
          row.label(3)
        ],
    ]),
    ReportTable('Tenants', [
      'Tenant',
      'Phone',
      'Property',
      'Room',
      'Bed',
      'Monthly rent (AED)',
      'Advance (AED)',
      'Joined',
      'Rent due day',
      'Status',
      'Checked out',
    ], [
      for (final row in tenants)
        [
          row.text(1),
          row.text(2),
          building(row.text(3)),
          room(row.text(4)),
          bed(row.text(5)),
          row.number(6),
          row.number(7),
          row.date(8),
          row.number(9),
          row.yes(10, fallback: true) ? 'Active' : 'Checked out',
          row.date(11),
        ],
    ]),
    ReportTable('Bookings', [
      'Tenant',
      'Phone',
      'Property',
      'Room',
      'Bed',
      'Move-in date',
      'Rent (AED)',
      'Advance (AED)',
      'Rent paid (AED)',
      'Payment date',
      'Rent due day',
      'Status',
      'Refund (AED)',
    ], [
      for (final row in bookings)
        [
          row.text(1),
          row.text(2),
          building(row.text(3)),
          room(row.text(4)),
          bed(row.text(5)),
          row.date(6),
          row.number(7),
          row.number(8),
          row.number(9),
          row.date(10),
          row.number(11),
          row.label(12),
          row.number(13),
        ],
    ]),
    ReportTable('Payments', [
      'Tenant',
      'Property',
      'Room',
      'Amount (AED)',
      'Rent month',
      'Paid on',
    ], [
      for (final row in records('Payments'))
        [
          tenant(row.text(1)),
          building(tenantsById[row.text(1)]?.text(3) ?? ''),
          room(tenantsById[row.text(1)]?.text(4) ?? ''),
          row.number(2),
          row.date(3, month: true),
          row.date(4),
        ],
    ]),
    ReportTable('Expenses', [
      'Property',
      'Room',
      'Expense type',
      'Amount (AED)',
      'Date',
      'Description',
      'Tenant',
    ], [
      for (final row in records('Expenses'))
        [
          roomBuilding(row.text(1)),
          room(row.text(1)),
          row.label(2),
          row.number(3),
          row.date(4),
          row.text(5),
          tenant(row.text(6)),
        ],
    ]),
  ];
}

class _Record {
  final List<dynamic> cells;
  const _Record(this.cells);

  String text(int index) =>
      index < cells.length ? cells[index]?.toString() ?? '' : '';

  Object number(int index) => num.tryParse(text(index)) ?? text(index);

  bool yes(int index, {required bool fallback}) =>
      switch (text(index).toLowerCase()) {
        'true' || 'yes' || '1' => true,
        'false' || 'no' || '0' => false,
        _ => fallback,
      };

  String date(int index, {bool month = false}) {
    final raw = text(index);
    final value = DateTime.tryParse(month ? '$raw-01' : raw);
    if (value == null) return raw;
    return DateFormat(month ? 'MMM yyyy' : 'dd MMM yyyy').format(value);
  }

  String label(int index) {
    final value = text(index);
    if (value.isEmpty) return '';
    final spaced = value.replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'), (match) => '${match[1]} ${match[2]}');
    final normalized = spaced.replaceAll('_', ' ').toLowerCase();
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  String media(int index) {
    try {
      return RoomMediaModel.decode(text(index))
          .map((item) =>
              '${item.name.isEmpty ? 'Media' : item.name} (${item.viewUrl})')
          .join('\n');
    } catch (_) {
      return '';
    }
  }
}
