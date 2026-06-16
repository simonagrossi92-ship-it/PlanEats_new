import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload an image file to Firebase Storage
  /// Returns the download URL of the uploaded image
  Future<String?> uploadImage(File imageFile, String recipeId) async {
    try {
      // Compress the image before uploading
      final compressedFile = await _compressImage(imageFile);

      // Create a unique filename
      final fileName =
          '${recipeId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final ref = _storage.ref().child('recipe_images/$fileName');

      // Upload the file
      final uploadTask = ref.putFile(compressedFile);
      final snapshot = await uploadTask;

      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Delete an image from Firebase Storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  /// Compress image before uploading to save storage space
  Future<File> _compressImage(File file) async {
    try {
      final filePath = file.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'\.jp'));
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = '${splitted}_out${filePath.substring(lastIndex)}';

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 75,
        minWidth: 800,
        minHeight: 600,
      );

      if (compressedImage != null) {
        return File(compressedImage.path);
      }
      return file;
    } catch (e) {
      print('Error compressing image: $e');
      return file;
    }
  }
}
