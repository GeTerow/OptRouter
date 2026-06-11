import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/app_failure.dart';
import '../domain/user_settings.dart';
import '../services/auth_service.dart';
import '../services/route_draft_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_alerts.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_layout.dart';
import '../widgets/app_text.dart';
import '../widgets/loading_overlay.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = RouteDraftService();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();

  String? _loadingText;

  bool get _isLoading => _loadingText != null;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _service.getSettings();
      if (!mounted) return;
      setState(() {
        _originController.text = settings.defaultOrigin;
        _destinationController.text = settings.defaultDestination;
      });
    } catch (_) {
      if (!mounted) return;
      await showAppAlert(
        context,
        title: 'Erro',
        message: 'Não foi possível carregar as configurações.',
      );
    }
  }

  Future<void> _saveSettings() async {
    try {
      setState(() => _loadingText = 'Salvando configurações...');
      await _service.saveSettings(
        UserSettings(
          defaultOrigin: _originController.text,
          defaultDestination: _destinationController.text,
        ),
      );
      if (!mounted) return;
      setState(() => _loadingText = null);
      await showAppAlert(
        context,
        title: 'Pronto',
        message: 'Configurações salvas.',
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _loadingText = null);
      await showAppAlert(context, title: 'Erro', message: error.userMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingText = null);
      await showAppAlert(context, title: 'Erro', message: error.toString());
    }
  }

  Future<void> _deleteSavedRoutes() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar rotas salvas?'),
        content: const Text(
          'Isso remove as rotas salvas no Firebase para esta conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      setState(() => _loadingText = 'Apagando rotas...');
      await _service.deleteSavedRoutes();
      if (!mounted) return;
      context.read<AppState>().clearCurrentDraft();
      setState(() => _loadingText = null);
      await showAppAlert(
        context,
        title: 'Pronto',
        message: 'Rotas salvas apagadas.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingText = null);
      await showAppAlert(context, title: 'Erro', message: error.toString());
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Stack(
      children: [
        AppLayout(
          title: 'Configurações',
          onBack: () => Navigator.of(context).pop(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCardTitle('Conta'),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Nome',
                      value: user?.displayName?.trim().isNotEmpty == true
                          ? user!.displayName!.trim()
                          : 'Sem nome',
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      label: 'E-mail',
                      value: user?.email ?? 'Sem e-mail',
                    ),
                    const SizedBox(height: 14),
                    AppButton(
                      label: 'Sair da conta',
                      icon: Icons.logout,
                      variant: AppButtonVariant.secondary,
                      onPressed: _isLoading ? null : _signOut,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCardTitle('Ponto de partida padrão'),
                    const SizedBox(height: 8),
                    const AppHelperText(
                      'Usado automaticamente ao criar uma nova rota.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _originController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: appInputDecoration('Endereço de origem'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCardTitle('Destino padrão'),
                    const SizedBox(height: 8),
                    const AppHelperText(
                      'Opcional. Útil quando muitas rotas terminam no mesmo lugar.',
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _destinationController,
                      minLines: 1,
                      maxLines: 3,
                      decoration: appInputDecoration('Endereço de destino'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCardTitle('Dados salvos'),
                    const SizedBox(height: 8),
                    const AppHelperText(
                      'Gerencie os dados de rota salvos para esta conta.',
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Apagar rotas salvas',
                      icon: Icons.delete_outline,
                      variant: AppButtonVariant.secondary,
                      onPressed: _isLoading ? null : _deleteSavedRoutes,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Salvar configurações',
                icon: Icons.save_outlined,
                onPressed: _isLoading ? null : _saveSettings,
              ),
            ],
          ),
        ),
        if (_loadingText != null) LoadingOverlay(text: _loadingText!),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textStrong,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
