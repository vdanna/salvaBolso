import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/brand_logo.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(centered: true),
              SizedBox(height: 28),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Carregando sua sessão...'),
            ],
          ),
        ),
      ),
    );
  }
}