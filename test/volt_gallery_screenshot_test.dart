// THROWAWAY preview harness — generates screenshots of the Volt & Velocity
// design system using the REAL theme tokens + bundled fonts, with no Firebase /
// auth / maps. Run:
//   flutter test --update-goldens test/volt_gallery_screenshot_test.dart
// → writes test/shots/volt_dark.png and test/shots/volt_light.png
// Safe to delete once the rebrand is reviewed.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racepal/theme.dart';

Future<void> _loadFonts() async {
  await (FontLoader('BarlowCondensed')
        ..addFont(rootBundle.load('assets/fonts/BarlowCondensed-ExtraBold.ttf')))
      .load();
  await (FontLoader('SpaceGrotesk')
        ..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Variable.ttf')))
      .load();
}

void main() {
  testWidgets('volt gallery — dark', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    await tester.pumpWidget(const _GalleryApp(dark: true));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(_GalleryApp), matchesGoldenFile('shots/volt_dark.png'));
  });

  testWidgets('volt gallery — light', (tester) async {
    await _loadFonts();
    await tester.binding.setSurfaceSize(const Size(430, 1500));
    await tester.pumpWidget(const _GalleryApp(dark: false));
    await tester.pumpAndSettle();
    await expectLater(
        find.byType(_GalleryApp), matchesGoldenFile('shots/volt_light.png'));
  });
}

