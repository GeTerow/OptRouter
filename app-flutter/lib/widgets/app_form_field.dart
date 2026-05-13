import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

InputDecoration appInputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSubtle),
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.all(14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.button),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.button),
      borderSide: const BorderSide(color: AppColors.primary),
    ),
  );
}
