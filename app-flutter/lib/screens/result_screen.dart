import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_routes.dart';
import '../services/maps_link_builder.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_alerts.dart';
import '../widgets/app_button.dart';
import '../widgets/app_layout.dart';
import '../widgets/route_stop_tile.dart';
import '../widgets/route_summary_card.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  var _copied = false;

  Future<void> _openMaps(String mapsUrl) async {
    final uri = Uri.parse(mapsUrl);
    if (!await canLaunchUrl(uri)) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Erro',
        message: 'Não foi possível abrir o Google Maps.',
      );
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _copyLink(String mapsUrl) async {
    try {
      await Clipboard.setData(ClipboardData(text: mapsUrl));
      if (!mounted) return;
      setState(() => _copied = true);
      await Future<void>.delayed(const Duration(milliseconds: 1800));
      if (mounted) setState(() => _copied = false);
    } catch (_) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Erro',
        message: 'Não foi possível copiar o link.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = context.watch<AppState>().optimizedRoute;

    if (route == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.addressInput);
        }
      });
      return const SizedBox.shrink();
    }

    final mapsUrl = MapsLinkBuilder.googleDirectionsUrl(route);

    return AppLayout(
      title: 'Rota Otimizada',
      onBack: () => Navigator.of(context).pop(),
      footer: Row(
        children: [
          Expanded(
            child: AppButton(
              label: 'Abrir no Maps',
              icon: Icons.map_outlined,
              onPressed: () => _openMaps(mapsUrl),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AppButton(
              label: _copied ? 'Copiado!' : 'Copiar Link',
              icon: Icons.link,
              variant: AppButtonVariant.secondary,
              onPressed: () => _copyLink(mapsUrl),
            ),
          ),
        ],
      ),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 140),
        children: [
          RouteSummaryCard(route: route),
          const SizedBox(height: 16),
          const Text(
            'Endereços',
            style: TextStyle(
              color: AppColors.textStrong,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < route.stops.length; i++) ...[
            RouteStopTile(stop: route.stops[i], index: i),
            if (i < route.stops.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
