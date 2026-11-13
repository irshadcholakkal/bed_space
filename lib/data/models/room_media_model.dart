import 'dart:convert';

class RoomMediaModel {
  final String fileId;
  final String name;
  final String mimeType;
  final int size;
  final String? resourceKey;

  const RoomMediaModel(
      {required this.fileId,
      required this.name,
      required this.mimeType,
      required this.size,
      this.resourceKey});

  bool get isVideo => mimeType.startsWith('video/');
  String get viewUrl => Uri.https(
          'drive.google.com',
          '/file/d/$fileId/view',
          resourceKey == null || resourceKey!.isEmpty
              ? null
              : {'resourcekey': resourceKey!})
      .toString();

  static const mimeTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'heif': 'image/heif',
    'gif': 'image/gif',
    'mp4': 'video/mp4',
    'mov': 'video/quicktime',
    'm4v': 'video/x-m4v',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
  };

  Map<String, dynamic> toJson() => {
        'file_id': fileId,
        'name': name,
        'mime_type': mimeType,
        'size': size,
        'resource_key': resourceKey
      };

  factory RoomMediaModel.fromJson(Map<String, dynamic> json) => RoomMediaModel(
      fileId: json['file_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mimeType: json['mime_type']?.toString() ?? '',
      size: int.tryParse('${json['size']}') ?? 0,
      resourceKey: json['resource_key']?.toString());

  static List<RoomMediaModel> decode(dynamic value) {
    if (value == null || value == '') return const [];
    final rows = value is String ? jsonDecode(value) : value;
    return (rows as List)
        .map((row) => RoomMediaModel.fromJson(Map<String, dynamic>.from(row)))
        .where((media) => media.fileId.isNotEmpty)
        .toList();
  }
}
