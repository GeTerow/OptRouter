import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../domain/saved_route_summary.dart';
import '../services/route_draft_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_card.dart';
import '../widgets/app_layout.dart';
import '../widgets/app_text.dart';

class SavedRoutesScreen extends StatefulWidget {
  const SavedRoutesScreen({super.key});

  @override
  State<SavedRoutesScreen> createState() => _SavedRoutesScreenState();
}

class _SavedRoutesScreenState extends State<SavedRoutesScreen> {
  final _service = RouteDraftService();
  late Future<List<SavedRouteSummary>> _routesFuture;

  @override
  void initState() {
    super.initState();
    _routesFuture = _service.listRoutes();
  }

  void _openRoute(SavedRouteSummary route) {
    context.read<AppState>().loadRouteDraft(
          routeId: route.id,
          addresses: route.addressOrder,
        );
    Navigator.of(context).pushNamed(AppRoutes.addressInput);
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      title: 'Minhas rotas',
      onBack: () => Navigator.of(context).pop(),
      child: FutureBuilder<List<SavedRouteSummary>>(
        future: _routesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final routes = snapshot.data ?? const <SavedRouteSummary>[];
          if (routes.isEmpty) {
            return const Center(
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.route_outlined,
                      size: 34,
                      color: AppColors.textSubtle,
                    ),
                    SizedBox(height: 10),
                    AppCardTitle('Nenhuma rota salva'),
                    SizedBox(height: 6),
                    AppHelperText(
                      'As rotas aparecem aqui depois que você otimiza ou salva um rascunho.',
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: routes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final route = routes[index];
              return _SavedRouteTile(
                route: route,
                onTap: () => _openRoute(route),
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedRouteTile extends StatelessWidget {
  const _SavedRouteTile({
    required this.route,
    required this.onTap,
  });

  final SavedRouteSummary route;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(
                Icons.route_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${route.origin} → ${route.destination}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${route.stopCount} endereço(s)',
                      style: const TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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
      ),
    );
  }
}
