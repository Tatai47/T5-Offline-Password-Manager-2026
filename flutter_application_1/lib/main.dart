import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'database/db_helper.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/pin_lock_screen.dart';
import 'utils/app_theme.dart';

/// Entry point of our Flutter Password Manager application.
void main() async {
  // Ensure that Flutter widget binding is initialized before database or platform channels
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database factory based on the active platform
  if (kIsWeb) {
    // Web (Chrome, Safari, Edge) uses WebAssembly SQLite
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    // Desktop uses FFI SQLite
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 1. Load last changed theme from local SQLite database (independent of user session)
  try {
    final localTheme = await DatabaseHelper.instance.getLocalTheme();
    applyAppTheme(localTheme);
  } catch (_) {}

  // 2. Check if an active user was remembered from the previous session
  UserModel? sessionUser;
  try {
    sessionUser = await DatabaseHelper.instance.getActiveSessionUser();
  } catch (_) {}

  // Run the root widget of the application
  runApp(PasswordManagerApp(initialUser: sessionUser));
}

/// Global notifier to switch between Light and Dark themes instantly
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.light);

/// Global helper function to apply and persist the app theme mode ('dark' or 'light') in localDB
void applyAppTheme(String? mode, {bool persist = false}) {
  if (mode == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.light;
  }
  if (persist && mode != null) {
    DatabaseHelper.instance.setLocalTheme(mode);
  }
}

/// Backward compatible alias that persists theme to localDB
void applyUserTheme(String? mode) {
  applyAppTheme(mode);
}

/// The root widget of our application.
class PasswordManagerApp extends StatelessWidget {
  final UserModel? initialUser;

  const PasswordManagerApp({super.key, this.initialUser});

  @override
  Widget build(BuildContext context) {
    // Decide which screen to show on launch:
    // 1. If user saved credentials to localDB with a 4-digit PIN -> PinLockScreen
    // 2. Otherwise (no session or no PIN set) -> LoginScreen
    Widget initialScreen;
    if (initialUser != null && initialUser!.pin != null && initialUser!.pin!.isNotEmpty) {
      initialScreen = PinLockScreen(currentUser: initialUser!);
    } else {
      initialScreen = const LoginScreen();
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'T5 Offline Password Manager',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: initialScreen,
        );
      },
    );
  }
}
