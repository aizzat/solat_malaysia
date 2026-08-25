import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.mosque,
            size: 100,
            color: AppTheme.petronasGreen,
          ),
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
          const SizedBox(height: 16),
          Text(
            'Developed by:',
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
              'Visit: www.maizzat.my',
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
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  'Disclaimer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This application is provided "as is", without warranty of any kind. '
                  'The developer is not responsible for any inaccuracies in the prayer times provided.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Data provided by e-Solat JAKIM & Aladhan API.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
