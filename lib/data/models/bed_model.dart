/// Bed data model
enum BedType { lower, upper }

enum BedStatus { vacant, occupied }

class BedModel {
  final String? bedId;
  final String roomId;
  final BedType bedType;
  final BedStatus status;

  BedModel({
    this.bedId,
    required this.roomId,
    required this.bedType,
    required this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      'bed_id': bedId ?? '',
      'room_id': roomId,
      'bed_type': bedType == BedType.lower ? 'LOWER' : 'UPPER',
      'status': status == BedStatus.vacant ? 'VACANT' : 'OCCUPIED',
    };
  }

  factory BedModel.fromJson(Map<String, dynamic> json) {
    return BedModel(
      bedId: json['bed_id']?.toString(),
      roomId: json['room_id']?.toString() ?? '',
      bedType: (json['bed_type']?.toString().toUpperCase() == 'LOWER')
          ? BedType.lower
          : BedType.upper,
      status: (json['status']?.toString().toUpperCase() == 'VACANT')
          ? BedStatus.vacant
          : BedStatus.occupied,
    );
  }
}

