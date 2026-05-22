import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../domain/address_rules.dart';
import '../domain/app_failure.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_alerts.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_form_field.dart';
import '../widgets/app_layout.dart';
import '../widgets/app_text.dart';
import '../widgets/loading_overlay.dart';

class AddressInputScreen extends StatefulWidget {
  const AddressInputScreen({super.key});

  @override
  State<AddressInputScreen> createState() => _AddressInputScreenState();
}

class _AddressInputScreenState extends State<AddressInputScreen> {
  static const _maxLines = 8;

  final _addressesController = TextEditingController();
  final _startController = TextEditingController();
  final _imagePicker = ImagePicker();

  bool _initializedFromStore = false;
  bool _updatingControllers = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _addressesController.addListener(_refresh);
    _startController.addListener(_refresh);
  }

  @override
  void dispose() {
    _addressesController.dispose();
    _startController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromStore) return;

    _initializedFromStore = true;
    _setControllersFromAddresses(context.read<AppState>().addresses);
  }

  void _refresh() {
    if (_updatingControllers) return;
    if (mounted) setState(() {});
  }

  void _setControllersFromAddresses(List<String> addresses) {
    _updatingControllers = true;
    _addressesController.text = addresses.join('\n');
    _startController.text = addresses.isNotEmpty ? addresses.first : '';
    _updatingControllers = false;
  }

  List<String> _parseAddressText() {
    return AddressRules.parseLines(_addressesController.text);
  }

  int get _totalLines => _parseAddressText().length;

  bool get _canProceed {
    final all = AddressRules.buildRouteAddresses(
      addressesText: _addressesController.text,
      startAddress: _startController.text,
    );
    return all.length >= 2;
  }

  Future<void> _handleNext() async {
    final all = AddressRules.buildRouteAddresses(
      addressesText: _addressesController.text,
      startAddress: _startController.text,
    );

    if (all.length < 2) {
      showAppAlert(
        context,
        title: 'Atenção',
        message: 'Digite pelo menos 2 endereços para continuar.',
      );
      return;
    }

    context.read<AppState>().setAddresses(all);
    await Navigator.of(context).pushNamed(AppRoutes.confirm);
    if (!mounted) return;

    _setControllersFromAddresses(context.read<AppState>().addresses);
    setState(() {});
  }

  Future<void> _handleSignOut() async {
    await AuthService().signOut();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  Future<void> _handleScanFromCamera() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image == null) return;
      if (!mounted) return;

      final currentAddresses = _parseAddressText();
      final currentStart = _startController.text.trim();

      setState(() => _loading = true);
      final extracted = await context.read<AppState>().scanImageBytes(
            await image.readAsBytes(),
            filename: image.name,
            baseAddresses: currentAddresses,
          );

      if (!mounted) return;

      if (extracted.isEmpty) {
        setState(() => _loading = false);
        await showAppAlert(
          context,
          title: 'Aviso',
          message: 'Não encontramos endereços na imagem.',
        );
        return;
      }

      _setControllersAfterScan(
        context.read<AppState>().addresses,
        currentStart: currentStart,
      );
      setState(() => _loading = false);

      await showAppAlert(
        context,
        title: 'Sucesso',
        message:
            '${extracted.length} endereço(s) encontrados a partir da imagem.',
      );
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showAppAlert(context, title: 'Erro', message: error.userMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      await showAppAlert(context, title: 'Erro', message: error.toString());
    }
  }

  void _setControllersAfterScan(
    List<String> addresses, {
    required String currentStart,
  }) {
    _updatingControllers = true;
    _addressesController.text = addresses.join('\n');
    _startController.text = currentStart.isNotEmpty
        ? currentStart
        : addresses.isNotEmpty
            ? addresses.first
            : '';
    _updatingControllers = false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AppLayout(
          title: 'Novo Roteiro',
          trailing: IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            color: AppColors.textMuted,
            onPressed: _handleSignOut,
          ),
          footer: AppButton(
            label: 'Avançar',
            onPressed: _canProceed ? _handleNext : null,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppCardTitle('Endereços'),
                      const SizedBox(height: 8),
                      const AppHelperText(
                        'Cole ou digite um por linha. Você também pode usar '
                        'a câmera para escanear uma etiqueta/nota fiscal.',
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _addressesController,
                        minLines: _maxLines,
                        maxLines: _maxLines,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: appInputDecoration(
                          'Avenida Paulista 1000, São Paulo\n'
                          'Praça da Sé, São Paulo\n'
                          'Rua Oscar Freire 200, São Paulo',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$_totalLines linha(s)',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Mantenha um endereço por linha',
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.textSubtle,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: 'Escanear com a câmera',
                        icon: Icons.photo_camera_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: _loading ? null : _handleScanFromCamera,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppCardTitle('Endereço de Partida (opcional)'),
                      const SizedBox(height: 8),
                      const AppHelperText(
                        'Se vazio, usamos o primeiro endereço da lista.',
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _startController,
                        decoration: appInputDecoration(
                          'Usar primeiro endereço ou localização atual',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const LoadingOverlay(text: 'Lendo endereços da imagem...'),
      ],
    );
  }
}
