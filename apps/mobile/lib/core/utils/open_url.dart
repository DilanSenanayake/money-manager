import 'package:url_launcher/url_launcher.dart';

Future<bool> openExternalUrl(String url) {
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
