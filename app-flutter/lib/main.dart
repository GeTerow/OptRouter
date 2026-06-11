import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'app_routes.dart';
import 'firebase_options.dart';
import 'screens/address_input_screen.dart';
import 'screens/auth_gate.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/result_screen.dart';
import 'screens/saved_routes_screen.dart';
import 'screens/settings_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    RotaOtimizadaApp(
      firebaseInitialization: _initializeFirebase(),
    ),
  );
}

Future<FirebaseApp> _initializeFirebase() async {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

class RotaOtimizadaApp extends StatelessWidget {
  const RotaOtimizadaApp({
    required this.firebaseInitialization,
    super.key,
  });

  final Future<FirebaseApp> firebaseInitialization;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Rota Otimizada',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: FirebaseBootstrap(initialization: firebaseInitialization),
        routes: {
          AppRoutes.login: (_) => const AuthScreen(),
          AppRoutes.home: (_) => const HomeScreen(),
          AppRoutes.addressInput: (_) => const AddressInputScreen(),
          AppRoutes.savedRoutes: (_) => const SavedRoutesScreen(),
          AppRoutes.settings: (_) => const SettingsScreen(),
          AppRoutes.result: (_) => const ResultScreen(),
        },
      ),
    );
  }
}

class FirebaseBootstrap extends StatelessWidget {
  const FirebaseBootstrap({
    required this.initialization,
    super.key,
  });

  final Future<FirebaseApp> initialization;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const _FirebaseSetupErrorScreen();
        }

        return const AuthGate();
      },
    );
  }
}

class _FirebaseSetupErrorScreen extends StatelessWidget {
  const _FirebaseSetupErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Firebase ainda não configurado. Rode o FlutterFire CLI e conecte '
              'o app ao seu projeto Firebase antes de iniciar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
