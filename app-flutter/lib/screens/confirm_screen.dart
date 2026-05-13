import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../domain/app_failure.dart';
import '../state/app_state.dart';
import '../widgets/address_tile.dart';
import '../widgets/app_alerts.dart';
import '../widgets/app_button.dart';
import '../widgets/app_layout.dart';
import '../widgets/loading_overlay.dart';

class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key});

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  var _addressList = <String>[];
  var _initialized = false;
  var _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    _initialized = true;
    _addressList = List.of(context.read<AppState>().addresses);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppState>().clearRoute();
      if (_addressList.length < 2) {
        Navigator.of(context).pushReplacementNamed(AppRoutes.addressInput);
      }
    });
  }

  void _handleDelete(int index) {
    if (index == 0) return;
    final updated = [
      for (var i = 0; i < _addressList.length; i++)
        if (i != index) _addressList[i],
    ];

    setState(() {
      _addressList = updated;
    });
    context.read<AppState>().setAddresses(updated);
  }

  Future<void> _handleOptimizeClick() async {
    if (_addressList.length < 2) {
      await showAppAlert(
        context,
        title: 'Atenção',
        message: 'Você precisa de pelo menos 2 endereços.',
      );
      return;
    }

    try {
      setState(() => _loading = true);
      context.read<AppState>().setAddresses(_addressList);
      await context.read<AppState>().optimizeRoute(_addressList);

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushNamed(AppRoutes.result);
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);

      await showAppAlert(
        context,
        title: error.kind == AppFailureKind.addressNotFound
            ? 'Endereço não encontrado'
            : 'Erro ao otimizar rota',
        message: error.userMessage,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showAppAlert(
        context,
        title: 'Erro ao otimizar rota',
        message: error.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppLayout(
          title: 'Endereços',
          onBack: () => Navigator.of(context).pop(),
          footer: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Voltar',
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: 'Otimizar Rota',
                  onPressed: _loading ? null : _handleOptimizeClick,
                ),
              ),
            ],
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 140),
            itemCount: _addressList.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final address = _addressList[index];
              final isStart = index == 0;

              return AddressTile(
                address: address,
                isStart: isStart,
                onDelete: isStart ? null : () => _handleDelete(index),
              );
            },
          ),
        ),
        if (_loading) const LoadingOverlay(text: 'Otimizando rota...'),
      ],
    );
  }
}
