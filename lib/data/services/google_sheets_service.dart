/// Google Sheets API Service
library;

///
/// IMPORTANT DISCLAIMER:
/// This service directly calls Google Sheets API from the client.
/// One Google user â†’ one Google Sheet per device (enforced locally via SharedPreferences).
/// On app reinstall, a new sheet may be created.
/// No global uniqueness enforcement is possible without a backend.
///
/// This app:
/// - Is client-only
/// - Does not guarantee uniqueness across devices
/// - Is not suitable for high-security financial data
/// - Is designed for internal / prototype usage

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/building_model.dart';
import '../models/room_model.dart';
import '../models/bed_model.dart';
import '../models/tenant_model.dart';
import '../models/payment_model.dart';
import '../models/expense_model.dart';
import '../models/booking_model.dart';

class GoogleSheetsService {
  /// Locate or create a private customer-owned document folder.
  static Future<String> ensureDocumentFolder(String token, String customerId,
      {String? businessName}) async {
    final legacyName = 'Bedspace_$customerId';
    final name = businessName?.trim().isNotEmpty == true
        ? '${businessName!.trim()} - Documents'
        : legacyName;
    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q':
          "(name = '${_escapeDriveQuery(name)}' or name = '${_escapeDriveQuery(legacyName)}') and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      'fields': 'files(id)',
    });
    final found = await http.get(uri, headers: headers);
    if (found.statusCode != 200) {
      throw Exception(
          'Could not access your Google Drive folder. Reconnect Google and retry.');
    }
    final files = jsonDecode(found.body)['files'] as List;
    if (files.isNotEmpty) return files.first['id'] as String;
    final created = await http.post(
        Uri.https('www.googleapis.com', '/drive/v3/files'),
        headers: headers,
        body: jsonEncode(
            {'name': name, 'mimeType': 'application/vnd.google-apps.folder'}));
    if (created.statusCode != 200 && created.statusCode != 201) {
      throw Exception('Could not create your private Drive folder.');
    }
    return jsonDecode(created.body)['id'] as String;
  }

  final String accessToken;
  final String sheetId;
  Future<void>? _bookingsReady;
  static const _bookingColumns = [
    'booking_id',
    'tenant_name',
    'phone',
    'building_id',
    'room_id',
    'bed_id',
    'move_in_date',
    'rent_amount',
    'advance_amount',
    'rent_paid',
    'payment_date',
    'rent_due_day',
    'status',
    'refund_amount',
  ];

  GoogleSheetsService({
    required this.accessToken,
    required this.sheetId,
  });

  static const String _baseUrl =
      'https://sheets.googleapis.com/v4/spreadsheets';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  /// Search for a sheet with a specific title in the user's Google Drive
  static String _escapeDriveQuery(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  static Future<String?> findSheetByTitle(
      String accessToken, String title) async {
    try {
      final url = Uri.https('www.googleapis.com', '/drive/v3/files', {
        'q':
            "name = '${_escapeDriveQuery(title)}' and mimeType = 'application/vnd.google-apps.spreadsheet' and trashed = false",
        'fields': 'files(id)',
      });

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> files = data['files'] ?? [];
        if (files.isNotEmpty) {
          return files.first['id'] as String;
        }
        return null;
      } else {
        throw Exception('Failed to search for sheet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error searching for sheet: $e');
    }
  }

  /// Create a new Google Sheet with required tabs
  static Future<String> createSheet(
      String accessToken, String sheetName) async {
    try {
      // Create spreadsheet structure
      final spreadsheet = {
        'properties': {'title': sheetName},
        'sheets': [
          {
            'properties': {
              'title': 'Bookings',
              'gridProperties': {'rowCount': 1000, 'columnCount': 20}
            }
          },
          {
            'properties': {
              'title': 'Buildings',
              'gridProperties': {'rowCount': 1000, 'columnCount': 10}
            }
          },
          {
            'properties': {
              'title': 'Rooms',
              'gridProperties': {'rowCount': 1000, 'columnCount': 10}
            }
          },
          {
            'properties': {
              'title': 'Beds',
              'gridProperties': {'rowCount': 1000, 'columnCount': 10}
            }
          },
          {
            'properties': {
              'title': 'Tenants',
              'gridProperties': {'rowCount': 1000, 'columnCount': 10}
            }
          },
          {
            'properties': {
              'title': 'Payments',
              'gridProperties': {'rowCount': 1000, 'columnCount': 10}
            }
          },
          {
            'properties': {
              'title': 'Expenses',
              'gridProperties': {'rowCount': 1000, 'columnCount': 10}
            }
          },
        ],
      };

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(spreadsheet),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final sheetId = data['spreadsheetId'];

        // Initialize headers for each sheet
        final service = GoogleSheetsService(
          accessToken: accessToken,
          sheetId: sheetId,
        );

        await service._initializeSheetHeaders();

        return sheetId;
      } else {
        throw Exception('Failed to create sheet: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error creating sheet: $e');
    }
  }

  /// Initialize headers for all sheets
  Future<void> _initializeSheetHeaders() async {
    final headers = {
      'Bookings': _bookingColumns,
      'Buildings': ['building_id', 'building_name', 'address', 'total_rooms'],
      'Rooms': [
        'room_id',
        'building_id',
        'room_number',
        'total_capacity',
        'lower_beds_count',
        'upper_beds_count',
        'lower_bed_rent',
        'upper_bed_rent',
        'utility_cost_monthly',
        'monthly_rent',
        'parent_room_id',
        'available'
      ],
      'Beds': ['bed_id', 'room_id', 'bed_type', 'status'],
      'Tenants': [
        'tenant_id',
        'tenant_name',
        'phone',
        'building_id',
        'room_id',
        'bed_id',
        'rent_amount',
        'advance_amount',
        'joining_date',
        'rent_due_day',
        'active',
        'checkout_date'
      ],
      'Payments': [
        'payment_id',
        'tenant_id',
        'amount',
        'payment_month',
        'paid_date'
      ],
      'Expenses': [
        'id',
        'room_id',
        'expense_type',
        'amount',
        'date',
        'description',
        'tenant_id'
      ],
    };

    for (final entry in headers.entries) {
      await _writeRange(entry.key,
          'A1:${_getColumnLetter(entry.value.length)}1', [entry.value]);
    }
  }

  String _getColumnLetter(int column) {
    String result = '';
    while (column > 0) {
      column--;
      result = String.fromCharCode(65 + (column % 26)) + result;
      column ~/= 26;
    }
    return result;
  }

  /// Write data to a range in the sheet
  Future<void> _writeRange(
      String sheetName, String range, List<List<dynamic>> values) async {
    final url =
        '$_baseUrl/$sheetId/values/$sheetName!$range?valueInputOption=RAW';

    final response = await http
        .put(
          Uri.parse(url),
          headers: _headers,
          body: jsonEncode({'values': values}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to write to sheet: ${response.body}');
    }
  }

  /// Read data from a range in the sheet
  Future<List<List<String>>> _readRange(String sheetName, String range) async {
    final url = '$_baseUrl/$sheetId/values/$sheetName!$range';

    final response = await http
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List<dynamic> values = data['values'] ?? [];
      return values
          .map((row) => (row as List<dynamic>)
              .map((cell) => cell?.toString() ?? '')
              .toList())
          .toList()
          .cast<List<String>>();
    } else {
      throw Exception('Failed to read from sheet: ${response.body}');
    }
  }

  // Buildings CRUD
  Future<void> _ensureBookingsSheet() {
    return _bookingsReady ??=
        _prepareBookingsSheet().catchError((Object error) {
      _bookingsReady = null;
      throw error;
    });
  }

  Future<bool> _hasBookingsSheet() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/$sheetId?fields=sheets.properties.title'),
            headers: _headers)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw StateError('Could not access booking records in Sheets.');
    }
    final sheets = jsonDecode(response.body)['sheets'] as List? ?? [];
    return sheets.any((sheet) => sheet['properties']['title'] == 'Bookings');
  }

  Future<void> _prepareBookingsSheet() async {
    if (!await _hasBookingsSheet()) {
      final response = await http
          .post(Uri.parse('$_baseUrl/$sheetId:batchUpdate'),
              headers: _headers,
              body: jsonEncode({
                'requests': [
                  {
                    'addSheet': {
                      'properties': {'title': 'Bookings'}
                    }
                  }
                ]
              }))
          .timeout(const Duration(seconds: 30));
      // Another device may have created the tab while this request was in flight.
      if (response.statusCode != 200 && !await _hasBookingsSheet()) {
        throw StateError('Could not create the Bookings tab in Sheets.');
      }
    }
    await _writeRange('Bookings', 'A1:N1', [_bookingColumns]);
  }

  Future<List<BookingModel>> getBookings() async {
    await _ensureBookingsSheet();
    final rows = await _readRange('Bookings', 'A2:N');
    return rows
        .where((row) => row.isNotEmpty && row.first.isNotEmpty)
        .map((row) {
      return BookingModel.fromJson({
        for (var i = 0; i < _bookingColumns.length; i++)
          _bookingColumns[i]: i < row.length ? row[i] : '',
      });
    }).toList();
  }

  Future<void> saveBooking(BookingModel booking) async {
    await _ensureBookingsSheet();
    final rows = await _readRange('Bookings', 'A:N');
    final index = rows
        .indexWhere((row) => row.isNotEmpty && row.first == booking.bookingId);
    final row = index < 0 ? rows.length + 1 : index + 1;
    final json = booking.toJson();
    await _writeRange('Bookings', 'A$row:N$row', [
      _bookingColumns.map((column) => json[column]).toList(),
    ]);
  }

  Future<List<BuildingModel>> getBuildings() async {
    final rows = await _readRange('Buildings', 'A2:D');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return BuildingModel.fromJson({
        'building_id': row[0],
        'building_name': row.length > 1 ? row[1] : '',
        'address': row.length > 2 ? row[2] : '',
        'total_rooms': row.length > 3 ? row[3] : '0',
      });
    }).toList();
  }

  Future<void> addBuilding(BuildingModel building) async {
    final rows = await _readRange('Buildings', 'A:D');
    final newRow = [
      (building.buildingId != null && building.buildingId!.isNotEmpty)
          ? building.buildingId!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      building.buildingName,
      building.address,
      building.totalRooms.toString(),
    ];
    final existing =
        rows.indexWhere((row) => row.isNotEmpty && row[0] == newRow[0]);
    final rowNumber = existing < 0 ? rows.length + 1 : existing + 1;
    await _writeRange('Buildings', 'A$rowNumber:D$rowNumber', [newRow]);
  }

  // Rooms CRUD
  Future<List<RoomModel>> getRooms() async {
    final rows = await _readRange('Rooms', 'A2:L');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return RoomModel.fromJson({
        'room_id': row[0],
        'building_id': row.length > 1 ? row[1] : '',
        'room_number': row.length > 2 ? row[2] : '',
        'total_capacity': row.length > 3 ? row[3] : '0',
        'lower_beds_count': row.length > 4 ? row[4] : '0',
        'upper_beds_count': row.length > 5 ? row[5] : '0',
        'lower_bed_rent': row.length > 6 ? row[6] : '0',
        'upper_bed_rent': row.length > 7 ? row[7] : '0',
        'utility_cost_monthly': row.length > 8 ? row[8] : '0',
        'monthly_rent': row.length > 9 ? row[9] : '0',
        'parent_room_id': row.length > 10 ? row[10] : null,
        'available': row.length > 11 ? row[11] : 'TRUE',
      });
    }).toList();
  }

  Future<void> addRoom(RoomModel room) async {
    await _writeRange('Rooms', 'K1', [
      ['parent_room_id', 'available']
    ]);
    final rows = await _readRange('Rooms', 'A:L');
    final newRow = [
      (room.roomId != null && room.roomId!.isNotEmpty)
          ? room.roomId!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      room.buildingId,
      room.roomNumber,
      room.totalCapacity.toString(),
      room.lowerBedsCount.toString(),
      room.upperBedsCount.toString(),
      room.lowerBedRent.toString(),
      room.upperBedRent.toString(),
      room.utilityCostMonthly.toString(),
      room.monthlyRent.toString(),
      room.parentRoomId ?? '',
      room.available ? 'TRUE' : 'FALSE',
    ];
    final existing =
        rows.indexWhere((row) => row.isNotEmpty && row[0] == newRow[0]);
    final rowNumber = existing < 0 ? rows.length + 1 : existing + 1;
    await _writeRange('Rooms', 'A$rowNumber:L$rowNumber', [newRow]);
  }

  // Beds CRUD
  Future<List<BedModel>> getBeds() async {
    final rows = await _readRange('Beds', 'A2:D');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return BedModel.fromJson({
        'bed_id': row[0],
        'room_id': row.length > 1 ? row[1] : '',
        'bed_type': row.length > 2 ? row[2] : 'LOWER',
        'status': row.length > 3 ? row[3] : 'VACANT',
      });
    }).toList();
  }

  Future<void> addBed(BedModel bed) async {
    final rows = await _readRange('Beds', 'A:D');
    final newRow = [
      (bed.bedId != null && bed.bedId!.isNotEmpty)
          ? bed.bedId!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      bed.roomId,
      bed.bedType == BedType.lower ? 'LOWER' : 'UPPER',
      bed.status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED',
    ];
    final existing =
        rows.indexWhere((row) => row.isNotEmpty && row[0] == newRow[0]);
    final rowNumber = existing < 0 ? rows.length + 1 : existing + 1;
    await _writeRange('Beds', 'A$rowNumber:D$rowNumber', [newRow]);
  }

  Future<void> updateBedStatus(String bedId, BedStatus status) async {
    final rows = await _readRange('Beds', 'A2:D');
    final index = rows.indexWhere((row) => row.isNotEmpty && row[0] == bedId);
    if (index < 0) throw StateError('Bed $bedId is missing from Sheets.');
    await _writeRange('Beds', 'D${index + 2}', [
      [status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED']
    ]);
  }

  Future<void> deleteBed(String bedId) async {
    final rows = await _readRange('Beds', 'A2:D');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == bedId) {
        await _writeRange('Beds', 'A${i + 2}:D${i + 2}', [
          ['', '', '', '']
        ]);
        break;
      }
    }
  }

  // Tenants CRUD
  Future<List<TenantModel>> getTenants() async {
    final rows = await _readRange('Tenants', 'A2:L');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return TenantModel.fromJson({
        'tenant_id': row[0],
        'tenant_name': row.length > 1 ? row[1] : '',
        'phone': row.length > 2 ? row[2] : '',
        'building_id': row.length > 3 ? row[3] : '',
        'room_id': row.length > 4 ? row[4] : '',
        'bed_id': row.length > 5 ? row[5] : '',
        'rent_amount': row.length > 6 ? row[6] : '0',
        'advance_amount': row.length > 7 ? row[7] : '0',
        'joining_date': row.length > 8
            ? row[8]
            : DateTime.now().toIso8601String().split('T')[0],
        'rent_due_day': row.length > 9 ? row[9] : '1',
        'active': row.length > 10 ? row[10] : 'TRUE',
        'checkout_date': row.length > 11 ? row[11] : '',
      });
    }).toList();
  }

  Future<void> addTenant(TenantModel tenant) async {
    final rows = await _readRange('Tenants', 'A:L');
    final newRow = [
      (tenant.tenantId != null && tenant.tenantId!.isNotEmpty)
          ? tenant.tenantId!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      tenant.tenantName,
      tenant.phone,
      tenant.buildingId,
      tenant.roomId,
      tenant.bedId,
      tenant.rentAmount.toString(),
      tenant.advanceAmount.toString(),
      tenant.joiningDate.toIso8601String().split('T')[0],
      tenant.rentDueDay.toString(),
      tenant.active ? 'TRUE' : 'FALSE',
      tenant.checkoutDate?.toIso8601String().split('T')[0] ?? '',
    ];
    final existing =
        rows.indexWhere((row) => row.isNotEmpty && row[0] == newRow[0]);
    final rowNumber = existing < 0 ? rows.length + 1 : existing + 1;
    await _writeRange('Tenants', 'A$rowNumber:L$rowNumber', [newRow]);
  }

  // Payments CRUD
  Future<List<PaymentModel>> getPayments() async {
    final rows = await _readRange('Payments', 'A2:E');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return PaymentModel.fromJson({
        'payment_id': row[0],
        'tenant_id': row.length > 1 ? row[1] : '',
        'amount': row.length > 2 ? row[2] : '0',
        'payment_month': row.length > 3 ? row[3] : '',
        'paid_date': row.length > 4
            ? row[4]
            : DateTime.now().toIso8601String().split('T')[0],
      });
    }).toList();
  }

  Future<void> addPayment(PaymentModel payment) async {
    final rows = await _readRange('Payments', 'A:E');
    final newRow = [
      (payment.paymentId != null && payment.paymentId!.isNotEmpty)
          ? payment.paymentId!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      payment.tenantId,
      payment.amount.toString(),
      payment.paymentMonth,
      payment.paidDate.toIso8601String().split('T')[0],
    ];
    final existing =
        rows.indexWhere((row) => row.isNotEmpty && row[0] == newRow[0]);
    final rowNumber = existing < 0 ? rows.length + 1 : existing + 1;
    await _writeRange('Payments', 'A$rowNumber:E$rowNumber', [newRow]);
  }

  // --- Expenses CRUD ---
  Future<List<ExpenseModel>> getExpenses() async {
    final rows = await _readRange('Expenses', 'A2:G');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return ExpenseModel.fromJson({
        'id': row[0],
        'room_id': row.length > 1 ? row[1] : '',
        'expense_type': row.length > 2 ? row[2] : 'OTHER',
        'amount': row.length > 3 ? double.tryParse(row[3]) ?? 0.0 : 0.0,
        'date': row.length > 4 ? row[4] : DateTime.now().toIso8601String(),
        'description': row.length > 5 ? row[5] : '',
        'tenant_id': row.length > 6 ? row[6] : '',
      });
    }).toList();
  }

  Future<void> addExpense(ExpenseModel expense) async {
    final rows = await _readRange('Expenses', 'A:G');
    final newRow = [
      (expense.id != null && expense.id!.isNotEmpty)
          ? expense.id!
          : DateTime.now().millisecondsSinceEpoch.toString(),
      expense.roomId,
      expense.expenseType.toString().split('.').last.toUpperCase(),
      expense.amount.toString(),
      expense.date.toIso8601String(),
      expense.description ?? '',
      expense.tenantId ?? '',
    ];
    final existing =
        rows.indexWhere((row) => row.isNotEmpty && row[0] == newRow[0]);
    final rowNumber = existing < 0 ? rows.length + 1 : existing + 1;
    await _writeRange('Expenses', 'A$rowNumber:G$rowNumber', [newRow]);
  }

  Future<void> deleteExpense(String expenseId) async {
    final rows = await _readRange('Expenses', 'A2:F');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == expenseId) {
        await _writeRange('Expenses', 'A${i + 2}:F${i + 2}', [
          ['', '', '', '', '', '']
        ]);
        break;
      }
    }
  }

  // Update methods
  Future<void> updateBuilding(BuildingModel building) async {
    if (building.buildingId == null) return;
    await addBuilding(building);
  }

  Future<void> updateRoom(RoomModel room) async {
    if (room.roomId == null) return;
    await addRoom(room);
  }

  Future<void> updateTenant(TenantModel tenant) async {
    if (tenant.tenantId == null) return;
    await addTenant(tenant);
  }

  // Delete methods (mark as empty row)
  Future<void> deleteBuilding(String buildingId) async {
    final rows = await _readRange('Buildings', 'A2:D');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == buildingId) {
        await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [
          ['', '', '', '']
        ]);
        break;
      }
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final rows = await _readRange('Rooms', 'A2:L');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == roomId) {
        await _writeRange('Rooms', 'A${i + 2}:L${i + 2}', [
          ['', '', '', '', '', '', '', '', '', '', '', '']
        ]);
        break;
      }
    }
  }

  Future<void> deleteTenant(String tenantId) async {
    final rows = await _readRange('Tenants', 'A2:L');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == tenantId) {
        // Ensure row has enough columns (up to index 10 for 'active')
        while (rows[i].length <= 10) {
          rows[i].add('');
        }
        // Mark tenant as inactive instead of deleting
        rows[i][10] = 'FALSE';
        await _writeRange('Tenants', 'A${i + 2}:L${i + 2}', [rows[i]]);
        break;
      }
    }
  }

  Future<void> deletePayment(String paymentId) async {
    final rows = await _readRange('Payments', 'A2:E');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == paymentId) {
        await _writeRange('Payments', 'A${i + 2}:E${i + 2}', [
          ['', '', '', '', '']
        ]);
        break;
      }
    }
  }

  // Helper: Get tenant by ID
  Future<TenantModel?> getTenantById(String tenantId) async {
    final tenants = await getTenants();
    try {
      return tenants.firstWhere((t) => t.tenantId == tenantId);
    } catch (e) {
      return null;
    }
  }

  // Helper: Get payments by tenant ID
  Future<List<PaymentModel>> getPaymentsByTenantId(String tenantId) async {
    final payments = await getPayments();
    return payments.where((p) => p.tenantId == tenantId).toList();
  }

  // Helper: Calculate rent balance for a tenant
  Future<Map<String, dynamic>> getTenantRentBalance(String tenantId) async {
    final tenant = await getTenantById(tenantId);
    if (tenant == null) {
      return {
        'totalDue': 0.0,
        'totalPaid': 0.0,
        'balance': 0.0,
        'payments': []
      };
    }

    final payments = await getPaymentsByTenantId(tenantId);
    final now = DateTime.now();

    // Calculate months from joining date to current month
    final joiningDate = tenant.joiningDate;
    final startMonth = DateTime(joiningDate.year, joiningDate.month);
    final currentMonth = DateTime(now.year, now.month);

    int monthsCount = 0;
    DateTime month = startMonth;
    while (
        month.isBefore(currentMonth) || month.isAtSameMomentAs(currentMonth)) {
      monthsCount++;
      month = DateTime(month.year, month.month + 1);
    }

    final totalDue = tenant.rentAmount * monthsCount;
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
    final balance = totalDue - totalPaid;

    return {
      'totalDue': totalDue,
      'totalPaid': totalPaid,
      'balance': balance,
      'payments': payments,
      'tenant': tenant,
    };
  }
}
