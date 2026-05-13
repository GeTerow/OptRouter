import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AddressTile extends StatelessWidget {
  const AddressTile({
    required this.address,
    required this.isStart,
    this.onDelete,
    super.key,
  });

  final String address;
  final bool isStart;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.largeCard),
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isStart)
              const SizedBox(
                width: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.primary),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      isStart ? Icons.flag : Icons.menu,
                      size: 22,
                      color: isStart ? AppColors.primary : AppColors.textSubtle,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            address,
                            style: const TextStyle(
                              color: AppColors.textStrong,
                              fontSize: 16,
                              height: 1.35,
                            ),
                          ),
                          if (isStart)
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Text(
                                'Ponto de Partida',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onDelete != null)
                      IconButton(
                        tooltip: 'Remover endereço',
                        onPressed: onDelete,
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.textSubtle,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
