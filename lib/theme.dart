import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF6C3CE1);       // electric purple
  static const Color accent = Color(0xFFFFD600);        // lightning yellow
  static const Color background = Color(0xFF0F0F1A);    // dark navy
  static const Color surface = Color(0xFF1C1C2E);       // card surface
  static const Color surfaceLight = Color(0xFF2A2A3E);  // lighter surface
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color success = Color(0xFF4CAF50);
  static const Color divider = Color(0xFF2E2E45);

  // Type scale — prefer these over ad-hoc font sizes so text stays consistent
  // across screens (see BACKLOG #7). Display for screen/section heroes, heading
  // for sheet titles, title for card titles, body for primary text, secondary
  // for supporting text, caption for timestamps/labels. (Tiny 10–11 micro
  // labels — badges, calendar day-of-month — and the 40px login hero are
  // deliberate one-offs and stay as-is.)
  static const double fsDisplay = 20;
  static const double fsHeading = 18;
  static const double fsTitle = 16;
  static const double fsBody = 14;
  static const double fsSecondary = 13;
  static const double fsCaption = 12;

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primary,
      secondary: accent,
      surface: surface,
      background: background,
      onPrimary: Colors.white,
      onSecondary: Colors.black,
      onSurface: textPrimary,
    ),
    scaffoldBackgroundColor: background,
    cardColor: surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: AppTheme.fsDisplay,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: textSecondary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fsBody),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceLight,
      labelStyle: const TextStyle(color: textPrimary, fontSize: AppTheme.fsCaption),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerColor: divider,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
    ),
  );
}

class AppConstants {
  static const String appName = 'RacePals';
  static const String appVersion = '1.0.0';

  // Privacy policy — hosted free on GitHub Pages (docs/privacy.html on master).
  static const String privacyPolicyUrl =
      'https://maldonadocintia-code.github.io/racepal/privacy.html';

  // Firestore collections
  static const String usersCol = 'users';
  static const String racesCol = 'races';
  static const String reviewsCol = 'reviews';
  static const String attendancesCol = 'attendances';
  static const String followsCol = 'follows'; // legacy — read only, for migration
  static const String followRequestsCol = 'follow_requests'; // legacy
  static const String palsCol = 'pals';
  static const String palRequestsCol = 'pal_requests';
  static const String activitiesCol = 'activities';

  // Race types
  static const List<String> raceTypes = [
    'parkrun',
    '5K',
    '10K',
    'Half Marathon',
    'Marathon',
    'Ultra',
    'Triathlon',
    'Obstacle',
    'Trail',
    'Other',
  ];

  // UK regions
  static const List<String> ukRegions = [
    'East Midlands',
    'East of England',
    'London',
    'North East',
    'North West',
    'Northern Ireland',
    'Scotland',
    'South East',
    'South West',
    'Wales',
    'West Midlands',
    'Yorkshire & Humber',
  ];
}
