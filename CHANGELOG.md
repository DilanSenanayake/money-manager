# Changelog

## 1.0.0+5 — first Play release

- Release builds require a private upload key. The debug keystore is not used. Enroll in Play App Signing.
- Session tokens are stored in Keystore-backed secure storage. Android backup of app data is disabled.
- Release builds accept only HTTPS API and Supabase URLs. Cleartext is blocked outside debug builds.
- The recents screen does not show app contents.
- Optional app lock: PIN, with biometric unlock when the device has it. A failed or timed-out prompt stays locked.
- Receipt photos use the system picker. Broad photo and legacy storage permissions are not requested.
- Public account-deletion page, in-app Privacy, Terms, financial disclaimer, and open-source licenses.
- First launch records the Terms and Privacy consent version and time.
- Amounts sent to the API are decimal strings. Transactions can be exported as CSV or JSON.

Personal Play Console accounts created after 13 November 2023 need a closed test with 12 testers opted in for 14 consecutive days before production access.
