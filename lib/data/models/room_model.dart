/// Room data model
class RoomModel {
  final bool available;
  final String? roomId;
  final String buildingId;
  final String roomNumber;
  final String? parentRoomId;
  final int totalCapacity;
  final int lowerBedsCount;
  final int upperBedsCount;
  final double lowerBedRent;
  final double upperBedRent;
  final double
      utilityCostMonthly; // Kept for backward compatibility or estimates
  final double monthlyRent; // Base rent paid to landlord

  RoomModel({
    this.available = true,
    this.roomId,
    required this.buildingId,
    required this.roomNumber,
    this.parentRoomId,
    required this.totalCapacity,
    required this.lowerBedsCount,
    required this.upperBedsCount,
    required this.lowerBedRent,
    required this.upperBedRent,
    required this.utilityCostMonthly,
    this.monthlyRent = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'available': available ? 'TRUE' : 'FALSE',
      'room_id': roomId ?? '',
      'building_id': buildingId,
      'room_number': roomNumber,
      'parent_room_id': parentRoomId,
      'total_capacity': totalCapacity,
      'lower_beds_count': lowerBedsCount,
      'upper_beds_count': upperBedsCount,
      'lower_bed_rent': lowerBedRent,
      'upper_bed_rent': upperBedRent,
      'utility_cost_monthly': utilityCostMonthly,
      'monthly_rent': monthlyRent,
    };
  }

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    return RoomModel(
      available:
          !['FALSE', '0'].contains(json['available']?.toString().toUpperCase()),
      roomId: json['room_id']?.toString(),
      buildingId: json['building_id']?.toString() ?? '',
      roomNumber: json['room_number']?.toString() ?? '',
      parentRoomId: (json['parent_room_id']?.toString().trim().isEmpty ?? true)
          ? null
          : json['parent_room_id'].toString().trim(),
      totalCapacity:
          int.tryParse(json['total_capacity']?.toString() ?? '0') ?? 0,
      lowerBedsCount:
          int.tryParse(json['lower_beds_count']?.toString() ?? '0') ?? 0,
      upperBedsCount:
          int.tryParse(json['upper_beds_count']?.toString() ?? '0') ?? 0,
      lowerBedRent:
          double.tryParse(json['lower_bed_rent']?.toString() ?? '0') ?? 0.0,
      upperBedRent:
          double.tryParse(json['upper_bed_rent']?.toString() ?? '0') ?? 0.0,
      utilityCostMonthly:
          double.tryParse(json['utility_cost_monthly']?.toString() ?? '0') ??
              0.0,
      monthlyRent:
          double.tryParse(json['monthly_rent']?.toString() ?? '0') ?? 0.0,
    );
  }

  bool get isSubroom => parentRoomId != null && parentRoomId!.isNotEmpty;
  bool isAvailable(Iterable<RoomModel> rooms) =>
      available &&
      (!isSubroom ||
          rooms.where((r) => r.roomId == parentRoomId).firstOrNull?.available ==
              true);

  String displayName(Iterable<RoomModel> rooms) {
    if (!isSubroom) return 'Room $roomNumber';
    final parent =
        rooms.where((room) => room.roomId == parentRoomId).firstOrNull;
    return parent == null
        ? 'Subroom $roomNumber'
        : 'Room ${parent.roomNumber} / Subroom $roomNumber';
  }

  /// Only one level of subrooms is supported; each space owns its own beds.
  void validateHierarchy(Iterable<RoomModel> rooms) {
    if (isSubroom) {
      final parent =
          rooms.where((room) => room.roomId == parentRoomId).firstOrNull;
      if (parent == null ||
          parent.roomId == roomId ||
          parent.isSubroom ||
          parent.buildingId != buildingId) {
        throw ArgumentError('Choose a main room in the same building.');
      }
    }
    final children =
        rooms.where((room) => room.parentRoomId == roomId && roomId != null);
    if (children.any((child) => isSubroom || child.buildingId != buildingId)) {
      throw ArgumentError(
          'A room with subrooms must stay in its current building as a main room.');
    }
    if (rooms.any((room) =>
        room.roomId != roomId &&
        room.buildingId == buildingId &&
        room.parentRoomId == parentRoomId &&
        room.roomNumber.trim().toLowerCase() ==
            roomNumber.trim().toLowerCase())) {
      throw ArgumentError(
          'This room name already exists in the selected location.');
    }
  }
}
