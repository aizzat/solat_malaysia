import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
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
            'developed by',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Dr. Muhammad Aizzat Bin Zakaria',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'maizzat2@gmail.com',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.petronasGreen : AppTheme.petronasBlue,
                ),
          ),
        ],
      ),
    );
  }
}
