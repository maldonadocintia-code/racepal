import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VOLT & VELOCITY DESIGN SYSTEM
// Translated to Flutter from the RacePals design doc (which was written for
// React Native). Single source of truth for colour, type, spacing and shape.
//
//  • [AppPalette]  — raw colours. Never reference directly in widgets.
//  • [AppColors]   — semantic tokens that switch with the active brightness.
//                    Use `final c = AppColors.of(context);` then `c.primary`.
//  • [AppType]     — font families + size scale.
//  • [AppSpacing] / [AppRadius] — layout tokens.
//  • [AppTheme]    — builds the light/dark [ThemeData]. Legacy static colour +
//                    `fs*` size constants are kept so screens not yet migrated to
//                    [AppColors] still compile (they render in the old palette
//                    until their conversion pass).
// ─────────────────────────────────────────────────────────────────────────────

class AppPalette {
  // Volt & Velocity core
  static const volt = Color(0xFFC4FF00); // primary accent
  static const midnight = Color(0xFF0D0E1A); // dark bg
  static const surface = Color(0xFF1C1F2E); // dark card/surface
  static const surfaceHigh = Color(0xFF252837); // dark elevated (sheets/modals)
  static const hotPink = Color(0xFFFF8AD0); // PB badges / achievements (AAA: 7.6:1 on dark surface; was #FF3CAC @ 5.0:1)
  static const cyan = Color(0xFF00D4FF); // data / stats

  // Light surfaces
  static const lightBg = Color(0xFFF2F4FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceHigh = Color(0xFFEEF0FF);
  static const lightBorder = Color(0xFFE2E5F5);

  // Semantic / shared
  static const palsTeal = Color(0xFF00BFA5);
  static const goGreen = Color(0xFF22C55E);
  static const errorRed = Color(0xFFFF4444);
  static const warningAmber = Color(0xFFF59E0B);

  // Light-mode deepened accents (AA on white)
  static const violetLink = Color(0xFF5B00C8);
  static const cyanDeep = Color(0xFF0077AA);
  static const pinkDeep = Color(0xFFA8005C); // AAA: 7.45:1 on white (was #C0006A @ 6.1:1)
  static const tealDeep = Color(0xFF00897B);
  static const oliveOnVolt = Color(0xFF3A6600);
  static const greenDeep = Color(0xFF16A34A);
  static const redDeep = Color(0xFFDC2626);

  // Neutrals
  static const white = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFF0F0F0);
  static const grey100 = Color(0xFFE8E8E8);
  static const grey300 = Color(0xFFA0A3B1);
  static const grey500 = Color(0xFF6B6E80);
  static const grey700 = Color(0xFF3A3D4D);
  static const grey900 = Color(0xFF1A1C28);
  static const black = Color(0xFF000000);

  // Volt tints
  static const voltAlpha10 = Color(0x1AC4FF00);
  static const voltAlpha20 = Color(0x33C4FF00);
  static const voltAlpha30 = Color(0x4DC4FF00);
}