class _GalleryApp extends StatelessWidget {
  final bool dark;
  const _GalleryApp({required this.dark});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark : AppTheme.light,
      home: const _Gallery(),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wordmark
              Text('RACEPALS',
                  style: TextStyle(
                      fontFamily: AppType.display,
                      fontSize: AppType.xxxl,
                      color: c.textPrimary,
                      letterSpacing: 0.5)),
              Text('Your UK running social calendar',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: AppType.md,
                      color: c.textSecondary)),
              const SizedBox(height: AppSpacing.lg),

              _label(c, 'EXPLORE'),
              const SizedBox(height: AppSpacing.sm),
              // Search bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: c.searchBg,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(color: c.searchBorder),
                ),
                child: Row(children: [
                  Icon(Icons.location_on_outlined, color: c.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Manchester',
                      style: TextStyle(
                          fontFamily: AppType.body,
                          fontSize: AppType.md,
                          color: c.searchText,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  Icon(Icons.close, color: c.searchIcon, size: 18),
                ]),
              ),
              const SizedBox(height: AppSpacing.md),
              // Filter chips
              Row(children: [
                _chip(c, 'All', active: true),
                const SizedBox(width: 8),
                _chip(c, 'Parkruns'),
                const SizedBox(width: 8),
                _chip(c, 'Races'),
                const Spacer(),
                _viewToggle(c),
              ]),
              const SizedBox(height: AppSpacing.md),
              // Distance list tiles
              _distanceTile(c, '1.2', 'Peel parkrun', 'Saturdays · 9:00am',
                  '📍 Peel Park', '★ 4.6 (12)'),
              const SizedBox(height: 8),
              _distanceTile(c, '4.8', 'Manchester Half', 'Sun 12 Oct 2026',
                  '📍 Manchester city centre', null),
              const SizedBox(height: AppSpacing.lg),

              _label(c, 'BUTTONS & BADGES'),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                ElevatedButton(onPressed: () {}, child: const Text("I'm doing this")),
                const SizedBox(width: 12),
                OutlinedButton(onPressed: () {}, child: const Text('Reviews')),
              ]),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                _badge(c, 'Going', c.goingBg, c.goingText, c.goingBorder),
                const SizedBox(width: 8),
                _badge(c, 'Pal', c.palBadgeBg, c.palBadgeText, c.palBadgeBorder),
                const SizedBox(width: 8),
                _tag(c, 'parkrun', AppPalette.goGreen),
                const SizedBox(width: 8),
                Text('⚡', style: TextStyle(fontSize: AppType.lg, color: c.primary)),
              ]),
              const SizedBox(height: AppSpacing.lg),

              _label(c, 'FEED'),
              const SizedBox(height: AppSpacing.sm),
              _feedItem(c),
              const SizedBox(height: AppSpacing.lg),

              _label(c, 'PLAN'),
              const SizedBox(height: AppSpacing.sm),
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(color: c.calToday, shape: BoxShape.circle),
                  child: Text('18',
                      style: TextStyle(
                          fontFamily: AppType.body,
                          color: c.calTodayText,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: AppSpacing.lg),
                _legendDot(c, c.calDotMine, 'Mine'),
                const SizedBox(width: AppSpacing.lg),
                _legendDot(c, c.calDotPals, 'Pals'),
                const Spacer(),
                // FAB sample
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                  decoration: BoxDecoration(
                      color: c.fabBg,
                      borderRadius: BorderRadius.circular(AppRadius.full)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_location_alt_outlined,
                        color: c.fabText, size: 18),
                    const SizedBox(width: 8),
                    Text('Add new event',
                        style: TextStyle(
                            fontFamily: AppType.body,
                            color: c.fabText,
                            fontWeight: FontWeight.w500)),
                  ]),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(AppColors c, String t) => Text(t,
      style: TextStyle(
          fontFamily: AppType.body,
          fontSize: AppType.xs,
          color: c.feedSectionLabel,
          fontWeight: FontWeight.w500,
          letterSpacing: 2));

  Widget _chip(AppColors c, String t, {bool active = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? c.filterActive : c.filterInactive,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border:
              Border.all(color: active ? Colors.transparent : c.filterBorder),
        ),
        child: Text(t,
            style: TextStyle(
                fontFamily: AppType.body,
                fontSize: AppType.base,
                color: active ? c.filterActiveText : c.filterInactiveText,
                fontWeight: active ? FontWeight.w500 : FontWeight.normal)),
      );

  Widget _viewToggle(AppColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.filterInactive,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: c.filterBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.map_outlined, size: 16, color: c.textPrimary),
          const SizedBox(width: 5),
          Text('Map',
              style: TextStyle(
                  color: c.textPrimary,
                  fontSize: AppType.sm,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _distanceTile(AppColors c, String dist, String title, String sub,
          String addr, String? rating) =>
      Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          SizedBox(
            width: 48,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dist,
                  style: TextStyle(
                      fontFamily: AppType.display,
                      color: c.primary,
                      fontSize: AppType.xxl,
                      height: 1.1,
                      fontWeight: FontWeight.w800)),
              Text('miles',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      color: c.textTertiary,
                      fontSize: AppType.xs)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      color: c.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: AppType.md)),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      color: c.textSecondary,
                      fontSize: AppType.sm)),
              Text(addr,
                  style: TextStyle(
                      fontFamily: AppType.body,
                      color: c.textTertiary,
                      fontSize: AppType.sm)),
            ]),
          ),
          if (rating != null)
            Text(rating,
                style: TextStyle(
                    fontFamily: AppType.body,
                    color: c.achievement,
                    fontSize: AppType.sm,
                    fontWeight: FontWeight.w700)),
          Icon(Icons.chevron_right, size: 16, color: c.textTertiary),
        ]),
      );

  Widget _badge(AppColors c, String t, Color bg, Color fg, Color border) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
        ),
        child: Text(t,
            style: TextStyle(
                fontFamily: AppType.body,
                color: fg,
                fontSize: AppType.sm,
                fontWeight: FontWeight.w500)),
      );

  Widget _tag(AppColors c, String t, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(t,
            style: TextStyle(
                color: color, fontSize: AppType.sm, fontWeight: FontWeight.w600)),
      );

  Widget _feedItem(AppColors c) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: c.feedDotBg,
                shape: BoxShape.circle,
                border: Border.all(color: c.feedDotBorder, width: 2),
              ),
              child: Icon(Icons.location_on_outlined,
                  size: 14, color: c.feedDotIcon),
            ),
            Container(width: 2, height: 28, color: c.feedLine),
          ]),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: AppType.base,
                      color: c.feedNameText),
                  children: [
                    const TextSpan(
                        text: 'Cintia Barrett ',
                        style: TextStyle(fontWeight: FontWeight.w500)),
                    const TextSpan(text: 'is going to '),
                    TextSpan(
                        text: 'Abbey Park parkrun',
                        style: TextStyle(
                            color: c.feedLinkText,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Text('~1d',
                  style: TextStyle(
                      fontFamily: AppType.body,
                      fontSize: AppType.sm,
                      color: c.feedTimeText)),
            ]),
          ),
        ],
      );

  Widget _legendDot(AppColors c, Color dot, String label) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontFamily: AppType.body,
                color: c.textSecondary,
                fontSize: AppType.sm)),
      ]);
}
