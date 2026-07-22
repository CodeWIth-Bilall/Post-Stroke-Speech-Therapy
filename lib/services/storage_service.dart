import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload audio file and return download URL
  Future<String?> uploadAudio({
    required String userId,
    required String sessionId,
    required String filePath,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final fileName = path.basename(filePath);
      final ref = _storage.ref().child('audio/$userId/$sessionId/$fileName');

      final uploadTask = await ref.putFile(
        file,
        SettableMetadata(contentType: 'audio/wav'),
      );

      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // Get download URL for an existing file
  Future<String?> getDownloadUrl(String storagePath) async {
    try {
      return await _storage.ref(storagePath).getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  // List audio files for a session
  Future<List<String>> listSessionAudios(String userId, String sessionId) async {
    try {
      final result = await _storage.ref('audio/$userId/$sessionId').listAll();
      final urls = <String>[];
      for (var item in result.items) {
        urls.add(await item.getDownloadURL());
      }
      return urls;
    } catch (e) {
      return [];
    }
  }
}
