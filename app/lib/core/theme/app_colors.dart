import 'package:flutter/material.dart';

class AppColors {
  static const Color mint = Color(0xFFA8E6CF);
  static const Color indigo = Color(0xFF4D6583);
  static const Color seaGreen = Color(0xFF7BC6AC);
  static const Color lightGray = Color(0xFFF0F4F7);

  static const Color background = Color(0xFFF8FBFA);
  static const Color card = Color(0xFFFFFFFF);

  static const Color navy = Color(0xFF1C2F4A);
  static const Color textPrimary = Color(0xFF243447);
  static const Color textSecondary = Color(0xFF7A8798);

  static const Color border = Color(0xFFD9E3EA);
  static const Color error = Color(0xFFE56B6F);
  static const Color warning = Color(0xFFFFC857);
  static const Color success = seaGreen;

  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      mint,
      seaGreen,
    ],
  );

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFDDF8EE),
      background,
      background,
    ],
  );
}