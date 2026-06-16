import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class UnsplashService {
  // Using Picsum Photos API (free, no key required)
  static const String _baseUrl = 'https://picsum.photos';

  // Search for an image based on a query
  Future<String?> searchImage(String query,
      {int width = 800, int height = 600}) async {
    try {
      // Build the URL for Picsum Photos (using seed for consistent images)
      final seed = query.replaceAll(' ', '_');
      final url = '$_baseUrl/seed/$seed/$width/$height';

      debugPrint('Searching image for: $query');
      debugPrint('URL: $url');

      // Download the image
      final response = await http.get(Uri.parse(url));

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body length: ${response.bodyBytes.length}');

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Save the image locally
        final localPath = await _saveImageLocally(response.bodyBytes, query);
        debugPrint('Image saved to: $localPath');
        return localPath;
      } else {
        debugPrint('Failed to download image: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error searching image: $e');
      return null;
    }
  }

  // Save image to local storage
  Future<String> _saveImageLocally(List<int> bytes, String query) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName =
        '${query.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = path.join(directory.path, fileName);

    final file = File(filePath);
    await file.writeAsBytes(bytes);

    return filePath;
  }

  // Check if image exists locally
  Future<bool> imageExists(String query) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();

      // Look for files matching the query
      for (var file in files) {
        if (file is File && file.path.contains(query.replaceAll(' ', '_'))) {
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('Error checking image existence: $e');
      return false;
    }
  }

  // Get local image path if exists
  Future<String?> getLocalImagePath(String query) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();

      // Look for files matching the query
      for (var file in files) {
        if (file is File && file.path.contains(query.replaceAll(' ', '_'))) {
          return file.path;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting local image path: $e');
      return null;
    }
  }

  // Clear all cached images
  Future<void> clearCache() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();

      for (var file in files) {
        if (file is File && file.path.endsWith('.jpg')) {
          await file.delete();
        }
      }
      debugPrint('Unsplash cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
}
