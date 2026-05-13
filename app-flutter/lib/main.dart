import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'screens/address_input_screen.dart';
import 'screens/confirm_screen.dart';
import 'screens/result_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RotaOtimizadaApp());
}

class RotaOtimizadaApp extends StatelessWidget {
  const RotaOtimizadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Rota Otimizada',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        initialRoute: AppRoutes.addressInput,
        routes: {
          AppRoutes.addressInput: (_) => const AddressInputScreen(),
          AppRoutes.confirm: (_) => const ConfirmScreen(),
          AppRoutes.result: (_) => const ResultScreen(),
        },
      ),
    );
  }
}
