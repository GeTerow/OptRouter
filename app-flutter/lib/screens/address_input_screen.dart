import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_routes.dart';
import '../domain/address_rules.dart';
import '../domain/app_failure.dart';
import '../domain/route_draft.dart';
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

class AddressInputScreen extends StatefulWidget {
  const AddressInputScreen({super.key});

  @override
  State<AddressInputScreen> createState() => _AddressInputScreenState();
}

class _AddressInputScreenState extends State<AddressInputScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _imagePicker = ImagePicker();

  final _stopInputs = <_StopInput>[];
  var _initializedFromStore = false;
  String? _loadingText;

  bool get _isLoading => _loadingText != null;

  bool get _canProceed {
    final draft = _buildDraft();
    return draft.origin.isNotEmpty && draft.destination.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _originController.addListener(_refresh);
    _destinationController.addListener(_refresh);
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    for (final stop in _stopInputs) {
      stop.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initializedFromStore) return;

    _initializedFromStore = true;
    _setRouteFromAddresses(context.read<AppState>().addresses);
    _applySavedDefaultsIfEmpty();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _setRouteFromAddresses(List<String> addresses) {
    final normalized = AddressRules.normalize(addresses);
    _originController.text = normalized.isNotEmpty ? normalized.first : '';
    _destinationController.text = normalized.length > 1 ? normalized.last : '';

    for (final stop in _stopInputs) {
      stop.dispose();
    }
    _stopInputs
      ..clear()
      ..addAll(
        normalized.length > 2
            ? normalized.sublist(1, normalized.length - 1).map(_createStopInput)
            : const <_StopInput>[],
      );
  }

  _StopInput _createStopInput(String value) {
    final stop = _StopInput(value);
    stop.controller.addListener(_refresh);
    return stop;
  }

  RouteDraft _buildDraft() {
    final origin = _originController.text.trim();
    final destination = _destinationController.text.trim();
    final stops = _stopInputs
        .map((stop) => stop.controller.text.trim())
        .where((address) => address.isNotEmpty)
        .toList();

    return RouteDraft(
      origin: origin,
      destination: destination,
      stops: stops,
    );
  }

  Future<void> _applySavedDefaultsIfEmpty() async {
    if (_originController.text.trim().isNotEmpty ||
        _destinationController.text.trim().isNotEmpty) {
      return;
    }

    final settings = await RouteDraftService().getSettings();
    if (!mounted || !settings.hasDefaults) return;

    setState(() {
      _originController.text = settings.defaultOrigin;
      _destinationController.text = settings.defaultDestination;
    });
  }

  Future<void> _handleOptimize() async {
    final draft = _buildDraft();

    if (draft.origin.isEmpty || draft.destination.isEmpty) {
      await showAppAlert(
        context,
        title: 'Atenção',
        message: 'Informe o ponto de partida e o ponto de chegada.',
      );
      return;
    }

    try {
      final appState = context.read<AppState>();
      setState(() => _loadingText = 'Otimizando rota...');
      await appState.saveRouteDraft(draft);
      await appState.optimizeRoute(draft.orderedAddresses);
      if (!mounted) return;

      setState(() => _loadingText = null);
      Navigator.of(context).pushNamed(AppRoutes.result);
    } on AppFailure catch (error) {
      if (!mounted) return;
      setState(() => _loadingText = null);
      await showAppAlert(context, title: 'Erro', message: error.userMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadingText = null);
      await showAppAlert(
        context,
        title: 'Erro ao salvar rota',
        message: error.toString(),
      );
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService().signOut();
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (_) => false,
    );
  }

  void _handleAddStop([String value = '']) {
    setState(() {
      _stopInputs.add(_createStopInput(value));
    });
  }

  void _handleRemoveStop(int index) {
    setState(() {
      _stopInputs.removeAt(index).dispose();
    });
  }

  void _handleSetDestinationFromStop(int index) {
    final currentDestination = _destinationController.text.trim();
    final newDestination = _stopInputs[index].controller.text.trim();
    if (newDestination.isEmpty) return;

    setState(() {
      _stopInputs.removeAt(index).dispose();
      if (currentDestination.isNotEmpty) {
        _stopInputs.add(_createStopInput(currentDestination));
      }
      _destinationController.text = newDestination;
    });
  }

  void _handleReorderStops(int oldIndex, int newIndex) {
    setState(() {
      final targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final stop = _stopInputs.removeAt(oldIndex);
      _stopInputs.insert(targetIndex, stop);
    });
  }

  Future<void> _handleScanFromCamera() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (image == null) return;

    await _processImages([image]);
  }

  Future<void> _handlePickImages() async {
    final images = await _imagePicker.pickMultiImage(imageQuality: 80);
    if (images.isEmpty) return;

    await _processImages(images);
  }

  Future<void> _processImages(List<XFile> images) async {
    final extracted = <String>[];

    try {
      setState(() {
        _loadingText = images.length == 1
            ? 'Lendo imagem...'
            : 'Lendo ${images.length} imagens...';
      });

      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        final found =
            await context.read<AppState>().extractAddressesFromImageBytes(
                  await image.readAsBytes(),
                  filename: image.name,
                );
        extracted.addAll(found);
      }

      if (!mounted) return;
      final addedCount = _appendUniqueStops(extracted);
      setState(() => _loadingText = null);

      if (addedCount == 0) {
        await showAppAlert(
          context,
          title: 'Aviso',
          message: 'Não encontramos endereços novos nas imagens.',
        );
        return;
      }

      await showAppAlert(
        context,
        title: 'Sucesso',
        message: '$addedCount endereço(s) adicionados às paradas.',
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

  int _appendUniqueStops(Iterable<String> addresses) {
    final current = AddressRules.normalize(_buildDraft().orderedAddresses);
    final merged = AddressRules.mergeUnique(current, addresses);
    final incoming = merged.skip(current.length).toList();
    if (incoming.isEmpty) return 0;

    setState(() {
      for (final address in incoming) {
        _stopInputs.add(_createStopInput(address));
      }
    });
    return incoming.length;
  }

  Future<void> _handlePasteList() async {
    final pasted = await showDialog<List<String>>(
      context: context,
      builder: (context) => const _PasteAddressesDialog(),
    );
    if (pasted == null || pasted.isEmpty || !mounted) return;

    final addedCount = _appendUniqueStops(pasted);
    if (addedCount == 0) {
      await showAppAlert(
        context,
        title: 'Aviso',
        message: 'A lista não tinha endereços novos.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _buildDraft();
    final stopCount = draft.stops.length;

    return Stack(
      children: [
        AppLayout(
          title: 'Novo Roteiro',
          onBack: () => Navigator.of(context).pop(),
          trailing: IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            color: AppColors.textMuted,
            onPressed: _handleSignOut,
          ),
          footer: AppButton(
            label: 'Otimizar rota',
            onPressed: _canProceed && !_isLoading ? _handleOptimize : null,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppCardTitle('Rota'),
                      const SizedBox(height: 8),
                      const AppHelperText(
                        'Monte a rota em blocos. A origem e a chegada ficam fixas; arraste as paradas para ajustar a ordem.',
                      ),
                      const SizedBox(height: 16),
                      _RouteAddressField(
                        controller: _originController,
                        label: 'Ponto de partida',
                        hint: 'Ex: Rua inicial, cidade',
                        icon: Icons.flag_outlined,
                        accentColor: AppColors.primary,
                      ),
                      const SizedBox(height: 14),
                      _buildStopsSection(stopCount),
                      const SizedBox(height: 14),
                      _RouteAddressField(
                        controller: _destinationController,
                        label: 'Ponto de chegada',
                        hint: 'Ex: destino final da rota',
                        icon: Icons.location_on_outlined,
                        accentColor: AppColors.destination,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppCardTitle('Importar endereços'),
                      const SizedBox(height: 8),
                      const AppHelperText(
                        'Imagens e listas coladas entram como paradas. Depois você pode arrastar, editar ou transformar uma parada em chegada.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppButton(
                              label: 'Câmera',
                              icon: Icons.photo_camera_outlined,
                              variant: AppButtonVariant.secondary,
                              onPressed:
                                  _isLoading ? null : _handleScanFromCamera,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppButton(
                              label: 'Imagens',
                              icon: Icons.photo_library_outlined,
                              variant: AppButtonVariant.secondary,
                              onPressed: _isLoading ? null : _handlePickImages,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'Colar lista de endereços',
                        icon: Icons.content_paste_outlined,
                        variant: AppButtonVariant.secondary,
                        onPressed: _isLoading ? null : _handlePasteList,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_loadingText != null) LoadingOverlay(text: _loadingText!),
      ],
    );
  }

  Widget _buildStopsSection(int stopCount) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.route_outlined,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$stopCount parada(s)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : () => _handleAddStop(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (_stopInputs.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: _EmptyStopsHint(),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: _stopInputs.length,
              onReorder: _handleReorderStops,
              itemBuilder: (context, index) {
                final stop = _stopInputs[index];
                return _StopEditor(
                  key: ValueKey(stop.id),
                  index: index,
                  controller: stop.controller,
                  onRemove: () => _handleRemoveStop(index),
                  onSetDestination: () => _handleSetDestinationFromStop(index),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StopInput {
  _StopInput(String value)
      : id = _nextId++,
        controller = TextEditingController(text: value);

  static var _nextId = 0;

  final int id;
  final TextEditingController controller;

  void dispose() {
    controller.dispose();
  }
}

class _RouteAddressField extends StatelessWidget {
  const _RouteAddressField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.accentColor,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 19, color: accentColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          textInputAction: TextInputAction.next,
          decoration: appInputDecoration(hint),
        ),
      ],
    );
  }
}

class _StopEditor extends StatelessWidget {
  const _StopEditor({
    required this.index,
    required this.controller,
    required this.onRemove,
    required this.onSetDestination,
    super.key,
  });

  final int index;
  final TextEditingController controller;
  final VoidCallback onRemove;
  final VoidCallback onSetDestination;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12, index == 0 ? 0 : 8, 12, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const SizedBox(
                  width: 36,
                  height: 48,
                  child: Icon(
                    Icons.drag_handle,
                    color: AppColors.textSubtle,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  decoration: appInputDecoration('Endereço da parada'),
                ),
              ),
              IconButton(
                tooltip: 'Definir como chegada',
                onPressed: onSetDestination,
                icon: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.destination,
                ),
              ),
              IconButton(
                tooltip: 'Remover parada',
                onPressed: onRemove,
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyStopsHint extends StatelessWidget {
  const _EmptyStopsHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
          style: BorderStyle.solid,
        ),
      ),
      child: const Text(
        'Nenhuma parada adicionada.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSubtle,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PasteAddressesDialog extends StatefulWidget {
  const _PasteAddressesDialog();

  @override
  State<_PasteAddressesDialog> createState() => _PasteAddressesDialogState();
}

class _PasteAddressesDialogState extends State<_PasteAddressesDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Colar endereços'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 5,
        maxLines: 8,
        textAlignVertical: TextAlignVertical.top,
        decoration: appInputDecoration(
          'Avenida Paulista 1000, São Paulo\nPraça da Sé, São Paulo',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final parsed = AddressRules.parseLines(_controller.text);
            Navigator.of(context).pop(parsed);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
