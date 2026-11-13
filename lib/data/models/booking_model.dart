import 'payment_model.dart';
import 'tenant_model.dart';

enum BookingStatus { reserved, checkedIn, cancelled }

class BookingModel {
  final String bookingId;
  final String tenantName;
  final String phone;
  final String buildingId;
  final String roomId;
  final String bedId;
  final DateTime moveInDate;
  final double rentAmount;
  final double advanceAmount;
  final double rentPaid;
  final DateTime paymentDate;
  final int rentDueDay;
  final BookingStatus status;
  final double refundAmount;

  const BookingModel({
    required this.bookingId,
    required this.tenantName,
    required this.phone,
    required this.buildingId,
    required this.roomId,
    required this.bedId,
    required this.moveInDate,
    required this.rentAmount,
    required this.advanceAmount,
    required this.rentPaid,
    required this.paymentDate,
    required this.rentDueDay,
    this.status = BookingStatus.reserved,
    this.refundAmount = 0,
  });

  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  String get rentMonth =>
      '${moveInDate.year}-${moveInDate.month.toString().padLeft(2, '0')}';

  TenantModel toTenant() => TenantModel(
      tenantId: bookingId,
      tenantName: tenantName,
      phone: phone,
      buildingId: buildingId,
      roomId: roomId,
      bedId: bedId,
      rentAmount: rentAmount,
      advanceAmount: advanceAmount,
      joiningDate: day(moveInDate),
      rentDueDay: rentDueDay,
      active: true);

  PaymentModel? get rentPayment => rentPaid > 0
      ? PaymentModel(
          paymentId: 'booking_rent_$bookingId',
          tenantId: bookingId,
          amount: rentPaid,
          paymentMonth: rentMonth,
          paidDate: paymentDate)
      : null;

  BookingModel withStatus(BookingStatus value, {double? refund}) =>
      BookingModel.fromJson({
        ...toJson(),
        'status': value.name,
        'refund_amount': refund ?? refundAmount
      });

  void validate() {
    if ([bookingId, tenantName, phone, buildingId, roomId, bedId]
        .any((value) => value.trim().isEmpty)) {
      throw ArgumentError('Enter tenant details and select a bed.');
    }
    if (!rentAmount.isFinite ||
        rentAmount <= 0 ||
        !advanceAmount.isFinite ||
        advanceAmount < 0 ||
        !rentPaid.isFinite ||
        rentPaid < 0 ||
        !refundAmount.isFinite ||
        refundAmount < 0 ||
        refundAmount > advanceAmount + rentPaid ||
        rentDueDay < 1 ||
        rentDueDay > 31) {
      throw ArgumentError('Enter valid rent, payments and rent due day.');
    }
  }

  Map<String, dynamic> toJson() => {
        'booking_id': bookingId,
        'tenant_name': tenantName,
        'phone': phone,
        'building_id': buildingId,
        'room_id': roomId,
        'bed_id': bedId,
        'move_in_date': day(moveInDate).toIso8601String().split('T').first,
        'rent_amount': rentAmount,
        'advance_amount': advanceAmount,
        'rent_paid': rentPaid,
        'payment_date': day(paymentDate).toIso8601String().split('T').first,
        'rent_due_day': rentDueDay,
        'status': status.name,
        'refund_amount': refundAmount,
      };

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        bookingId: json['booking_id']?.toString() ?? '',
        tenantName: json['tenant_name']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        buildingId: json['building_id']?.toString() ?? '',
        roomId: json['room_id']?.toString() ?? '',
        bedId: json['bed_id']?.toString() ?? '',
        moveInDate: DateTime.parse(json['move_in_date'].toString()),
        rentAmount: double.tryParse('${json['rent_amount']}') ?? 0,
        advanceAmount: double.tryParse('${json['advance_amount']}') ?? 0,
        rentPaid: double.tryParse('${json['rent_paid']}') ?? 0,
        paymentDate: DateTime.parse(json['payment_date'].toString()),
        rentDueDay: int.tryParse('${json['rent_due_day']}') ?? 1,
        status: BookingStatus.values.firstWhere(
            (value) => value.name == json['status'],
            orElse: () => BookingStatus.reserved),
        refundAmount: double.tryParse('${json['refund_amount']}') ?? 0,
      );
}
