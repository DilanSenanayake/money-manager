import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcr {
  Future<String> extractText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(input);
      final cleaned = result.text
          .replaceAll('\r', '')
          .replaceAll(RegExp(r'[ \t]+\n'), '\n')
          .trim();
      return cleaned;
    } finally {
      await recognizer.close();
    }
  }
}