/// Semantic colour tokens. Two instances ([dark] / [light]); pick the active one
/// for the current screen with [AppColors.of].
@immutable
class AppColors {
  // Backgrounds
  final Color bgPrimary, bgSurface, bgSurfaceHigh, bgInput, bgInputFocused;
  // Text
  final Color textPrimary,
      textSecondary,
      textTertiary,
      textOnVolt,
      textOnPink,
      textLink;
  // Brand accents
  final Color primary, primaryMuted, secondary, achievement, pals;
  // Borders & dividers
  final Color border, borderFocused, divider;
  // Tabs
  final Color tabActive, tabInactive, tabBadgeBg, tabBadgeText;
  // Filter chips
  final Color filterActive,
      filterActiveText,
      filterInactive,
      filterInactiveText,
      filterBorder;
  // Calendar
  final Color calToday,
      calTodayText,
      calSelected,
      calSelectedText,
      calDotMine,
      calDotPals;
  // FAB
  final Color fabBg, fabText;
  // Bottom sheet
  final Color sheetBg, sheetHandle;
  // Status
  final Color statusLive, statusError;
  // Slider
  final Color sliderTrack, sliderFill, sliderThumb;
  // Action button
  final Color actionBg, actionText;
  // Going badge
  final Color goingBg, goingText, goingBorder;
  // Pal badge
  final Color palBadgeBg, palBadgeText, palBadgeBorder;
  // Plan accent bars
  final Color planBarMine, planBarPals;
  // Notification badge
  final Color notifBg, notifText;
  // Search
  final Color searchBg,
      searchBorder,
      searchBorderFocus,
      searchIcon,
      searchText,
      searchPlaceholder;
  // Avatar fallback
  final Color avatarBg, avatarText;
  // Feed timeline
  final Color feedDotBg,
      feedDotBorder,
      feedDotIcon,
      feedLine,
      feedTimeText,
      feedSectionLabel,
      feedNameText,
      feedLinkText;

  const AppColors({
    required this.bgPrimary,
    required this.bgSurface,
    required this.bgSurfaceHigh,
    required this.bgInput,
    required this.bgInputFocused,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnVolt,
    required this.textOnPink,
    required this.textLink,
    required this.primary,
    required this.primaryMuted,
    required this.secondary,
    required this.achievement,
    required this.pals,
    required this.border,
    required this.borderFocused,
    required this.divider,
    required this.tabActive,
    required this.tabInactive,
    required this.tabBadgeBg,
    required this.tabBadgeText,
    required this.filterActive,
    required this.filterActiveText,
    required this.filterInactive,
    required this.filterInactiveText,
    required this.filterBorder,
    required this.calToday,
    required this.calTodayText,
    required this.calSelected,
    required this.calSelectedText,
    required this.calDotMine,
    required this.calDotPals,
    required this.fabBg,
    required this.fabText,
    required this.sheetBg,
    required this.sheetHandle,
    required this.statusLive,
    required this.statusError,
    required this.sliderTrack,
    required this.sliderFill,
    required this.sliderThumb,
    required this.actionBg,
    required this.actionText,
    required this.goingBg,
    required this.goingText,
    required this.goingBorder,
    required this.palBadgeBg,
    required this.palBadgeText,
    required this.palBadgeBorder,
    required this.planBarMine,
    required this.planBarPals,
    required this.notifBg,
    required this.notifText,
    required this.searchBg,
    required this.searchBorder,
    required this.searchBorderFocus,
    required this.searchIcon,
    required this.searchText,
    required this.searchPlaceholder,
    required this.avatarBg,
    required this.avatarText,
    required this.feedDotBg,
    required this.feedDotBorder,
    required this.feedDotIcon,
    required this.feedLine,
    required this.feedTimeText,
    required this.feedSectionLabel,
    required this.feedNameText,
    required this.feedLinkText,
  });

