import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.compact = false,
    this.centered = false,
  });

  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 42.0 : 56.0;
    final textSize = compact ? 20.0 : 28.0;

    final content = [
      Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.lightGray,
          border: Border.all(
            color: AppColors.seaGreen,
            width: 2.3,
          ),
        ),
        child: Icon(
          Icons.savings_outlined,
          color: AppColors.seaGreen,
          size: iconSize * 0.58,
        ),
      ),
      SizedBox(width: compact ? 10 : 0, height: compact ? 0 : 10),
      Text(
        'SALVA\nBOLSO',
        textAlign: compact ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          color: AppColors.indigo,
          fontSize: textSize,
          fontWeight: FontWeight.w900,
          height: 0.92,
          letterSpacing: -0.5,
        ),
      ),
    ];

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: content,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: content,
    );
  }
}