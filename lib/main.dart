import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'firebase_options.dart';
import 'services/app_provider.dart';
import 'services/theme_controller.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Compact relative timestamps for the feed ("2h", "1d") instead of the verbose default.
  timeago.setLocaleMessages('en_short', timeago.EnShortMessages());
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  final themeController = ThemeController();
  await themeController.load();
  runApp(RacePalApp(themeController: themeController));
}

class RacePalApp extends StatelessWidget {
  final ThemeController themeController;
  const RacePalApp({super.key, required this.themeController});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
        ChangeNotifierProvider.value(value: themeController),
      ],
      child: Consumer<ThemeController>(
        builder: (_, theme, __) => MaterialApp(
          title: AppConstants.appName,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.mode,
          debugShowCheckedModeBanner: false,
          home: const _AuthGate(),
        ),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.isLoggedIn) return const HomeShell();
    return const LoginScreen();
  }
}