  /// The active token set for [context]'s brightness.
  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  static const AppColors dark = AppColors(
    bgPrimary: AppPalette.midnight,
    bgSurface: AppPalette.surface,
    bgSurfaceHigh: AppPalette.surfaceHigh,
    bgInput: AppPalette.surface,
    bgInputFocused: AppPalette.surfaceHigh,
    textPrimary: AppPalette.offWhite,
    textSecondary: AppPalette.grey300,
    textTertiary: AppPalette.grey500,
    textOnVolt: AppPalette.midnight,
    textOnPink: AppPalette.white,
    textLink: AppPalette.volt,
    primary: AppPalette.volt,
    primaryMuted: AppPalette.voltAlpha20,
    secondary: AppPalette.cyan,
    achievement: AppPalette.hotPink,
    pals: AppPalette.palsTeal,
    border: AppPalette.grey700,
    borderFocused: AppPalette.volt,
    divider: Color(0x12FFFFFF),
    tabActive: AppPalette.volt,
    tabInactive: AppPalette.grey500,
    tabBadgeBg: AppPalette.errorRed,
    tabBadgeText: AppPalette.white,
    filterActive: AppPalette.volt,
    filterActiveText: AppPalette.midnight,
    filterInactive: AppPalette.surfaceHigh,
    filterInactiveText: AppPalette.grey300,
    filterBorder: AppPalette.grey700,
    calToday: AppPalette.volt,
    calTodayText: AppPalette.midnight,
    calSelected: AppPalette.voltAlpha30,
    calSelectedText: AppPalette.volt,
    calDotMine: AppPalette.volt,
    calDotPals: AppPalette.palsTeal,
    fabBg: AppPalette.volt,
    fabText: AppPalette.midnight,
    sheetBg: AppPalette.surfaceHigh,
    sheetHandle: AppPalette.grey700,
    statusLive: AppPalette.goGreen,
    statusError: AppPalette.errorRed,
    sliderTrack: AppPalette.grey700,
    sliderFill: AppPalette.volt,
    sliderThumb: AppPalette.volt,
    actionBg: AppPalette.volt,
    actionText: AppPalette.midnight,
    goingBg: AppPalette.voltAlpha20,
    goingText: AppPalette.volt,
    goingBorder: AppPalette.volt,
    palBadgeBg: Color(0x2600BFA5),
    palBadgeText: AppPalette.palsTeal,
    palBadgeBorder: AppPalette.palsTeal,
    planBarMine: AppPalette.volt,
    planBarPals: AppPalette.palsTeal,
    notifBg: AppPalette.errorRed,
    notifText: AppPalette.white,
    searchBg: AppPalette.surface,
    searchBorder: AppPalette.grey700,
    searchBorderFocus: AppPalette.volt,
    searchIcon: AppPalette.grey500,
    searchText: AppPalette.offWhite,
    searchPlaceholder: AppPalette.grey500,
    avatarBg: AppPalette.voltAlpha20,
    avatarText: AppPalette.volt,
    feedDotBg: AppPalette.surface,
    feedDotBorder: AppPalette.volt,
    feedDotIcon: AppPalette.volt,
    feedLine: AppPalette.grey700,
    feedTimeText: AppPalette.grey500,
    feedSectionLabel: AppPalette.grey500,
    feedNameText: AppPalette.offWhite,
    feedLinkText: AppPalette.volt,
  );

