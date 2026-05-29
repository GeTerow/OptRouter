import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../domain/app_failure.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
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
    if (index == 0 || index == _addressList.length - 1) return;
    final updated = [
      for (var i = 0; i < _addressList.length; i++)
        if (i != index) _addressList[i],
    ];

    setState(() {
      _addressList = updated;
    });
    context.read<AppState>().setAddresses(updated);
  }

  /// Moves the address at [index] to the last position (destination).
  void _handleSetDestination(int index) {
    if (index == 0 || index == _addressList.length - 1) return;

    final address = _addressList[index];
    final updated = [
      for (var i = 0; i < _addressList.length; i++)
        if (i != index) _addressList[i],
    ];
    // Insert before old destination so new destination is at the end.
    updated.add(address);

    setState(() {
      _addressList = updated;
    });
    context.read<AppState>().setAddresses(updated);
  }

  /// Opens a dialog to add a brand-new address as the destination.
  Future<void> _handleAddNewDestination() async {
    final newAddress = await showDialog<String>(
      context: context,
      builder: (context) => const _NewDestinationDialog(),
    );

    if (newAddress == null || newAddress.isEmpty) return;
    if (!mounted) return;

    setState(() {
      _addressList = [..._addressList, newAddress];
    });
    context.read<AppState>().setAddresses(_addressList);
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
      if (kDebugMode) {
        debugPrint('[ConfirmScreen] ${error.kind}: ${error.toString()}');
      }

      await showAppAlert(
        context,
        title: error.kind == AppFailureKind.addressNotFound
            ? 'Endereço não encontrado'
            : 'Erro ao otimizar rota',
        message: _errorMessage(error),
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

  String _errorMessage(AppFailure error) {
    if (!kDebugMode || error.technicalMessage == null) {
      return error.userMessage;
    }

    return '${error.userMessage}\n\nDetalhe técnico: ${error.technicalMessage}';
  }

  @override
  Widget build(BuildContext context) {
    // Total items: addresses + 1 for the "Novo endereço" button after destination.
    final itemCount = _addressList.length + 1;

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
            itemCount: itemCount,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              // After all addresses, show the "Novo endereço" button.
              if (index == _addressList.length) {
                return _buildNewDestinationButton();
              }

              final address = _addressList[index];
              final isStart = index == 0;
              final isEnd = index == _addressList.length - 1;
              final isIntermediate = !isStart && !isEnd;

              return AddressTile(
                address: address,
                isStart: isStart,
                isEnd: isEnd,
                onDelete: isIntermediate ? () => _handleDelete(index) : null,
                onSetDestination:
                    isIntermediate ? () => _handleSetDestination(index) : null,
              );
            },
          ),
        ),
        if (_loading) const LoadingOverlay(text: 'Otimizando rota...'),
      ],
    );
  }

  Widget _buildNewDestinationButton() {
    return GestureDetector(
      onTap: _handleAddNewDestination,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.largeCard),
          border: Border.all(
            color: AppColors.destination.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 20,
              color: AppColors.destination,
            ),
            SizedBox(width: 8),
            Text(
              'Novo endereço de chegada',
              style: TextStyle(
                color: AppColors.destination,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDestinationDialog extends StatefulWidget {
  const _NewDestinationDialog();

  @override
  State<_NewDestinationDialog> createState() => _NewDestinationDialogState();
}

class _NewDestinationDialogState extends State<_NewDestinationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Novo Ponto de Chegada'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          hintText: 'Digite o endereço de chegada',
          hintStyle: const TextStyle(
            color: AppColors.textSubtle,
            fontSize: 14,
          ),
          filled: true,
          fillColor: AppColors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.card),
            borderSide: const BorderSide(
              color: AppColors.destination,
              width: 2,
            ),
          ),
        ),
        maxLines: 2,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          final trimmed = value.trim();
          if (trimmed.isNotEmpty) {
            Navigator.of(context).pop(trimmed);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final trimmed = _controller.text.trim();
            if (trimmed.isNotEmpty) {
              Navigator.of(context).pop(trimmed);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.destination,
          ),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
