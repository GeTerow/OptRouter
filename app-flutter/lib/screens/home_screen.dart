import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_layout.dart';
import '../widgets/app_text.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    await AuthService().signOut();
    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  void _startNewRoute(BuildContext context) {
    context.read<AppState>().clearCurrentDraft();
    Navigator.of(context).pushNamed(AppRoutes.addressInput);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Central',
      trailing: IconButton(
        tooltip: 'Sair',
        icon: const Icon(Icons.logout),
        color: AppColors.textMuted,
        onPressed: () => _handleSignOut(context),
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppCardTitle('Roteiros'),
                const SizedBox(height: 8),
                const AppHelperText(
                  'Crie uma rota nova ou retome uma rota salva.',
                ),
                const SizedBox(height: 16),
                _HomeAction(
                  title: 'Otimizar nova rota',
                  subtitle: 'Montar origem, paradas e destino.',
                  icon: Icons.add_location_alt_outlined,
                  accentColor: AppColors.primary,
                  onTap: () => _startNewRoute(context),
                ),
                const SizedBox(height: 10),
                _HomeAction(
                  title: 'Minhas rotas',
                  subtitle: 'Abrir rotas salvas e rascunhos.',
                  icon: Icons.route_outlined,
                  accentColor: AppColors.destination,
                  onTap: () => Navigator.of(context).pushNamed(
                    AppRoutes.savedRoutes,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            child: _HomeAction(
              title: 'Configurações',
              subtitle: 'Conta, padrões de rota e dados salvos.',
              icon: Icons.settings_outlined,
              accentColor: AppColors.textSecondary,
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAction extends StatelessWidget {
  const _HomeAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textStrong,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSubtle,
            ),
          ],
        ),
      ),
    );
  }
}
