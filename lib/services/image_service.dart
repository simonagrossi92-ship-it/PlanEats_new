import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class ImageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final Uuid _uuid = Uuid();

  /// Compress image to target dimensions and quality
  static Future<File> compressImage(File imageFile) async {
    try {
      final filePath = imageFile.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'\.'));
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_out${filePath.substring(lastIndex)}";

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 75,
        minWidth: 800,
        minHeight: 600,
      );

      if (compressedImage != null) {
        return File(compressedImage.path);
      }
      return imageFile;
    } catch (e) {
      print('Error compressing image: $e');
      return imageFile;
    }
  }

  /// Generate thumbnail for list views (smaller size)
  static Future<File> generateThumbnail(File imageFile) async {
    try {
      final filePath = imageFile.absolute.path;
      final lastIndex = filePath.lastIndexOf(RegExp(r'\.'));
      final splitted = filePath.substring(0, (lastIndex));
      final outPath = "${splitted}_thumb${filePath.substring(lastIndex)}";

      final thumbnail = await FlutterImageCompress.compressAndGetFile(
        filePath,
        outPath,
        quality: 70,
        minWidth: 300,
        minHeight: 200,
      );

      if (thumbnail != null) {
        return File(thumbnail.path);
      }
      return imageFile;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return imageFile;
    }
  }

  /// Upload image to Firebase Storage and return download URL
  static Future<String?> uploadImage(File imageFile, String recipeId) async {
    try {
      final fileName = 'recipes/$recipeId/${_uuid.v4()}.jpg';
      final ref = _storage.ref().child(fileName);

      final uploadTask = ref.putFile(imageFile);
      final snapshot = await uploadTask;

      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// Delete image from Firebase Storage
  static Future<void> deleteImage(String imageUrl) async {
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      print('Error deleting image: $e');
    }
  }
}