  static const AppColors light = AppColors(
    bgPrimary: AppPalette.lightBg,
    bgSurface: AppPalette.lightSurface,
    bgSurfaceHigh: AppPalette.lightSurfaceHigh,
    bgInput: AppPalette.lightSurface,
    bgInputFocused: AppPalette.white,
    textPrimary: AppPalette.midnight,
    textSecondary: AppPalette.grey700,
    textTertiary: AppPalette.grey500,
    textOnVolt: AppPalette.midnight,
    textOnPink: AppPalette.white,
    textLink: AppPalette.violetLink,
    primary: AppPalette.volt,
    primaryMuted: Color(0x26C4FF00),
    secondary: AppPalette.cyanDeep,
    achievement: AppPalette.pinkDeep,
    pals: AppPalette.tealDeep,
    border: AppPalette.lightBorder,
    borderFocused: AppPalette.violetLink,
    divider: Color(0x14000000),
    tabActive: AppPalette.midnight,
    tabInactive: AppPalette.grey500,
    tabBadgeBg: AppPalette.errorRed,
    tabBadgeText: AppPalette.white,
    filterActive: AppPalette.midnight,
    filterActiveText: AppPalette.white,
    filterInactive: AppPalette.lightSurface,
    filterInactiveText: AppPalette.grey700,
    filterBorder: AppPalette.lightBorder,
    calToday: AppPalette.midnight,
    calTodayText: AppPalette.white,
    calSelected: Color(0x4DC4FF00),
    calSelectedText: AppPalette.midnight,
    calDotMine: AppPalette.midnight,
    calDotPals: AppPalette.tealDeep,
    fabBg: AppPalette.volt,
    fabText: AppPalette.midnight,
    sheetBg: AppPalette.lightSurface,
    sheetHandle: AppPalette.lightBorder,
    statusLive: AppPalette.greenDeep,
    statusError: AppPalette.redDeep,
    sliderTrack: AppPalette.lightBorder,
    sliderFill: AppPalette.midnight,
    sliderThumb: AppPalette.midnight,
    actionBg: AppPalette.midnight,
    actionText: AppPalette.white,
    goingBg: Color(0x33C4FF00),
    goingText: AppPalette.oliveOnVolt,
    goingBorder: AppPalette.oliveOnVolt,
    palBadgeBg: Color(0x1F00897B),
    palBadgeText: AppPalette.tealDeep,
    palBadgeBorder: AppPalette.tealDeep,
    planBarMine: AppPalette.midnight,
    planBarPals: AppPalette.tealDeep,
    notifBg: AppPalette.redDeep,
    notifText: AppPalette.white,
    searchBg: AppPalette.lightSurface,
    searchBorder: AppPalette.lightBorder,
    searchBorderFocus: AppPalette.violetLink,
    searchIcon: AppPalette.grey500,
    searchText: AppPalette.midnight,
    searchPlaceholder: AppPalette.grey500,
    avatarBg: Color(0x33C4FF00),
    avatarText: AppPalette.oliveOnVolt,
    feedDotBg: AppPalette.white,
    feedDotBorder: AppPalette.midnight,
    feedDotIcon: AppPalette.midnight,
    feedLine: AppPalette.lightBorder,
    feedTimeText: AppPalette.grey500,
    feedSectionLabel: AppPalette.grey500,
    feedNameText: AppPalette.midnight,
    feedLinkText: AppPalette.violetLink,
  );
}

/// Typography tokens. [display] = Barlow Condensed 800 (stats, headlines,
/// distances); [heading]/[body] = Space Grotesk (variable, weight via fontWeight).
class AppType {
  static const String display = 'BarlowCondensed';
  static const String heading = 'SpaceGrotesk';
  static const String body = 'SpaceGrotesk';

  // Size scale
  static const double xs = 10;
  static const double sm = 12;
  static const double base = 14;
  static const double md = 16;
  static const double lg = 18;
  static const double xl = 22;
  static const double xxl = 28;
  static const double xxxl = 36;
  static const double xxxxl = 48;
  static const double xxxxxl = 60;
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double xxxxl = 40;
  static const double xxxxxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;
}

class AppTheme {
  // ── Legacy constants (kept so unmigrated screens compile) ──────────────────
  // These map to the OLD purple identity on purpose: a screen still using them
  // stays internally consistent until it's converted to AppColors. New code
  // should use `AppColors.of(context)` and the AppType/AppSpacing tokens.
  static const Color primary = Color(0xFF6C3CE1);
  static const Color accent = Color(0xFFFFD600);
  static const Color background = AppPalette.midnight;
  static const Color surface = AppPalette.surface;
  static const Color surfaceLight = AppPalette.surfaceHigh;
  static const Color textPrimary = AppPalette.offWhite;
  static const Color textSecondary = AppPalette.grey300;
  static const Color success = AppPalette.goGreen;
  static const Color divider = Color(0xFF2E2E45);

  // Legacy type scale (still referenced widely). Prefer AppType.* in new code.
  static const double fsDisplay = 20;
  static const double fsHeading = 18;
  static const double fsTitle = 16;
  static const double fsBody = 14;
  static const double fsSecondary = 13;
  static const double fsCaption = 12;

