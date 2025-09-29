import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stored_code.dart';

class CodeStorage {
  CodeStorage._(this._preferences, this._codesDirectory);

  final SharedPreferences _preferences;
  final Directory _codesDirectory;

  static const _storageKey = 'buylistguardian.codes';

  static Future<CodeStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    final documentsDir = await getApplicationDocumentsDirectory();
    final codesDir = Directory(p.join(documentsDir.path, 'codes'));
    if (!await codesDir.exists()) {
      await codesDir.create(recursive: true);
    }
    return CodeStorage._(prefs, codesDir);
  }

  Directory get codesDirectory => _codesDirectory;

  Future<List<StoredCode>> loadCodes() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    try {
      return StoredCode.decodeList(raw);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCodes(List<StoredCode> codes) async {
    final encoded = StoredCode.encodeList(codes);
    await _preferences.setString(_storageKey, encoded);
  }

  Future<String> reserveImagePath(String id, String extension) async {
    final sanitizedExtension = extension.replaceAll('.', '');
    final fileName = '$id.$sanitizedExtension';
    return p.join(_codesDirectory.path, fileName);
  }

  Future<void> deleteImageIfExists(String imagePath) async {
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignore deletion errors to avoid blocking user actions.
    }
  }
}
