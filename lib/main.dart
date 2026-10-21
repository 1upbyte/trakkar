import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'models/theme_preference.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/setup_link_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  runApp(ChangeNotifierProvider.value(value: state, child: const TrakkarApp()));
  unawaited(state.bootstrap());
}

class TrakkarApp extends StatelessWidget {
  const TrakkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) => MaterialApp(
        title: 'trakkar',
        debugShowCheckedModeBanner: false,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: switch (state.themePreference) {
          ThemePreference.system => ThemeMode.system,
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
        },
        home: const _AppHome(),
        onGenerateInitialRoutes: (initialRoute) => [
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => const _AppHome(),
          ),
          if (initialRoute != '/') _setupRoute(initialRoute),
        ],
        onGenerateRoute: (settings) => _setupRoute(settings.name ?? ''),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    const seed = Color(0xFF126E68);
    final colors = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: colors,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.surface,
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHighest,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

Route<void> _setupRoute(String link) => MaterialPageRoute<void>(
  // Do not retain credentials in route names or diagnostic output.
  settings: const RouteSettings(name: '/setup'),
  builder: (_) => SetupLinkScreen(link: link),
);

class _AppHome extends StatelessWidget {
  const _AppHome();

  @override
  Widget build(BuildContext context) {
    final phase = context.watch<AppState>().phase;
    return switch (phase) {
      AppPhase.loading => const _LoadingScreen(),
      AppPhase.onboarding => const OnboardingScreen(),
      AppPhase.ready => const HomeScreen(),
    };
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(size: 72),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF126E68),
        borderRadius: BorderRadius.circular(size * .3),
      ),
      child: Icon(Icons.near_me_rounded, color: Colors.white, size: size * .5),
    );
  }
}
