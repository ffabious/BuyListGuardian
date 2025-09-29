import 'dart:convert';

class StoredCode {
  const StoredCode({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.createdAt,
  });

  factory StoredCode.newCode({required String name, required String imagePath}) {
    final now = DateTime.now();
    return StoredCode(
      id: now.microsecondsSinceEpoch.toString(),
      name: name,
      imagePath: imagePath,
      createdAt: now,
    );
  }

  factory StoredCode.fromJson(Map<String, dynamic> json) {
    return StoredCode(
      id: json['id'] as String,
      name: json['name'] as String,
      imagePath: json['imagePath'] as String,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String name;
  final String imagePath;
  final DateTime createdAt;

  StoredCode copyWith({String? name, String? imagePath}) {
    return StoredCode(
      id: id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static List<StoredCode> decodeList(String raw) {
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((entry) => StoredCode.fromJson(Map<String, dynamic>.from(entry)))
        .toList();
  }

  static String encodeList(List<StoredCode> codes) {
    final serialized = codes.map((code) => code.toJson()).toList();
    return jsonEncode(serialized);
  }
}
