import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class StorageService {
  static const String _cloudName = 'dsdxwsesv';
  static const String _uploadPreset = 'benevoles_upload';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload une image vers Cloudinary et retourne le secure_url.
  /// Compatible Flutter Web et mobile.
  Future<String> uploadActionPhoto(String actionId, Uint8List imageData) async {
    debugPrint('Cloudinary: upload en cours (${(imageData.length / 1024).toStringAsFixed(0)} KB)...');

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageData,
          filename: '$actionId.jpg',
        ),
      );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
    );

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = jsonResponse['secure_url'] as String;
      debugPrint('Cloudinary: upload réussi ! URL: $secureUrl');
      return secureUrl;
    } else {
      throw Exception(
        'Cloudinary upload échoué (${response.statusCode}): ${response.body}',
      );
    }
  }
}
