import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppShadows {
  AppShadows._();

  static List<BoxShadow> get card => [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 4, offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: AppColors.primary.withOpacity(0.07),
      blurRadius: 16, offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get elevated => [
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 12, offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primary.withOpacity(0.08),
      blurRadius: 40, offset: const Offset(0, 16),
    ),
  ];

  static List<BoxShadow> get navy => [
    BoxShadow(
      color: AppColors.primary.withOpacity(0.28),
      blurRadius: 20, offset: const Offset(0, 6),
    ),
  ];

  static List<BoxShadow> get gold => [
    BoxShadow(
      color: AppColors.gold.withOpacity(0.32),
      blurRadius: 14, offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get teal => [
    BoxShadow(
      color: AppColors.teal.withOpacity(0.28),
      blurRadius: 14, offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 3, offset: const Offset(0, 1),
    ),
  ];
}
