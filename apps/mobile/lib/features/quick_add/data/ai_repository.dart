import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/exception_mapper.dart';
import '../../../core/error/failures.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/json.dart';
import '../../../shared/models/models.dart';

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepository(ref.watch(ledgerlyApiProvider));
});

class AiRepository {
  AiRepository(this._api);

  final LedgerlyApi _api;

  Future<ReceiptExtraction> parseReceipt(String ocrText) async {
    final text = ocrText.replaceAll('\r', '').trim();
    if (text.length < 8) {
      throw const ValidationFailure(
        'We couldn’t read enough from that photo. Try a clearer picture, or add it manually.',
      );
    }
    try {
      return await _api.post<ReceiptExtraction>(
        '/v1/ai/parse-receipt',
        body: {'ocr_text': text.length > 8000 ? text.substring(0, 8000) : text},
        parse: (json) => parseDataEnvelope(json, ReceiptExtraction.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<SmsExtraction> parseSms(String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      throw const ValidationFailure('Paste a bank message first');
    }
    if (value.length > 4000) {
      throw const ValidationFailure(
        'That message is too long. Paste a single bank alert.',
      );
    }
    try {
      return await _api.post<SmsExtraction>(
        '/v1/ai/parse-sms',
        body: {'text': value},
        parse: (json) => parseDataEnvelope(json, SmsExtraction.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<QuickTextExtraction> parseQuickText(String text) async {
    final value = text.trim();
    if (value.isEmpty) {
      throw const ValidationFailure(
        'Type something like "Coffee 450 at Starbucks"',
      );
    }
    if (value.length > 2000) {
      throw const ValidationFailure(
        'That note is too long. Keep it to one short sentence.',
      );
    }
    try {
      return await _api.post<QuickTextExtraction>(
        '/v1/ai/parse-text',
        body: {'text': value},
        parse: (json) => parseDataEnvelope(json, QuickTextExtraction.fromJson),
      );
    } catch (e) {
      throw mapException(e);
    }
  }

  Future<String?> saveReviewed(AiReviewSave input) async {
    if (input.amount <= 0) {
      throw const ValidationFailure('Amount must be greater than zero');
    }
    try {
      return await _api.post<String?>(
        '/v1/ai/save-reviewed',
        body: input.toJson(),
        parse: (json) {
          final map = asMap(json);
          return asNullableString(map['category_id']);
        },
      );
    } catch (e) {
      throw mapException(e);
    }
  }
}
