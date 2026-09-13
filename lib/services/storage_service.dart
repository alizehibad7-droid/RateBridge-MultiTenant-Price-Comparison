import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadFile({
    required String path,
    File? file,
    Uint8List? bytes,
    String? contentType,
  }) async {
    try {
      final ref = _storage.ref().child(path);
      UploadTask uploadTask;
      final metadata = SettableMetadata(contentType: contentType ?? 'image/jpeg');

      if (file != null) {
        uploadTask = ref.putFile(file, metadata);
      } else if (bytes != null) {
        uploadTask = ref.putData(bytes, metadata);
      } else {
        throw Exception("File or Bytes required for upload");
      }

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException {
      rethrow;
    } catch (e) {
      throw Exception("Upload failed: $e");
    }
  }

  Future<void> deleteFile(String url) async {
    final ref = _storage.refFromURL(url);
    await ref.delete();
  }
}
