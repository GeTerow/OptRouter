import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppCardTitle extends StatelessWidget {
  const AppCardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textStrong,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class AppHelperText extends StatelessWidget {
  const AppHelperText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 13,
        height: 1.25,
      ),
    );
  }
}
