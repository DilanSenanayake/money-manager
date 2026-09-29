import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_secure_store.dart';

/// Version stored when someone accepts Terms and the Privacy Policy.
const consentVersion = '2026-09-29';

class ConsentRecord {
  const ConsentRecord({required this.version, required this.acceptedAt});

  final String version;
  final String acceptedAt;

  bool get isCurrent => version == consentVersion && acceptedAt.isNotEmpty;
}

final consentAcceptedProvider = StateProvider<bool>((ref) => false);

class ConsentStore {
  static const _versionKey = 'consent_version';
  static const _acceptedAtKey = 'consent_accepted_at';

  Future<ConsentRecord?> read() async {
    final version = await AppSecureStore.read(_versionKey);
    final acceptedAt = await AppSecureStore.read(_acceptedAtKey);
    if (version == null || acceptedAt == null) return null;
    return ConsentRecord(version: version, acceptedAt: acceptedAt);
  }

  Future<bool> isCurrent() async {
    final record = await read();
    return record?.isCurrent ?? false;
  }

  Future<ConsentRecord> accept() async {
    final record = ConsentRecord(
      version: consentVersion,
      acceptedAt: DateTime.now().toUtc().toIso8601String(),
    );
    await AppSecureStore.write(_versionKey, record.version);
    await AppSecureStore.write(_acceptedAtKey, record.acceptedAt);
    return record;
  }
}
