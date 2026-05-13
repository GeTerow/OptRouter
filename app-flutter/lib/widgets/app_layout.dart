import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppLayout extends StatelessWidget {
  const AppLayout({
    required this.title,
    required this.child,
    this.onBack,
    this.footer,
    super.key,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                child: Column(
                  children: [
                    _AppHeader(title: title, onBack: onBack),
                    Expanded(child: child),
                  ],
                ),
              ),
            ),
            if (footer != null)
              SafeArea(
                top: false,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenHorizontal,
                    AppSpacing.footerVertical,
                    AppSpacing.screenHorizontal,
                    AppSpacing.footerVertical,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.background,
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: footer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader({required this.title, this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: onBack == null
                ? null
                : IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.textMuted,
                    onPressed: onBack,
                  ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