  // ── Theme builders ─────────────────────────────────────────────────────────
  static ThemeData get dark => _build(AppColors.dark, Brightness.dark);
  static ThemeData get light => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppType.body,
      scaffoldBackgroundColor: c.bgPrimary,
      canvasColor: c.bgPrimary,
      cardColor: c.bgSurface,
      dividerColor: c.divider,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: c.primary,
        onPrimary: c.textOnVolt,
        secondary: c.secondary,
        onSecondary: brightness == Brightness.dark
            ? AppPalette.midnight
            : AppPalette.white,
        error: c.statusError,
        onError: AppPalette.white,
        surface: c.bgSurface,
        onSurface: c.textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bgPrimary,
        foregroundColor: c.textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppType.heading,
          color: c.textPrimary,
          fontSize: AppType.xl,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.bgSurface,
        selectedItemColor: c.tabActive,
        unselectedItemColor: c.tabInactive,
        selectedLabelStyle: const TextStyle(
            fontFamily: AppType.body, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.actionBg,
          foregroundColor: c.actionText,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.full)),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: AppType.body,
              fontWeight: FontWeight.w600,
              fontSize: AppType.base),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        // textLink = volt on dark (legible on midnight), violet on light
        // (volt-as-text fails contrast on white — see design doc §7).
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textLink,
          side: BorderSide(color: c.textLink, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg)),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: AppType.body,
              fontWeight: FontWeight.w600,
              fontSize: AppType.base),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.textLink),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: c.fabBg,
        foregroundColor: c.fabText,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.bgInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: c.borderFocused, width: 1.5),
        ),
        labelStyle: TextStyle(color: c.textSecondary),
        hintStyle: TextStyle(color: c.searchPlaceholder),
        prefixIconColor: c.searchIcon,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.filterInactive,
        labelStyle: TextStyle(
            color: c.filterInactiveText, fontSize: AppType.base),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full)),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.sliderFill,
        inactiveTrackColor: c.sliderTrack,
        thumbColor: c.sliderThumb,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheetBg,
        modalBackgroundColor: c.sheetBg,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.bgSurfaceHigh,
        contentTextStyle: TextStyle(color: c.textPrimary),
      ),
      iconTheme: IconThemeData(color: c.textSecondary),
      textTheme: _textTheme(c),
    );
  }

  static TextTheme _textTheme(AppColors c) => TextTheme(
        // Display = Barlow Condensed (stats, hero numbers, big titles)
        displayLarge: TextStyle(
            fontFamily: AppType.display,
            color: c.textPrimary,
            fontWeight: FontWeight.w800),
        displayMedium: TextStyle(
            fontFamily: AppType.display,
            color: c.textPrimary,
            fontWeight: FontWeight.w800),
        headlineLarge: TextStyle(
            fontFamily: AppType.display,
            color: c.textPrimary,
            fontWeight: FontWeight.w800),
        // Headings = Space Grotesk bold
        headlineMedium: TextStyle(
            fontFamily: AppType.heading,
            color: c.textPrimary,
            fontWeight: FontWeight.w700),
        titleLarge: TextStyle(
            fontFamily: AppType.heading,
            color: c.textPrimary,
            fontWeight: FontWeight.w700),
        titleMedium: TextStyle(
            fontFamily: AppType.body,
            color: c.textPrimary,
            fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontFamily: AppType.body, color: c.textPrimary),
        bodyMedium:
            TextStyle(fontFamily: AppType.body, color: c.textSecondary),
        labelLarge: TextStyle(
            fontFamily: AppType.body,
            color: c.textPrimary,
            fontWeight: FontWeight.w600),
      );
}

class AppConstants {
  static const String appName = 'RacePals';
  // Keep in sync with pubspec.yaml `version:`. Shown on the Explore header so a
  // test build is identifiable on-device (which build am I actually running?).
  static const String appVersion = '0.2.30+31';

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
  static const String parkrunVenuesCol = 'parkrunVenues';

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
