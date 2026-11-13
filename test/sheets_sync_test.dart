import 'dart:convert';

import 'package:bed_space/data/models/bed_model.dart';
import 'package:bed_space/data/models/booking_model.dart';
import 'package:bed_space/data/services/google_sheets_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('existing spreadsheets gain a Bookings tab and retain booking payments',
      () async {
    var exists = false;
    var created = 0;
    final rows = <List<dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.queryParameters['fields'] != null) {
        return http.Response(
            jsonEncode({
              'sheets': [
                if (exists)
                  {
                    'properties': {'title': 'Bookings'}
                  },
              ]
            }),
            200);
      }
      if (request.method == 'POST') {
        expect(
            jsonDecode(request.body)['requests'][0]['addSheet']['properties']
                ['title'],
            'Bookings');
        exists = true;
        created++;
        return http.Response('{}', 200);
      }
      if (request.method == 'PUT') {
        final value =
            (jsonDecode(request.body)['values'] as List).single as List;
        if (request.url.path.endsWith('A1:N1')) {
          rows.add(value);
        } else {
          expect(request.url.path.endsWith('A2:N2'), isTrue);
          if (rows.length == 1) {
            rows.add(value);
          } else {
            rows[1] = value;
          }
        }
        return http.Response('{}', 200);
      }
      return http.Response(
          jsonEncode({
            'values':
                request.url.path.endsWith('A2:N') ? rows.skip(1).toList() : rows
          }),
          200);
    });
    await http.runWithClient(() async {
      final sheets =
          GoogleSheetsService(accessToken: 'test', sheetId: 'legacy');
      final booking = BookingModel(
          bookingId: 'booking',
          tenantName: 'Future tenant',
          phone: '050123',
          buildingId: 'building',
          roomId: 'room',
          bedId: 'bed',
          moveInDate: DateTime(2026, 12, 31),
          rentAmount: 1000,
          advanceAmount: 200,
          rentPaid: 500,
          paymentDate: DateTime(2026, 11, 13),
          rentDueDay: 1);
      await sheets.saveBooking(booking);
      await sheets.saveBooking(booking);
      expect((await sheets.getBookings()).single.toJson(), booking.toJson());
      expect(created, 1);
      expect(rows.length, 2);
    }, () => client);
  });
  final service = GoogleSheetsService(accessToken: 'test', sheetId: 'sheet');

  test('retrying a bed addition overwrites the existing ID', () async {
    final writes = <http.Request>[];
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode({
              'values': [
                ['bed_id', 'room_id', 'bed_type', 'status'],
                ['bed', 'room', 'LOWER', 'VACANT'],
              ]
            }),
            200);
      }
      writes.add(request);
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      final bed = BedModel(
          bedId: 'bed',
          roomId: 'room',
          bedType: BedType.lower,
          status: BedStatus.occupied);
      await service.addBed(bed);
      await service.addBed(bed);
    }, () => client);
    expect(writes, hasLength(2));
    expect(writes.every((request) => request.url.path.endsWith('Beds!A2:D2')),
        isTrue);
  });

  test('occupancy writes handle truncated rows and retry missing beds',
      () async {
    var found = true;
    http.Request? write;
    final client = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response(
            jsonEncode({
              'values': found
                  ? [
                      [],
                      ['bed']
                    ]
                  : []
            }),
            200);
      }
      write = request;
      return http.Response('{}', 200);
    });
    await http.runWithClient(() async {
      await service.updateBedStatus('bed', BedStatus.occupied);
      expect(write!.url.path.endsWith('Beds!D3'), isTrue);
      expect(jsonDecode(write!.body)['values'], [
        ['OCCUPIED']
      ]);
      found = false;
      await expectLater(
          service.updateBedStatus('bed', BedStatus.vacant), throwsStateError);
    }, () => client);
  });

  test('expense refresh includes the tenant association stored in column G',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path.endsWith('Expenses!A2:G'), isTrue);
      return http.Response(
          jsonEncode({
            'values': [
              [
                'expense',
                'room',
                'REFUND',
                '100',
                '2026-11-13',
                'Refund',
                'tenant'
              ],
            ]
          }),
          200);
    });
    await http.runWithClient(() async {
      expect((await service.getExpenses()).single.tenantId, 'tenant');
    }, () => client);
  });
}
