/// Room data model
class RoomModel {
  final String? roomId;
  final String buildingId;
  final String roomNumber;
  final int totalCapacity;
  final int lowerBedsCount;
  final int upperBedsCount;
  final double lowerBedRent;
  final double upperBedRent;
  final double utilityCostMonthly;

  RoomModel({
    this.roomId,
    required this.buildingId,
    required this.roomNumber,
    required this.totalCapacity,
    required this.lowerBedsCount,
    required this.upperBedsCount,
    required this.lowerBedRent,
    required this.upperBedRent,
    required this.utilityCostMonthly,
  });

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId ?? '',
      'building_id': buildingId,
      'room_number': roomNumber,
      'total_capacity': totalCapacity,
      'lower_beds_count': lowerBedsCount,
      'upper_beds_count': upperBedsCount,
      'lower_bed_rent': lowerBedRent,
      'upper_bed_rent': upperBedRent,
      'utility_cost_monthly': utilityCostMonthly,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      roomId: json['room_id']?.toString(),
      buildingId: json['building_id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      totalCapacity: int.tryParse(json['total_capacity']?.toString() ?? '0') ?? 0,
      lowerBedsCount: int.tryParse(json['lower_beds_count']?.toString() ?? '0') ?? 0,
      upperBedsCount: int.tryParse(json['upper_beds_count']?.toString() ?? '0') ?? 0,
      lowerBedRent: double.tryParse(json['lower_bed_rent']?.toString() ?? '0') ?? 0.0,
      upperBedRent: double.tryParse(json['upper_bed_rent']?.toString() ?? '0') ?? 0.0,
      utilityCostMonthly: double.tryParse(json['utility_cost_monthly']?.toString() ?? '0') ?? 0.0,
    );
  }
}

