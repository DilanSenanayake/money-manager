import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../error/failures.dart';

class ReceiptOcr {
  Future<String> extractText(String imagePath) async {
    final file = File(imagePath);
    if (!file.existsSync() || file.lengthSync() < 32) {
      throw const ValidationFailure(
        'That photo could not be opened. Try another picture, or add it manually.',
      );
    }

    final input = InputImage.fromFile(file);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(input);
      final cleaned = result.text
          .replaceAll('\r', '')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .trim();
      return cleaned;
    } catch (_) {
      throw const ValidationFailure(
        'Could not read that photo on this phone. Choose a clearer picture, or add it manually.',
      );
    } finally {
      await recognizer.close();
    }
  }
}
