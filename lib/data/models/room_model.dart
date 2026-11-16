import 'dart:convert';
import 'room_media_model.dart';

enum RoomType { bedspace, partition, studio, wholeRoom }

extension RoomTypeLabel on RoomType {
  String get label => switch (this) {
        RoomType.bedspace => 'Bedspace',
        RoomType.partition => 'Partition',
        RoomType.studio => 'Studio',
        RoomType.wholeRoom => 'Whole room',
      };
}

/// Room data model
class RoomModel {
  final RoomType roomType;
  bool get isWholeUnit => roomType != RoomType.bedspace;
  String get rentalUnitLabel => isWholeUnit ? 'unit' : 'bed';
  final bool available;
  final List<RoomMediaModel> media;
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
    this.roomType = RoomType.bedspace,
    this.available = true,
    this.media = const [],
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
      'room_type': roomType.name,
      'available': available ? 'TRUE' : 'FALSE',
      'media_json': jsonEncode(media.map((media) => media.toJson()).toList()),
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
      roomType: RoomType.values
              .where((type) => type.name == json['room_type'])
              .firstOrNull ??
          RoomType.bedspace,
      media: RoomMediaModel.decode(json['media_json']),
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
    if (!isSubroom) {
      return '${isWholeUnit ? roomType.label : 'Room'} $roomNumber';
    }
    final parent =
        rooms.where((room) => room.roomId == parentRoomId).firstOrNull;
    return parent == null
        ? '${isWholeUnit ? roomType.label : 'Subroom'} $roomNumber'
        : '${parent.isWholeUnit ? parent.roomType.label : 'Room'} ${parent.roomNumber} / ${isWholeUnit ? roomType.label : 'Subroom'} $roomNumber';
  }

  /// Only one level of subrooms is supported; each space owns its own beds.
  void validateHierarchy(Iterable<RoomModel> rooms) {
    if (lowerBedsCount < 0 ||
        upperBedsCount < 0 ||
        totalCapacity != lowerBedsCount + upperBedsCount ||
        !lowerBedRent.isFinite ||
        !upperBedRent.isFinite ||
        lowerBedRent < 0 ||
        upperBedRent < 0) {
      throw ArgumentError(
          'Capacity must match the bed counts, and rents must be non-negative.');
    }
    if (isWholeUnit &&
        (totalCapacity != 1 || lowerBedsCount != 1 || upperBedsCount != 0)) {
      throw ArgumentError(
          'A partition, studio or whole room is rented as one unit.');
    }
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
