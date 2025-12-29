/// Google Sheets API Service
///
/// IMPORTANT DISCLAIMER:
/// This service directly calls Google Sheets API from the client.
/// One Google user → one Google Sheet per device (enforced locally via SharedPreferences).
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

class GoogleSheetsService {
  final String accessToken;
  final String sheetId;

  GoogleSheetsService({
    required this.accessToken,
    required this.sheetId,
  });

  static const String _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';
  static const String _driveUrl = 'https://www.googleapis.com/drive/v3/files';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      };

  /// Create a new Google Sheet with required tabs
  static Future<String> createSheet(String accessToken, String sheetName) async {
    try {
      // Create spreadsheet structure
      final spreadsheet = {
        'properties': {'title': sheetName},
        'sheets': [
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
        ],
      };

      final response = await http.post(
        Uri.parse('$_baseUrl'),
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
        'utility_cost_monthly'
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
        'joining_date',
        'rent_due_day',
        'active'
      ],
      'Payments': ['payment_id', 'tenant_id', 'amount', 'payment_month', 'paid_date'],
    };

    for (final entry in headers.entries) {
      await _writeRange(entry.key, 'A1:${_getColumnLetter(entry.value.length)}1', [
        entry.value
      ]);
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
  Future<void> _writeRange(String sheetName, String range, List<List<dynamic>> values) async {
    final url = '$_baseUrl/$sheetId/values/$sheetName!$range?valueInputOption=RAW';

    final response = await http.put(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode({'values': values}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to write to sheet: ${response.body}');
    }
  }

  /// Read data from a range in the sheet
  Future<List<List<String>>> _readRange(String sheetName, String range) async {
    final url = '$_baseUrl/$sheetId/values/$sheetName!$range';

    final response = await http.get(Uri.parse(url), headers: _headers);

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
      building.buildingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      building.buildingName,
      building.address,
      building.totalRooms.toString(),
    ];
    await _writeRange('Buildings', 'A${rows.length + 1}:D${rows.length + 1}', [newRow]);
  }

  // Rooms CRUD
  Future<List<RoomModel>> getRooms() async {
    final rows = await _readRange('Rooms', 'A2:I');
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
      });
    }).toList();
  }

  Future<void> addRoom(RoomModel room) async {
    final rows = await _readRange('Rooms', 'A:I');
    final newRow = [
      room.roomId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      room.buildingId,
      room.roomNumber,
      room.totalCapacity.toString(),
      room.lowerBedsCount.toString(),
      room.upperBedsCount.toString(),
      room.lowerBedRent.toString(),
      room.upperBedRent.toString(),
      room.utilityCostMonthly.toString(),
    ];
    await _writeRange('Rooms', 'A${rows.length + 1}:I${rows.length + 1}', [newRow]);
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
      bed.bedId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      bed.roomId,
      bed.bedType == BedType.lower ? 'LOWER' : 'UPPER',
      bed.status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED',
    ];
    await _writeRange('Beds', 'A${rows.length + 1}:D${rows.length + 1}', [newRow]);
  }

  Future<void> updateBedStatus(String bedId, BedStatus status) async {
    final rows = await _readRange('Beds', 'A2:D');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == bedId) {
        rows[i][3] = status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED';
        await _writeRange('Beds', 'A${i + 2}:D${i + 2}', [rows[i]]);
        break;
      }
    }
  }

  // Tenants CRUD
  Future<List<TenantModel>> getTenants() async {
    final rows = await _readRange('Tenants', 'A2:J');
    return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
      return TenantModel.fromJson({
        'tenant_id': row[0],
        'tenant_name': row.length > 1 ? row[1] : '',
        'phone': row.length > 2 ? row[2] : '',
        'building_id': row.length > 3 ? row[3] : '',
        'room_id': row.length > 4 ? row[4] : '',
        'bed_id': row.length > 5 ? row[5] : '',
        'rent_amount': row.length > 6 ? row[6] : '0',
        'joining_date': row.length > 7 ? row[7] : DateTime.now().toIso8601String().split('T')[0],
        'rent_due_day': row.length > 8 ? row[8] : '1',
        'active': row.length > 9 ? row[9] : 'TRUE',
      });
    }).toList();
  }

  Future<void> addTenant(TenantModel tenant) async {
    final rows = await _readRange('Tenants', 'A:J');
    final newRow = [
      tenant.tenantId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      tenant.tenantName,
      tenant.phone,
      tenant.buildingId,
      tenant.roomId,
      tenant.bedId,
      tenant.rentAmount.toString(),
      tenant.joiningDate.toIso8601String().split('T')[0],
      tenant.rentDueDay.toString(),
      tenant.active ? 'TRUE' : 'FALSE',
    ];
    await _writeRange('Tenants', 'A${rows.length + 1}:J${rows.length + 1}', [newRow]);
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
        'paid_date': row.length > 4 ? row[4] : DateTime.now().toIso8601String().split('T')[0],
      });
    }).toList();
  }

  Future<void> addPayment(PaymentModel payment) async {
    final rows = await _readRange('Payments', 'A:E');
    final newRow = [
      payment.paymentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      payment.tenantId,
      payment.amount.toString(),
      payment.paymentMonth,
      payment.paidDate.toIso8601String().split('T')[0],
    ];
    await _writeRange('Payments', 'A${rows.length + 1}:E${rows.length + 1}', [newRow]);
  }

  // Update methods
  Future<void> updateBuilding(BuildingModel building) async {
    if (building.buildingId == null) return;
    final rows = await _readRange('Buildings', 'A2:D');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == building.buildingId) {
        rows[i] = [
          building.buildingId!,
          building.buildingName,
          building.address,
          building.totalRooms.toString(),
        ];
        await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [rows[i]]);
        break;
      }
    }
  }

  Future<void> updateRoom(RoomModel room) async {
    if (room.roomId == null) return;
    final rows = await _readRange('Rooms', 'A2:I');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == room.roomId) {
        rows[i] = [
          room.roomId!,
          room.buildingId,
          room.roomNumber,
          room.totalCapacity.toString(),
          room.lowerBedsCount.toString(),
          room.upperBedsCount.toString(),
          room.lowerBedRent.toString(),
          room.upperBedRent.toString(),
          room.utilityCostMonthly.toString(),
        ];
        await _writeRange('Rooms', 'A${i + 2}:I${i + 2}', [rows[i]]);
        break;
      }
    }
  }

  Future<void> updateTenant(TenantModel tenant) async {
    if (tenant.tenantId == null) return;
    final rows = await _readRange('Tenants', 'A2:J');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == tenant.tenantId) {
        rows[i] = [
          tenant.tenantId!,
          tenant.tenantName,
          tenant.phone,
          tenant.buildingId,
          tenant.roomId,
          tenant.bedId,
          tenant.rentAmount.toString(),
          tenant.joiningDate.toIso8601String().split('T')[0],
          tenant.rentDueDay.toString(),
          tenant.active ? 'TRUE' : 'FALSE',
        ];
        await _writeRange('Tenants', 'A${i + 2}:J${i + 2}', [rows[i]]);
        break;
      }
    }
  }

  // Delete methods (mark as empty row)
  Future<void> deleteBuilding(String buildingId) async {
    final rows = await _readRange('Buildings', 'A2:D');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == buildingId) {
        await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [['', '', '', '']]);
        break;
      }
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final rows = await _readRange('Rooms', 'A2:I');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == roomId) {
        await _writeRange('Rooms', 'A${i + 2}:I${i + 2}', [['', '', '', '', '', '', '', '', '']]);
        break;
      }
    }
  }

  Future<void> deleteTenant(String tenantId) async {
    final rows = await _readRange('Tenants', 'A2:J');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == tenantId) {
        // Mark tenant as inactive instead of deleting
        rows[i][9] = 'FALSE';
        await _writeRange('Tenants', 'A${i + 2}:J${i + 2}', [rows[i]]);
        break;
      }
    }
  }

  Future<void> deletePayment(String paymentId) async {
    final rows = await _readRange('Payments', 'A2:E');
    for (int i = 0; i < rows.length; i++) {
      if (rows[i][0] == paymentId) {
        await _writeRange('Payments', 'A${i + 2}:E${i + 2}', [['', '', '', '', '']]);
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
      return {'totalDue': 0.0, 'totalPaid': 0.0, 'balance': 0.0, 'payments': []};
    }

    final payments = await getPaymentsByTenantId(tenantId);
    final now = DateTime.now();

    // Calculate months from joining date to current month
    final joiningDate = tenant.joiningDate;
    final startMonth = DateTime(joiningDate.year, joiningDate.month);
    final currentMonth = DateTime(now.year, now.month);

    int monthsCount = 0;
    DateTime month = startMonth;
    while (month.isBefore(currentMonth) || month.isAtSameMomentAs(currentMonth)) {
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



















// /// Google Sheets API Service
// ///
// /// IMPORTANT DISCLAIMER:
// /// This service directly calls Google Sheets API from the client.
// /// One Google user → one Google Sheet per device (enforced locally via SharedPreferences).
// /// On app reinstall, a new sheet may be created.
// /// No global uniqueness enforcement is possible without a backend.
// ///
// /// This app:
// /// - Is client-only
// /// - Does not guarantee uniqueness across devices
// /// - Is not suitable for high-security financial data
// /// - Is designed for internal / prototype usage

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import '../models/building_model.dart';
// import '../models/room_model.dart';
// import '../models/bed_model.dart';
// import '../models/tenant_model.dart';
// import '../models/payment_model.dart';
// import '../repositories/sheet_repository.dart';
// import 'google_auth_service.dart';

// class GoogleSheetsService {
//   String? _accessToken;
//   String? _sheetId;
//   final SheetRepository _sheetRepository = SheetRepository();
//   final GoogleAuthService _authService = GoogleAuthService();

//   GoogleSheetsService();

//   static const String _baseUrl =
//       'https://sheets.googleapis.com/v4/spreadsheets';
//   static const String _driveUrl = 'https://www.googleapis.com/drive/v3/files';

//   /// Initialize service by loading credentials from local storage
//   Future<void> initialize() async {
//     _accessToken = await _authService.signInSilently();
//     // await _authService.getAccessToken();
//     _sheetId = await _sheetRepository.getSheetId();

//     debugPrint(
//         'GoogleSheetsService initialized with Sheet ID: $_sheetId and Access Token: ${_accessToken != null ? "FOUND" : "NOT FOUND"}');

//     if (_accessToken == null || _accessToken!.isEmpty) {
//       throw Exception('Access token not found. Please login again.');
//     }

//     if (_sheetId == null || _sheetId!.isEmpty) {
//       throw Exception('Sheet ID not found. Please set up your sheet.');
//     }
//   }

//   /// Check if service is initialized
//   bool get isInitialized => _accessToken != null && _sheetId != null;

//   /// Get headers for API requests
//   Map<String, String> get _headers {
//     if (_accessToken == null) {
//       throw Exception('Service not initialized. Call initialize() first......');
//     }
//     return {
//       'Authorization': 'Bearer $_accessToken',
//       'Content-Type': 'application/json',
//     };
//   }

//   /// Get current sheet ID
//   String get sheetId {
//     if (_sheetId == null) {
      
//       throw Exception('Service not initialized. Call initialize() first"""""".');
//     }
//     return _sheetId!;
//   }

//   /// Create a new Google Sheet with required tabs
//   static Future<String> createSheet(
//     String accessToken,
//     String sheetName,
//   ) async {
//     try {
//       // Create spreadsheet structure
//       final spreadsheet = {
//         'properties': {'title': sheetName},
//         'sheets': [
//           {
//             'properties': {
//               'title': 'Buildings',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10},
//             },
//           },
//           {
//             'properties': {
//               'title': 'Rooms',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10},
//             },
//           },
//           {
//             'properties': {
//               'title': 'Beds',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10},
//             },
//           },
//           {
//             'properties': {
//               'title': 'Tenants',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10},
//             },
//           },
//           {
//             'properties': {
//               'title': 'Payments',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10},
//             },
//           },
//         ],
//       };

//       final response = await http.post(
//         Uri.parse('$_baseUrl'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode(spreadsheet),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final sheetId = data['spreadsheetId'];

//         // Initialize headers for each sheet
//         final service = GoogleSheetsService();
//         // Temporarily set credentials for initialization
//         service._accessToken = accessToken;
//         service._sheetId = sheetId;

//         await service._initializeSheetHeaders();

//         return sheetId;
//       } else {
//         throw Exception('Failed to create sheet: ${response.body}');
//       }
//     } catch (e) {
//       throw Exception('Error creating sheet: $e');
//     }
//   }

//   /// Initialize headers for all sheets
//   Future<void> _initializeSheetHeaders() async {
//     final headers = {
//       'Buildings': ['building_id', 'building_name', 'address', 'total_rooms'],
//       'Rooms': [
//         'room_id',
//         'building_id',
//         'room_number',
//         'total_capacity',
//         'lower_beds_count',
//         'upper_beds_count',
//         'lower_bed_rent',
//         'upper_bed_rent',
//         'utility_cost_monthly',
//       ],
//       'Beds': ['bed_id', 'room_id', 'bed_type', 'status'],
//       'Tenants': [
//         'tenant_id',
//         'tenant_name',
//         'phone',
//         'building_id',
//         'room_id',
//         'bed_id',
//         'rent_amount',
//         'joining_date',
//         'rent_due_day',
//         'active',
//       ],
//       'Payments': [
//         'payment_id',
//         'tenant_id',
//         'amount',
//         'payment_month',
//         'paid_date',
//       ],
//     };

//     for (final entry in headers.entries) {
//       await _writeRange(
//         entry.key,
//         'A1:${_getColumnLetter(entry.value.length)}1',
//         [entry.value],
//       );
//     }
//   }

//   String _getColumnLetter(int column) {
//     String result = '';
//     while (column > 0) {
//       column--;
//       result = String.fromCharCode(65 + (column % 26)) + result;
//       column ~/= 26;
//     }
//     return result;
//   }

//   /// Write data to a range in the sheet
//   Future<void> _writeRange(
//     String sheetName,
//     String range,
//     List<List<dynamic>> values,
//   ) async {
//     final url =
//         '$_baseUrl/$sheetId/values/$sheetName!$range?valueInputOption=RAW';

//     final response = await http.put(
//       Uri.parse(url),
//       headers: _headers,
//       body: jsonEncode({'values': values}),
//     );

//     if (response.statusCode != 200) {
//       throw Exception('Failed to write to sheet: ${response.body}');
//     }
//   }

//   /// Read data from a range in the sheet
//   Future<List<List<String>>> _readRange(String sheetName, String range) async {
//     final url = '$_baseUrl/$sheetId/values/$sheetName!$range';

//     final response = await http.get(Uri.parse(url), headers: _headers);

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       final List<dynamic> values = data['values'] ?? [];
//       return values
//           .map(
//             (row) => (row as List<dynamic>)
//                 .map((cell) => cell?.toString() ?? '')
//                 .toList(),
//           )
//           .toList()
//           .cast<List<String>>();
//     } else {
//       throw Exception('Failed to read from sheet: ${response.body}');
//     }
//   }

//   // Buildings CRUD
//   Future<List<BuildingModel>> getBuildings() async {
//     final rows = await _readRange('Buildings', 'A2:D');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return BuildingModel.fromJson({
//         'building_id': row[0],
//         'building_name': row.length > 1 ? row[1] : '',
//         'address': row.length > 2 ? row[2] : '',
//         'total_rooms': row.length > 3 ? row[3] : '0',
//       });
//     }).toList();
//   }

//   Future<void> addBuilding(BuildingModel building) async {
//     final rows = await _readRange('Buildings', 'A:D');
//     final newRow = [
//       building.buildingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       building.buildingName,
//       building.address,
//       building.totalRooms.toString(),
//     ];
//     await _writeRange('Buildings', 'A${rows.length + 1}:D${rows.length + 1}', [
//       newRow,
//     ]);
//   }

//   // Rooms CRUD
//   Future<List<RoomModel>> getRooms() async {
//     final rows = await _readRange('Rooms', 'A2:I');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return RoomModel.fromJson({
//         'room_id': row[0],
//         'building_id': row.length > 1 ? row[1] : '',
//         'room_number': row.length > 2 ? row[2] : '',
//         'total_capacity': row.length > 3 ? row[3] : '0',
//         'lower_beds_count': row.length > 4 ? row[4] : '0',
//         'upper_beds_count': row.length > 5 ? row[5] : '0',
//         'lower_bed_rent': row.length > 6 ? row[6] : '0',
//         'upper_bed_rent': row.length > 7 ? row[7] : '0',
//         'utility_cost_monthly': row.length > 8 ? row[8] : '0',
//       });
//     }).toList();
//   }

//   Future<void> addRoom(RoomModel room) async {
//     final rows = await _readRange('Rooms', 'A:I');
//     final newRow = [
//       room.roomId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       room.buildingId,
//       room.roomNumber,
//       room.totalCapacity.toString(),
//       room.lowerBedsCount.toString(),
//       room.upperBedsCount.toString(),
//       room.lowerBedRent.toString(),
//       room.upperBedRent.toString(),
//       room.utilityCostMonthly.toString(),
//     ];
//     await _writeRange('Rooms', 'A${rows.length + 1}:I${rows.length + 1}', [
//       newRow,
//     ]);
//   }

//   // Beds CRUD
//   Future<List<BedModel>> getBeds() async {
//     final rows = await _readRange('Beds', 'A2:D');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return BedModel.fromJson({
//         'bed_id': row[0],
//         'room_id': row.length > 1 ? row[1] : '',
//         'bed_type': row.length > 2 ? row[2] : 'LOWER',
//         'status': row.length > 3 ? row[3] : 'VACANT',
//       });
//     }).toList();
//   }

//   Future<void> addBed(BedModel bed) async {
//     final rows = await _readRange('Beds', 'A:D');
//     final newRow = [
//       bed.bedId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       bed.roomId,
//       bed.bedType == BedType.lower ? 'LOWER' : 'UPPER',
//       bed.status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED',
//     ];
//     await _writeRange('Beds', 'A${rows.length + 1}:D${rows.length + 1}', [
//       newRow,
//     ]);
//   }

//   Future<void> updateBedStatus(String bedId, BedStatus status) async {
//     final rows = await _readRange('Beds', 'A2:D');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == bedId) {
//         rows[i][3] = status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED';
//         await _writeRange('Beds', 'A${i + 2}:D${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   // Tenants CRUD
//   Future<List<TenantModel>> getTenants() async {
//     final rows = await _readRange('Tenants', 'A2:J');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return TenantModel.fromJson({
//         'tenant_id': row[0],
//         'tenant_name': row.length > 1 ? row[1] : '',
//         'phone': row.length > 2 ? row[2] : '',
//         'building_id': row.length > 3 ? row[3] : '',
//         'room_id': row.length > 4 ? row[4] : '',
//         'bed_id': row.length > 5 ? row[5] : '',
//         'rent_amount': row.length > 6 ? row[6] : '0',
//         'joining_date': row.length > 7
//             ? row[7]
//             : DateTime.now().toIso8601String().split('T')[0],
//         'rent_due_day': row.length > 8 ? row[8] : '1',
//         'active': row.length > 9 ? row[9] : 'TRUE',
//       });
//     }).toList();
//   }

//   Future<void> addTenant(TenantModel tenant) async {
//     final rows = await _readRange('Tenants', 'A:J');
//     final newRow = [
//       tenant.tenantId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       tenant.tenantName,
//       tenant.phone,
//       tenant.buildingId,
//       tenant.roomId,
//       tenant.bedId,
//       tenant.rentAmount.toString(),
//       tenant.joiningDate.toIso8601String().split('T')[0],
//       tenant.rentDueDay.toString(),
//       tenant.active ? 'TRUE' : 'FALSE',
//     ];
//     await _writeRange('Tenants', 'A${rows.length + 1}:J${rows.length + 1}', [
//       newRow,
//     ]);
//   }

//   // Payments CRUD
//   Future<List<PaymentModel>> getPayments() async {
//     final rows = await _readRange('Payments', 'A2:E');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return PaymentModel.fromJson({
//         'payment_id': row[0],
//         'tenant_id': row.length > 1 ? row[1] : '',
//         'amount': row.length > 2 ? row[2] : '0',
//         'payment_month': row.length > 3 ? row[3] : '',
//         'paid_date': row.length > 4
//             ? row[4]
//             : DateTime.now().toIso8601String().split('T')[0],
//       });
//     }).toList();
//   }

//   Future<void> addPayment(PaymentModel payment) async {
//     final rows = await _readRange('Payments', 'A:E');
//     final newRow = [
//       payment.paymentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       payment.tenantId,
//       payment.amount.toString(),
//       payment.paymentMonth,
//       payment.paidDate.toIso8601String().split('T')[0],
//     ];
//     await _writeRange('Payments', 'A${rows.length + 1}:E${rows.length + 1}', [
//       newRow,
//     ]);
//   }

//   // Update methods
//   Future<void> updateBuilding(BuildingModel building) async {
//     if (building.buildingId == null) return;
//     final rows = await _readRange('Buildings', 'A2:D');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == building.buildingId) {
//         rows[i] = [
//           building.buildingId!,
//           building.buildingName,
//           building.address,
//           building.totalRooms.toString(),
//         ];
//         await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   Future<void> updateRoom(RoomModel room) async {
//     if (room.roomId == null) return;
//     final rows = await _readRange('Rooms', 'A2:I');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == room.roomId) {
//         rows[i] = [
//           room.roomId!,
//           room.buildingId,
//           room.roomNumber,
//           room.totalCapacity.toString(),
//           room.lowerBedsCount.toString(),
//           room.upperBedsCount.toString(),
//           room.lowerBedRent.toString(),
//           room.upperBedRent.toString(),
//           room.utilityCostMonthly.toString(),
//         ];
//         await _writeRange('Rooms', 'A${i + 2}:I${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   Future<void> updateTenant(TenantModel tenant) async {
//     if (tenant.tenantId == null) return;
//     final rows = await _readRange('Tenants', 'A2:J');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == tenant.tenantId) {
//         rows[i] = [
//           tenant.tenantId!,
//           tenant.tenantName,
//           tenant.phone,
//           tenant.buildingId,
//           tenant.roomId,
//           tenant.bedId,
//           tenant.rentAmount.toString(),
//           tenant.joiningDate.toIso8601String().split('T')[0],
//           tenant.rentDueDay.toString(),
//           tenant.active ? 'TRUE' : 'FALSE',
//         ];
//         await _writeRange('Tenants', 'A${i + 2}:J${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   // Delete methods (mark as empty row)
//   Future<void> deleteBuilding(String buildingId) async {
//     final rows = await _readRange('Buildings', 'A2:D');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == buildingId) {
//         await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [
//           ['', '', '', ''],
//         ]);
//         break;
//       }
//     }
//   }

//   Future<void> deleteRoom(String roomId) async {
//     final rows = await _readRange('Rooms', 'A2:I');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == roomId) {
//         await _writeRange('Rooms', 'A${i + 2}:I${i + 2}', [
//           ['', '', '', '', '', '', '', '', ''],
//         ]);
//         break;
//       }
//     }
//   }

//   Future<void> deleteTenant(String tenantId) async {
//     final rows = await _readRange('Tenants', 'A2:J');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == tenantId) {
//         // Mark tenant as inactive instead of deleting
//         rows[i][9] = 'FALSE';
//         await _writeRange('Tenants', 'A${i + 2}:J${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   Future<void> deletePayment(String paymentId) async {
//     final rows = await _readRange('Payments', 'A2:E');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == paymentId) {
//         await _writeRange('Payments', 'A${i + 2}:E${i + 2}', [
//           ['', '', '', '', ''],
//         ]);
//         break;
//       }
//     }
//   }

//   // Helper: Get tenant by ID
//   Future<TenantModel?> getTenantById(String tenantId) async {
//     final tenants = await getTenants();
//     try {
//       return tenants.firstWhere((t) => t.tenantId == tenantId);
//     } catch (e) {
//       return null;
//     }
//   }

//   // Helper: Get payments by tenant ID
//   Future<List<PaymentModel>> getPaymentsByTenantId(String tenantId) async {
//     final payments = await getPayments();
//     return payments.where((p) => p.tenantId == tenantId).toList();
//   }

//   // Helper: Calculate rent balance for a tenant
//   Future<Map<String, dynamic>> getTenantRentBalance(String tenantId) async {
//     final tenant = await getTenantById(tenantId);
//     if (tenant == null) {
//       return {
//         'totalDue': 0.0,
//         'totalPaid': 0.0,
//         'balance': 0.0,
//         'payments': [],
//       };
//     }

//     final payments = await getPaymentsByTenantId(tenantId);
//     final now = DateTime.now();

//     // Calculate months from joining date to current month
//     final joiningDate = tenant.joiningDate;
//     final startMonth = DateTime(joiningDate.year, joiningDate.month);
//     final currentMonth = DateTime(now.year, now.month);

//     int monthsCount = 0;
//     DateTime month = startMonth;
//     while (month.isBefore(currentMonth) ||
//         month.isAtSameMomentAs(currentMonth)) {
//       monthsCount++;
//       month = DateTime(month.year, month.month + 1);
//     }

//     final totalDue = tenant.rentAmount * monthsCount;
//     final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
//     final balance = totalDue - totalPaid;

//     return {
//       'totalDue': totalDue,
//       'totalPaid': totalPaid,
//       'balance': balance,
//       'payments': payments,
//       'tenant': tenant,
//     };
//   }
// }

































// /// Google Sheets API Service
// ///
// /// IMPORTANT DISCLAIMER:
// /// This service directly calls Google Sheets API from the client.
// /// One Google user → one Google Sheet per device (enforced locally via SharedPreferences).
// /// On app reinstall, a new sheet may be created.
// /// No global uniqueness enforcement is possible without a backend.
// ///
// /// This app:
// /// - Is client-only
// /// - Does not guarantee uniqueness across devices
// /// - Is not suitable for high-security financial data
// /// - Is designed for internal / prototype usage

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import '../models/building_model.dart';
// import '../models/room_model.dart';
// import '../models/bed_model.dart';
// import '../models/tenant_model.dart';
// import '../models/payment_model.dart';
// import '../repositories/sheet_repository.dart';
// import 'google_auth_service.dart';

// class GoogleSheetsService {
  
//   String? _accessToken;
//   String? _sheetId;
//   final SheetRepository _sheetRepository = SheetRepository();
//   final GoogleAuthService _authService = GoogleAuthService();

//   GoogleSheetsService();

//   static const String _baseUrl = 'https://sheets.googleapis.com/v4/spreadsheets';
//   static const String _driveUrl = 'https://www.googleapis.com/drive/v3/files';



//   Future<void> initialize() async {
//     _accessToken = 
//     // await _authService.signInSilently();
//     // await _authService.getAccessToken();
//                await _sheetRepository.getToken();

//     _sheetId = await _sheetRepository.getSheetId();

//     debugPrint(
//         'GoogleSheetsService initialized with Sheet ID: $_sheetId and Access Token: $_accessToken');

//     if (_accessToken == null || _accessToken!.isEmpty) {
//       throw Exception('Access token not found. Please login again.');
//     }

//     if (_sheetId == null || _sheetId!.isEmpty) {
//       throw Exception('Sheet ID not found. Please set up your sheet.');
//     }
//   }

//   /// Check if service is initialized
//   bool get isInitialized => _accessToken != null && _sheetId != null;

//   /// Get headers for API requests
//   Map<String, String> get _headers {
//     if (_accessToken == null || _accessToken!.isEmpty) {
//       throw Exception('Service not initialized. Call initialize() first......***');
//     }
//     return {
//       'Authorization': 'Bearer $_accessToken',
//       'Content-Type': 'application/json',
//     };
//   }


//   // Map<String, String> get _headers => {
//   //       'Authorization': 'Bearer $accessToken',
//   //       'Content-Type': 'application/json',
//   //     };

//   /// Create a new Google Sheet with required tabs
//   static Future<String> createSheet(String accessToken, String sheetName) async {
//     try {
//       // Create spreadsheet structure
//       final spreadsheet = {
//         'properties': {'title': sheetName},
//         'sheets': [
//           {
//             'properties': {
//               'title': 'Buildings',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10}
//             }
//           },
//           {
//             'properties': {
//               'title': 'Rooms',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10}
//             }
//           },
//           {
//             'properties': {
//               'title': 'Beds',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10}
//             }
//           },
//           {
//             'properties': {
//               'title': 'Tenants',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10}
//             }
//           },
//           {
//             'properties': {
//               'title': 'Payments',
//               'gridProperties': {'rowCount': 1000, 'columnCount': 10}
//             }
//           },
//         ],
//       };

//       final response = await http.post(
//         Uri.parse('$_baseUrl'),
//         headers: {
//           'Authorization': 'Bearer $accessToken',
//           'Content-Type': 'application/json',
//         },
//         body: jsonEncode(spreadsheet),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final sheetId = data['spreadsheetId'];

//         // Initialize headers for each sheet
//         final service = GoogleSheetsService(
//           // accessToken: accessToken,
//           // sheetId: sheetId,
//         );

//         await service._initializeSheetHeaders();

//         return sheetId;
//       } else {
//         throw Exception('Failed to create sheet: ${response.body}');
//       }
//     } catch (e) {
//       throw Exception('Error creating sheet: $e');
//     }
//   }

//   /// Initialize headers for all sheets
//   Future<void> _initializeSheetHeaders() async {
//     final headers = {
//       'Buildings': ['building_id', 'building_name', 'address', 'total_rooms'],
//       'Rooms': [
//         'room_id',
//         'building_id',
//         'room_number',
//         'total_capacity',
//         'lower_beds_count',
//         'upper_beds_count',
//         'lower_bed_rent',
//         'upper_bed_rent',
//         'utility_cost_monthly'
//       ],
//       'Beds': ['bed_id', 'room_id', 'bed_type', 'status'],
//       'Tenants': [
//         'tenant_id',
//         'tenant_name',
//         'phone',
//         'building_id',
//         'room_id',
//         'bed_id',
//         'rent_amount',
//         'joining_date',
//         'rent_due_day',
//         'active'
//       ],
//       'Payments': ['payment_id', 'tenant_id', 'amount', 'payment_month', 'paid_date'],
//     };

//     for (final entry in headers.entries) {
//       await _writeRange(entry.key, 'A1:${_getColumnLetter(entry.value.length)}1', [
//         entry.value
//       ]);
//     }
//   }

//   String _getColumnLetter(int column) {
//     String result = '';
//     while (column > 0) {
//       column--;
//       result = String.fromCharCode(65 + (column % 26)) + result;
//       column ~/= 26;
//     }
//     return result;
//   }

//   /// Write data to a range in the sheet
//   Future<void> _writeRange(String sheetName, String range, List<List<dynamic>> values) async {
//     final url = '$_baseUrl/$_sheetId/values/$sheetName!$range?valueInputOption=RAW';

//     final response = await http.put(
//       Uri.parse(url),
//       headers: _headers,
//       body: jsonEncode({'values': values}),
//     );

//     if (response.statusCode != 200) {
//       throw Exception('Failed to write to sheet: ${response.body}');
//     }
//   }

//   /// Read data from a range in the sheet
//   Future<List<List<String>>> _readRange(String sheetName, String range) async {
//     final url = '$_baseUrl/$_sheetId/values/$sheetName!$range';

//     final response = await http.get(Uri.parse(url), headers: _headers);

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       final List<dynamic> values = data['values'] ?? [];
//       return values
//           .map((row) => (row as List<dynamic>)
//               .map((cell) => cell?.toString() ?? '')
//               .toList())
//           .toList()
//           .cast<List<String>>();
//     } else {
//       throw Exception('Failed to read from sheet: ${response.body}');
//     }
//   }

//   // Buildings CRUD
//   Future<List<BuildingModel>> getBuildings() async {
//     final rows = await _readRange('Buildings', 'A2:D');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return BuildingModel.fromJson({
//         'building_id': row[0],
//         'building_name': row.length > 1 ? row[1] : '',
//         'address': row.length > 2 ? row[2] : '',
//         'total_rooms': row.length > 3 ? row[3] : '0',
//       });
//     }).toList();
//   }

//   Future<void> addBuilding(BuildingModel building) async {
//     final rows = await _readRange('Buildings', 'A:D');
//     final newRow = [
//       building.buildingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       building.buildingName,
//       building.address,
//       building.totalRooms.toString(),
//     ];
//     await _writeRange('Buildings', 'A${rows.length + 1}:D${rows.length + 1}', [newRow]);
//   }

//   // Rooms CRUD
//   Future<List<RoomModel>> getRooms() async {
//     final rows = await _readRange('Rooms', 'A2:I');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return RoomModel.fromJson({
//         'room_id': row[0],
//         'building_id': row.length > 1 ? row[1] : '',
//         'room_number': row.length > 2 ? row[2] : '',
//         'total_capacity': row.length > 3 ? row[3] : '0',
//         'lower_beds_count': row.length > 4 ? row[4] : '0',
//         'upper_beds_count': row.length > 5 ? row[5] : '0',
//         'lower_bed_rent': row.length > 6 ? row[6] : '0',
//         'upper_bed_rent': row.length > 7 ? row[7] : '0',
//         'utility_cost_monthly': row.length > 8 ? row[8] : '0',
//       });
//     }).toList();
//   }

//   Future<void> addRoom(RoomModel room) async {
//     final rows = await _readRange('Rooms', 'A:I');
//     final newRow = [
//       room.roomId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       room.buildingId,
//       room.roomNumber,
//       room.totalCapacity.toString(),
//       room.lowerBedsCount.toString(),
//       room.upperBedsCount.toString(),
//       room.lowerBedRent.toString(),
//       room.upperBedRent.toString(),
//       room.utilityCostMonthly.toString(),
//     ];
//     await _writeRange('Rooms', 'A${rows.length + 1}:I${rows.length + 1}', [newRow]);
//   }

//   // Beds CRUD
//   Future<List<BedModel>> getBeds() async {
//     final rows = await _readRange('Beds', 'A2:D');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return BedModel.fromJson({
//         'bed_id': row[0],
//         'room_id': row.length > 1 ? row[1] : '',
//         'bed_type': row.length > 2 ? row[2] : 'LOWER',
//         'status': row.length > 3 ? row[3] : 'VACANT',
//       });
//     }).toList();
//   }

//   Future<void> addBed(BedModel bed) async {
//     final rows = await _readRange('Beds', 'A:D');
//     final newRow = [
//       bed.bedId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       bed.roomId,
//       bed.bedType == BedType.lower ? 'LOWER' : 'UPPER',
//       bed.status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED',
//     ];
//     await _writeRange('Beds', 'A${rows.length + 1}:D${rows.length + 1}', [newRow]);
//   }

//   Future<void> updateBedStatus(String bedId, BedStatus status) async {
//     final rows = await _readRange('Beds', 'A2:D');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == bedId) {
//         rows[i][3] = status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED';
//         await _writeRange('Beds', 'A${i + 2}:D${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   // Tenants CRUD
//   Future<List<TenantModel>> getTenants() async {
//     final rows = await _readRange('Tenants', 'A2:J');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return TenantModel.fromJson({
//         'tenant_id': row[0],
//         'tenant_name': row.length > 1 ? row[1] : '',
//         'phone': row.length > 2 ? row[2] : '',
//         'building_id': row.length > 3 ? row[3] : '',
//         'room_id': row.length > 4 ? row[4] : '',
//         'bed_id': row.length > 5 ? row[5] : '',
//         'rent_amount': row.length > 6 ? row[6] : '0',
//         'joining_date': row.length > 7 ? row[7] : DateTime.now().toIso8601String().split('T')[0],
//         'rent_due_day': row.length > 8 ? row[8] : '1',
//         'active': row.length > 9 ? row[9] : 'TRUE',
//       });
//     }).toList();
//   }

//   Future<void> addTenant(TenantModel tenant) async {
//     final rows = await _readRange('Tenants', 'A:J');
//     final newRow = [
//       tenant.tenantId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       tenant.tenantName,
//       tenant.phone,
//       tenant.buildingId,
//       tenant.roomId,
//       tenant.bedId,
//       tenant.rentAmount.toString(),
//       tenant.joiningDate.toIso8601String().split('T')[0],
//       tenant.rentDueDay.toString(),
//       tenant.active ? 'TRUE' : 'FALSE',
//     ];
//     await _writeRange('Tenants', 'A${rows.length + 1}:J${rows.length + 1}', [newRow]);
//   }

//   // Payments CRUD
//   Future<List<PaymentModel>> getPayments() async {
//     final rows = await _readRange('Payments', 'A2:E');
//     return rows.where((row) => row.isNotEmpty && row[0].isNotEmpty).map((row) {
//       return PaymentModel.fromJson({
//         'payment_id': row[0],
//         'tenant_id': row.length > 1 ? row[1] : '',
//         'amount': row.length > 2 ? row[2] : '0',
//         'payment_month': row.length > 3 ? row[3] : '',
//         'paid_date': row.length > 4 ? row[4] : DateTime.now().toIso8601String().split('T')[0],
//       });
//     }).toList();
//   }

//   Future<void> addPayment(PaymentModel payment) async {
//     final rows = await _readRange('Payments', 'A:E');
//     final newRow = [
//       payment.paymentId ?? DateTime.now().millisecondsSinceEpoch.toString(),
//       payment.tenantId,
//       payment.amount.toString(),
//       payment.paymentMonth,
//       payment.paidDate.toIso8601String().split('T')[0],
//     ];
//     await _writeRange('Payments', 'A${rows.length + 1}:E${rows.length + 1}', [newRow]);
//   }

//   // Update methods
//   Future<void> updateBuilding(BuildingModel building) async {
//     if (building.buildingId == null) return;
//     final rows = await _readRange('Buildings', 'A2:D');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == building.buildingId) {
//         rows[i] = [
//           building.buildingId!,
//           building.buildingName,
//           building.address,
//           building.totalRooms.toString(),
//         ];
//         await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   Future<void> updateRoom(RoomModel room) async {
//     if (room.roomId == null) return;
//     final rows = await _readRange('Rooms', 'A2:I');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == room.roomId) {
//         rows[i] = [
//           room.roomId!,
//           room.buildingId,
//           room.roomNumber,
//           room.totalCapacity.toString(),
//           room.lowerBedsCount.toString(),
//           room.upperBedsCount.toString(),
//           room.lowerBedRent.toString(),
//           room.upperBedRent.toString(),
//           room.utilityCostMonthly.toString(),
//         ];
//         await _writeRange('Rooms', 'A${i + 2}:I${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   Future<void> updateTenant(TenantModel tenant) async {
//     if (tenant.tenantId == null) return;
//     final rows = await _readRange('Tenants', 'A2:J');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == tenant.tenantId) {
//         rows[i] = [
//           tenant.tenantId!,
//           tenant.tenantName,
//           tenant.phone,
//           tenant.buildingId,
//           tenant.roomId,
//           tenant.bedId,
//           tenant.rentAmount.toString(),
//           tenant.joiningDate.toIso8601String().split('T')[0],
//           tenant.rentDueDay.toString(),
//           tenant.active ? 'TRUE' : 'FALSE',
//         ];
//         await _writeRange('Tenants', 'A${i + 2}:J${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   // Delete methods (mark as empty row)
//   Future<void> deleteBuilding(String buildingId) async {
//     final rows = await _readRange('Buildings', 'A2:D');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == buildingId) {
//         await _writeRange('Buildings', 'A${i + 2}:D${i + 2}', [['', '', '', '']]);
//         break;
//       }
//     }
//   }

//   Future<void> deleteRoom(String roomId) async {
//     final rows = await _readRange('Rooms', 'A2:I');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == roomId) {
//         await _writeRange('Rooms', 'A${i + 2}:I${i + 2}', [['', '', '', '', '', '', '', '', '']]);
//         break;
//       }
//     }
//   }

//   Future<void> deleteTenant(String tenantId) async {
//     final rows = await _readRange('Tenants', 'A2:J');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == tenantId) {
//         // Mark tenant as inactive instead of deleting
//         rows[i][9] = 'FALSE';
//         await _writeRange('Tenants', 'A${i + 2}:J${i + 2}', [rows[i]]);
//         break;
//       }
//     }
//   }

//   Future<void> deletePayment(String paymentId) async {
//     final rows = await _readRange('Payments', 'A2:E');
//     for (int i = 0; i < rows.length; i++) {
//       if (rows[i][0] == paymentId) {
//         await _writeRange('Payments', 'A${i + 2}:E${i + 2}', [['', '', '', '', '']]);
//         break;
//       }
//     }
//   }

//   // Helper: Get tenant by ID
//   Future<TenantModel?> getTenantById(String tenantId) async {
//     final tenants = await getTenants();
//     try {
//       return tenants.firstWhere((t) => t.tenantId == tenantId);
//     } catch (e) {
//       return null;
//     }
//   }

//   // Helper: Get payments by tenant ID
//   Future<List<PaymentModel>> getPaymentsByTenantId(String tenantId) async {
//     final payments = await getPayments();
//     return payments.where((p) => p.tenantId == tenantId).toList();
//   }

//   // Helper: Calculate rent balance for a tenant
//   Future<Map<String, dynamic>> getTenantRentBalance(String tenantId) async {
//     final tenant = await getTenantById(tenantId);
//     if (tenant == null) {
//       return {'totalDue': 0.0, 'totalPaid': 0.0, 'balance': 0.0, 'payments': []};
//     }

//     final payments = await getPaymentsByTenantId(tenantId);
//     final now = DateTime.now();

//     // Calculate months from joining date to current month
//     final joiningDate = tenant.joiningDate;
//     final startMonth = DateTime(joiningDate.year, joiningDate.month);
//     final currentMonth = DateTime(now.year, now.month);

//     int monthsCount = 0;
//     DateTime month = startMonth;
//     while (month.isBefore(currentMonth) || month.isAtSameMomentAs(currentMonth)) {
//       monthsCount++;
//       month = DateTime(month.year, month.month + 1);
//     }

//     final totalDue = tenant.rentAmount * monthsCount;
//     final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amount);
//     final balance = totalDue - totalPaid;

//     return {
//       'totalDue': totalDue,
//       'totalPaid': totalPaid,
//       'balance': balance,
//       'payments': payments,
//       'tenant': tenant,
//     };
//   }
// }











