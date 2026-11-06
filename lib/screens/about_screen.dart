import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../theme.dart';
import '../ui/robot_game.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.watch<LocaleProvider>();
    return Center(
      child: SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const RobotMosqueGame(width: 300),
          const SizedBox(height: 24),
          Text(
            'Solat Malaysia',
            style: Theme.of(context).textTheme.displayMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snapshot) {
              final versionStr = snapshot.hasData ? 'v${snapshot.data!.version}' : '';
              return Text(
                versionStr,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.petronasYellow,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://www.research.maizzat.my/downloads/solat_malaysia_download.html');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: Text(
              l.t('about.checkUpdate'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.petronasGreen : AppTheme.petronasBlue,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.t('about.developedBy'),
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Assoc. Prof. Ts. Dr. Muhammad Aizzat Zakaria',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final url = Uri.parse('https://www.maizzat.my');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            child: Text(
              l.t('about.visit'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark ? AppTheme.petronasGreen : AppTheme.petronasBlue,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'maizzat2@gmail.com',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.petronasGreen : AppTheme.petronasBlue,
                ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  l.t('about.disclaimerTitle'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  l.t('about.disclaimer'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  l.t('about.data'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
