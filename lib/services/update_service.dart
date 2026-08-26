import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  static const String _githubApiUrl =
      'https://api.github.com/repos/aizzat/solat_malaysia/releases/latest';

  static Future<bool> checkForUpdate() async {
    try {
      final response = await http.get(Uri.parse(_githubApiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String tag = data['tag_name'] ?? '';
        if (tag.isEmpty) return false;

        final String latestVersion = tag.replaceAll('v', '').split('+')[0];
        
        final packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version.split('+')[0];

        return _isVersionGreaterThan(latestVersion, currentVersion);
      }
    } catch (e) {
      print('Error checking for update: $e');
    }
    return false;
  }

  static bool _isVersionGreaterThan(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < latestParts.length; i++) {
        if (i >= currentParts.length) return true;
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }
    } catch (_) {
      return latest.compareTo(current) > 0;
    }
    return false;
  }
}
