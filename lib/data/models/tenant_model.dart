/// Tenant data model
class TenantModel {
  final String? tenantId;
  final String tenantName;
  final String phone;
  final String buildingId;
  final String roomId;
  final String bedId;
  final double rentAmount;
  final double advanceAmount;
  final DateTime joiningDate;
  final int rentDueDay;
  final bool active;

  TenantModel({
    this.tenantId,
    required this.tenantName,
    required this.phone,
    required this.buildingId,
    required this.roomId,
    required this.bedId,
    required this.rentAmount,
    required this.advanceAmount,
    required this.joiningDate,
    required this.rentDueDay,
    required this.active,
  });

  Map<String, dynamic> toJson() {
    return {
      'tenant_id': tenantId ?? '',
      'tenant_name': tenantName,
      'phone': phone,
      'building_id': buildingId,
      'room_id': roomId,
      'bed_id': bedId,
      'rent_amount': rentAmount,
      'advance_amount': advanceAmount,
      'joining_date': joiningDate.toIso8601String().split('T')[0],
      'rent_due_day': rentDueDay,
      'active': active ? 'TRUE' : 'FALSE',
    };
  }

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      tenantId: json['tenant_id']?.toString(),
      tenantName: json['tenant_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      buildingId: json['building_id']?.toString() ?? '',
      roomId: json['room_id']?.toString() ?? '',
      bedId: json['bed_id']?.toString() ?? '',
      rentAmount: double.tryParse(json['rent_amount']?.toString() ?? '0') ?? 0.0,
      advanceAmount: double.tryParse(json['advance_amount']?.toString() ?? '0') ?? 0.0,
      joiningDate: DateTime.tryParse(json['joining_date']?.toString() ?? '') ?? DateTime.now(),
      rentDueDay: int.tryParse(json['rent_due_day']?.toString() ?? '1') ?? 1,
      active: json['active']?.toString().toUpperCase() == 'TRUE',
    );
  }

  TenantModel copyWith({
    String? tenantId,
    String? tenantName,
    String? phone,
    String? buildingId,
    String? roomId,
    String? bedId,
    double? rentAmount,
    double? advanceAmount,
    DateTime? joiningDate,
    int? rentDueDay,
    bool? active,
  }) {
    return TenantModel(
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      phone: phone ?? this.phone,
      buildingId: buildingId ?? this.buildingId,
      roomId: roomId ?? this.roomId,
      bedId: bedId ?? this.bedId,
      rentAmount: rentAmount ?? this.rentAmount,
      advanceAmount: advanceAmount ?? this.advanceAmount,
      joiningDate: joiningDate ?? this.joiningDate,
      rentDueDay: rentDueDay ?? this.rentDueDay,
      active: active ?? this.active,
    );
  }
}

