import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AddressTile extends StatelessWidget {
  const AddressTile({
    required this.address,
    required this.isStart,
    this.isEnd = false,
    this.onDelete,
    this.onSetDestination,
    super.key,
  });

  final String address;
  final bool isStart;
  final bool isEnd;
  final VoidCallback? onDelete;

  /// Shown on intermediate addresses — makes this address the destination.
  final VoidCallback? onSetDestination;

  Color get _accentColor {
    if (isStart) return AppColors.primary;
    if (isEnd) return AppColors.destination;
    return AppColors.textSubtle;
  }

  IconData get _icon {
    if (isStart) return Icons.flag;
    if (isEnd) return Icons.location_on;
    return Icons.menu;
  }

  String? get _label {
    if (isStart) return 'Ponto de Partida';
    if (isEnd) return 'Ponto de Chegada';
    return null;
  }

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
            if (isStart || isEnd)
              SizedBox(
                width: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: _accentColor),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      _icon,
                      size: 22,
                      color: _accentColor,
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
                          if (_label != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                _label!,
                                style: TextStyle(
                                  color: _accentColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onSetDestination != null)
                      IconButton(
                        tooltip: 'Definir como ponto de chegada',
                        onPressed: onSetDestination,
                        icon: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.destination,
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
