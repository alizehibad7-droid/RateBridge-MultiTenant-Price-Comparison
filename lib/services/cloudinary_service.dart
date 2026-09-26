// Cloudinary credentials — cloud_name and upload_preset are safe
// to include in client code since we use unsigned uploads only.
// Never put API secret here.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;

/// Direct multipart uploads to Cloudinary (unsigned preset).
class CloudinaryService {
  CloudinaryService._();

  static const _uploadPreset = 'ratebridge_uploads';
  static const _uploadUrl =
      'https://api.cloudinary.com/v1_1/duv7nuuud/image/upload';

  static Future<String?> uploadImage({
    required String filePath,
    required String folder,
  }) async {
    try {
      final bytes = await XFile(filePath).readAsBytes();
      return uploadImageBytes(bytes: bytes, folder: folder);
    } catch (_) {
      return null;
    }
  }

  /// Uploads image bytes directly — works on Flutter Web and mobile.
  static Future<String?> uploadImageBytes({
    required List<int> bytes,
    required String folder,
    String filename = 'upload.jpg',
  }) async {
    try {
      var uploadBytes = bytes;
      if (!kIsWeb) {
        try {
          final compressed = await FlutterImageCompress.compressWithList(
            Uint8List.fromList(bytes),
            minWidth: 1200,
            minHeight: 1200,
            quality: 75,
            format: CompressFormat.jpeg,
          );
          if (compressed.isNotEmpty) {
            uploadBytes = compressed;
          }
        } catch (_) {}
      }

      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = _uploadPreset;
      request.fields['folder'] = folder;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          uploadBytes,
          filename: filename,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode != 200) return null;

      final json = jsonDecode(body) as Map<String, dynamic>;
      final url = json['secure_url'];
      if (url is String && url.isNotEmpty) return url;
      return null;
    } catch (_) {
      return null;
    }
  }
}
