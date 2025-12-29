/// Building data model
/// Represents a building in the bed space management system
class BuildingModel {
  final String? buildingId;
  final String buildingName;
  final String address;
  final int totalRooms;

  BuildingModel({
    this.buildingId,
    required this.buildingName,
    required this.address,
    required this.totalRooms,
  });

  Map<String, dynamic> toJson() {
    return {
      'building_id': buildingId ?? '',
      'building_name': buildingName,
      'address': address,
      'total_rooms': totalRooms,
    };
  }

  factory BuildingModel.fromJson(Map<String, dynamic> json) {
    return BuildingModel(
      buildingId: json['building_id']?.toString(),
      buildingName: json['building_name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      totalRooms: int.tryParse(json['total_rooms']?.toString() ?? '0') ?? 0,
    );
  }

  BuildingModel copyWith({
    String? buildingId,
    String? buildingName,
    String? address,
    int? totalRooms,
  }) {
    return BuildingModel(
      buildingId: buildingId ?? this.buildingId,
      buildingName: buildingName ?? this.buildingName,
      address: address ?? this.address,
      totalRooms: totalRooms ?? this.totalRooms,
    );
  }
}

