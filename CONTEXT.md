# RacePals — Session Context

Use this file to brief Claude at the start of a new session:
> "Read CONTEXT.md and use it as the starting point for this session."

Also read: `BACKLOG.md` (outstanding work), `PROJECT_INSTRUCTIONS.md` (how to work on this project), `USE_CASES.md` (feature scope).

---

## What the app is

**RacePals** — Flutter Android app for UK runners. Discover races & parkruns near a location, log attendance, write reviews, and connect with other runners as **Pals**. Sideloaded APK, no Play Store. Firebase backend.

- App display name: **RacePals** (renamed v0.2.13). **Package id, repo and Firebase project keep the old `racepal` name** — only the user-facing name changed.
- GitHub: https://github.com/maldonadocintia-code/racepal (public)
- Latest release: https://github.com/maldonadocintia-code/racepal/releases/latest
- Current version: **v0.2.29-beta** (pubspec `0.2.29+30`) — full test build: **Wave** launcher logo (v0.2.28) + a **temporary on-screen build marker** under the Explore filter pills (a B8 diagnostic — `build x.y.z` from `AppConstants.appVersion`; **remove once B8 is confirmed on-device**). The actual feature work is unchanged from v0.2.27: Explore/Plan bug fixes (BACKLOG B8–B11) — filter pills wrap, map markers track filters, race-detail rating is live, calendar day panel lists all attendees. ⚠️ **B8 (pill wrap) is fixed in code but not yet confirmed on a real device** — a tester reported the pills still scrolling on an earlier install; the v0.2.29 marker exists to prove which build is actually running. Earlier: v0.2.26 Google Calendar export (BACKLOG #16); v0.2.25 Explore "Find your next race" redesign (BACKLOG #14). Volt & Velocity rebrand shipped in v0.2.20 (see "Design system" section).
- ⚠️ **Test builds are debug-signed** (no `key.properties` on the build machine — keystore step still pending, see PLAY_STORE_LAUNCH.md). Installing an update over a differently-signed install is **silently refused** — testers must fully uninstall first. Releases are cut from branch `docs/cost-model-ios-web`, **not** `master`.
- Firebase project: **racepal-ae334**

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter / Dart (Android only) |
| Package ID | `com.racepal.app` (unchanged despite the RacePals rename) |
| Auth | Firebase Auth (Google Sign-In) |
| Database | Cloud Firestore |
| Storage | Firebase Storage (profile photos) |
| Maps | `google_maps_flutter` |
| Calendar | `table_calendar` |
| State | `provider` — central `AppProvider` (`ChangeNotifier`) |
| Build | Kotlin DSL, `android/app/build.gradle.kts` |
| Test device | Pixel 9 (arm64) |

### Maps API key
- Stored in `android/local.properties` as `maps.apiKey=...`
- **This file is gitignored — NEVER commit it**
- Key is restricted to package `com.racepal.app` + SHA-1 in Google Cloud Console

---

## Navigation — 4 tabs

```
Explore  |  Feed  |  Plan  |  Me
```

(Renamed v0.2.12: Map→Explore, Calendar→Plan.)

| Tab | File | Notes |
|---|---|---|
| Explore | `lib/screens/map_screen.dart` | Discover races/parkruns near a location (location + radius). List default; Map toggle. |
| Feed | `lib/screens/feed_screen.dart` | Activity from your **pals** (+ you). App-bar bell = incoming pal requests. |
| Plan | `lib/screens/calendar_screen.dart` | Your race calendar (month default + list). Tap a day to add a race. |
| Me | `lib/screens/profile_screen.dart` | Profile, tappable stats (Races / Pals / Reviews). |

Shell/nav: `lib/screens/home_shell.dart` — also renders the **incoming-pal-request count as a badge on the Feed tab** (visible from any tab).

---

## The Pals model (v0.2.13 — replaced follow/follower)

A single **symmetric friendship**. No more one-directional follows, no follower/following lists, no account public/private.

- **Flow:** Add pal → sends a request → they **Accept** → you're pals, **both ways, instantly**.
- **`PalStatus`** (`lib/models/user_model.dart`): `none` / `requested` (you asked) / `incoming` (they asked you → "Accept pal") / `pals` (tap to remove) / `self`.
- **Storage:** two mirrored docs `pals/{ownerUid}_{otherUid}` (so rules + "my pals" queries stay simple), plus `pal_requests/{fromUid}_{toUid}`.
- **Bell + badge:** incoming requests show in the Feed bell sheet (Accept / Decline) and as a count badge on the Feed bottom-nav tab.
- **Migration:** `PalService.migrateIfNeeded(uid)` runs once per user on launch (guarded by `palsMigrated` on the user doc): legacy mutual follows → pals (both docs written); one-directional follow → a pending pal request from the follower. Legacy `follows`/`follow_requests` are read-only in rules now.

---

## Source Files

### Screens
| File | Purpose |
|---|---|
| `lib/screens/map_screen.dart` | **Explore**. Location + radius discovery only (**name search removed** v0.2.12 — find a known race on Plan instead). All/Parkruns/Races segment, list↔map toggle (list avoids Maps tile charges). FAB **"Add new event"** → `AddRaceScreen` (creates a community race in the shared collection). Dedup: skips Firestore races with `createdBy == 'system'` so bundled races don't show twice. |
| `lib/screens/calendar_screen.dart` | **Plan**. Defaults to **month** view so tap-to-add is discoverable. Colour-coded: mine (purple) + pals (teal, with avatars). Tap a day → day panel with **"Add a race on \<date>"** → `showPlanAddSheet`. |
| `lib/widgets/plan_add_sheet.dart` | **Tap-a-date add sheet** (v0.2.12). Search bundled curated races + parkruns + **user-created** Firestore races (`createdBy != 'system'`); tap to add to your calendar. Parkruns use the **tapped date**; known races keep their **own fixed date**. "Add it manually" → `AddRaceScreen(initialDate: date)`. |
| `lib/screens/add_race_screen.dart` | Create a race (Race tab, optional `initialDate`) or add a parkrun (Parkrun tab). Title **"Add new event"**; manual submit "Add event". |
| `lib/screens/race_detail_screen.dart` | Race detail — attendance (Going/Attended/Not going), reviews. **Reviews are public to all signed-in users** (the everyone/pals-only split was dropped). Live counts: **"Who's going (N)"** and **"Reviews (N)"** both derive from their streams. Reviews have an **`All · Pals` filter** (shown once a pal has reviewed): All sorts your review first, then pals' (with a teal "Pal" badge), then everyone else; Pals narrows to just your pals. Parkruns use venue doc `pr_<id>` + Saturday picker. Shows pals who are going (`palService.getPals`). **"Add to Google Calendar"** button (v0.2.26, dated races only — not the parkrun venue doc) exports the race to the user's own calendar via `_AddToCalendarButton` → `AppProvider.addRaceToCalendar`. |
| `lib/widgets/parkrun_helpers.dart` | Shared parkrun Saturday-picker + `planParkrunDate()`. |
| `lib/screens/feed_screen.dart` | Feed from `provider.palUids` (+ self). Bell → `_PalRequestsSheet` (incoming requests, Accept/Decline). |
| `lib/screens/profile_screen.dart` | Profile — photo, bio, **tappable stats Races/Pals/Reviews**. Pal button (`_PalButtonWidget`) for other users. (No "recent activity" — removed v0.2.12 as it duplicated the Feed; no private-account label — public/private dropped v0.2.13.) |
| `lib/screens/pals_screen.dart` | **Single Pals list** + "Find pals" search (→ `FindPalsScreen`, `_FoundUserTile` with pal button). (Following/Followers tabs removed v0.2.13.) |
| `lib/screens/edit_profile_screen.dart` | Edit name/bio/photo. (Public/private toggle removed v0.2.13.) |
| `lib/screens/login_screen.dart` | Google Sign-In entry. |

### Models
| File | Key Classes |
|---|---|
| `lib/models/race_model.dart` | `Race` — incl. `recommendPercent`, `lightningBolt` (⚡), `createdBy`. `Race.fromParkrunJson`. |
| `lib/models/review_model.dart` | `Review`, `Attendance`, `AttendanceStatus` (`going`/`attended`/`interested`). |
| `lib/models/user_model.dart` | `AppUser`, `ActivityItem`, **`PalStatus`**. (`isPublic`/`followersCount`/`followingCount` fields remain but are dormant/unused.) |

### Services
| File | Purpose |
|---|---|
| `lib/services/app_provider.dart` | Central state — auth, `currentUser`, **`palUids`**, `setAttendance`, `submitReview`, **`getPalStatus` / `togglePal` / `acceptPalRequest` / `declinePalRequest`**, `uploadProfilePhoto`. Calls `palService.migrateIfNeeded` on sign-in. |
| `lib/services/pal_service.dart` | **The Pals service** (replaced `follow_service.dart`): `getStatus`, `sendRequest`, `cancelRequest`, `acceptRequest`, `declineRequest`, `removePal`, `palUids`/`palsStream`/`getPals`, `incomingRequests` (no orderBy — sorts client-side), `searchUsers` (client-side `contains`, 30s cache, ≤500 users), `migrateIfNeeded`. |
| `lib/services/race_service.dart` | `ensureRace()`, `setAttendance()`, `addReview()`, `attendancesForUsers()`, `upcomingRaces()`, `feedForUser()`, `_recalcRaceStats()`. |
| `lib/services/auth_service.dart` | Google Sign-In, `updateProfile()` (no `isPublic`). |
| `lib/services/places_service.dart` | Loads `assets/uk_places.json`; `PlacesService.search()` type-ahead for Explore location search. Offline, free. |
| `lib/services/google_calendar_service.dart` | Google Calendar export (v0.2.26) — `addRace(Race)` reuses the existing Google sign-in and prompts for the `calendar.events` scope on first use, then inserts the event into the user's primary calendar. Wired via `AppProvider.addRaceToCalendar` → the "Add to Google Calendar" button on race detail. |

### Other
| File | Purpose |
|---|---|
| `lib/main.dart` | App entry, Firebase init, `RacePalApp` (class name unchanged). |
| `lib/theme.dart` | **Volt & Velocity design system** (see section below): `AppPalette`, `AppColors` (semantic, dark/light, `.of(context)`), `AppType`/`AppSpacing`/`AppRadius`, `AppTheme.light`/`.dark`. Legacy `AppTheme.*` purple constants kept for unconverted screens. Plus `AppConstants` (collection names incl. `palsCol`, `palRequestsCol`; `appName = 'RacePals'`). |
| `lib/services/theme_controller.dart` | `ThemeController` (ChangeNotifier) — System/Light/Dark theme mode, persisted via `shared_preferences` (`themeMode` key). Selector lives in the Me screen. |
| `lib/widgets/shared_widgets.dart` | `UserAvatar`, `ActivityCard`, **`PalButton`** (states: Add pal / Requested / Accept pal / Pals ✓). |
| `lib/utils/geo.dart` | `milesBetween()` haversine for radius search. |

---

## Design system — Volt & Velocity (shipped v0.2.20)

A dark **and** light theme rebrand. Source spec: the `racepals-design-system.md` doc the user supplied (written for React Native; translated to Flutter). **Complete and released as v0.2.20-beta (2026-06-19).** All screens converted; `flutter analyze` clean.

**Identity:** primary = **volt green `#C4FF00`** on near-black `#0D0E1A` (replaces the old purple `#6C3CE1`). Fonts: **Barlow Condensed ExtraBold** (display/stats/distances) + **Space Grotesk** (body/headings) — bundled in `assets/fonts/`, declared in `pubspec.yaml`. Space Grotesk is a variable font; weight is picked from `fontWeight`.

**How theming works (Flutter idiom):**
- `lib/theme.dart`: `AppPalette` (raw colours) → `AppColors` (~65 semantic tokens, two `const` instances `dark`/`light`, fetched with `AppColors.of(context)` which switches on `Theme.of(context).brightness`) → `AppType`/`AppSpacing`/`AppRadius` tokens → `AppTheme.light`/`AppTheme.dark` `ThemeData`.
- `lib/services/theme_controller.dart` holds the mode (System/Light/Dark), persisted via `shared_preferences`. `main.dart` uses `MultiProvider` and `MaterialApp(theme: AppTheme.light, darkTheme: AppTheme.dark, themeMode: controller.mode)`.
- **New code:** use `final c = AppColors.of(context);` then `c.primary` etc., plus `AppType.*`/`AppSpacing.*`/`AppRadius.*`. **Do not** add new `AppTheme.primary`-style static refs or numeric `fontSize:`.

**Accent semantics (settled):** volt = primary/active, green = parkrun, cyan = race, pink (`achievement`) = ratings/achievements, teal = pals. **Volt fails as a foreground on light**, so anywhere it would be text/icon-on-light it's swapped for `c.textLink` (volt on dark / violet on light). The legacy `AppTheme.*` colour + `fs*` constants still exist (kept during migration) but are now unused except `AppTheme.light`/`AppTheme.dark` in main.dart — safe to delete in a future cleanup.

**Status:** ✅ **Complete.** All 13 screens/widgets converted to `AppColors.of(context)` + `AppType`/`AppSpacing`/`AppRadius`. Released v0.2.20-beta. Throwaway preview harness lives at `test/volt_gallery_screenshot_test.dart` (run `flutter test --update-goldens` → PNGs in `test/shots/`).

**Accessibility:** doc's verified contrast values kept. Watch the light-mode "Going" badge (olive-on-volt-tint, AA not AAA). Type scale is the doc's larger one (display→60, distances 28), superseding the old v0.2.19 6-step `fs*` scale. **Not yet eyeballed on a physical device** — verified only via the headless gallery screenshots.

---

## Data Assets

| File | Bundled? | Contents |
|---|---|---|
| `assets/parkruns_uk.json` | ✅ | 884 UK parkruns — `id, name, location, lat, lng` |
| `assets/manchester_races.json` | ✅ | **Curated, web-verified ~20 Manchester-area races** (v0.2.15): Run North West, RunThrough (Media City / Tatton Park / Heaton Park — each date a separate entry), Manchester Half, Manchester Marathon, Great Manchester Run, Wilmslow. Schema: `name, url, startDate, description, city, address, lat, lng, distance`. |
| `assets/uk_places.json` | ✅ | ~120 UK towns — gazetteer for Explore location search. |
| `assets/findarace_uk.json` | ❌ (in repo, **not bundled**) | ~1,190 scraped races — **hidden** v0.2.15 (unreliable: mislabelled city/address fields). |
| `assets/major_races_uk.json` | ❌ (in repo, **not bundled**) | 60 national races — superseded by the curated Manchester set. |

> The curated set replaced the bundled bulk data because the findarace entries had mislabelled locations (the `address` field was often a random nearby business). Keep the curated file as the single bundled race source; re-source/expand deliberately.

### Map markers
- Green = parkruns · Orange = curated races · (user-created races also orange)

---

## Firestore Structure

```
races/{raceId}
  name, location, lat, lng, date, type, category, createdBy, website, description
  reviewCount, averageRating, recommendPercent, lightningBolt, attendeeCount

attendances/{uid}_{raceId}
  userId, raceId, status (going/attended/interested), ...

reviews/{reviewId}
  raceId, userId, rating, body, recommend  (all reviews are public to any signed-in user; the dead isPublic field was removed)

users/{uid}
  displayName, photoUrl, bio, createdAt, palsMigrated
  (legacy isPublic/followersCount/followingCount may exist but are unused)

pals/{ownerUid}_{otherUid}          # two mirrored docs per friendship
  ownerUid, otherUid, createdAt

pal_requests/{fromUid}_{toUid}
  fromUid, toUid, createdAt

activities/{actId}
  userId, userName, userPhotoUrl, type (going/attended/review), raceId, raceName, createdAt

follows/, follow_requests/          # LEGACY — read-only (migration source only)
```

---

## Firebase / Firestore Rules (`firestore.rules`)

- **users**: read if signed-in; create/update/delete by owner only (no cross-user count writes any more).
- **races**: creator edits; any signed-in user may update aggregate stat fields only.
- **reviews**: readable by any signed-in user (the everyone/pals-only split was dropped); create by self; edit/delete by owner.
- **pals**: read if signed-in; create/delete if you're either party in the doc (`ownerUid` or `otherUid`).
- **pal_requests**: read if signed-in and you're `fromUid`/`toUid` (with `resource == null ||` guard for status checks); create if `fromUid == you`; delete if you're either party.
- **follows / follow_requests**: read-only (`allow write: if false`) — kept for migration.
- Deploy: `firebase deploy --only firestore:rules` (a **production action** — confirm with the user first). Project is pinned in `.firebaserc` (`racepal-ae334`), so no `--project` flag is needed. **Deploy whenever `firestore.rules` changes** — it's part of the release checklist (see Dev Commands), since dependent client code breaks until the rules are live.

**GOTCHA:** never batch-delete a doc that may not exist when its delete rule reads `resource.data.*` — a null `resource` errors and **denies the whole batch**. This caused the v0.2.13 accept-pal crash. See memory `project_firestore_batch_delete_gotcha`.

---

## Costs — running RacePals (target: $0/month)

The user's hard constraint: **the app must not cost money to run.** As scoped (Manchester, Android-only closed test), the ongoing cost is **$0/month**. Verified June 2026.

| Item | Cost | Notes |
|---|---|---|
| Google Play | **$25 one-time** | Already accepted. No renewal. |
| Apple App Store / iOS | **$99/year recurring** | **Deliberately skipped.** No free native-iOS path exists (even TestFlight needs the $99/yr program; Xcode free-sideload expires after 7 days — impractical). iPhone users are served by a free web/PWA build instead (see PLAY_STORE_LAUNCH.md "iPhone / web users"). |
| Google Maps (Android native) | **$0, unlimited** | "Mobile Native Dynamic Maps" SKU is free. **Do not** switch map providers — Google native is free and best. Don't call billable SKUs (Geocoding/Places/Directions); location search uses bundled `uk_places.json`. |
| Firebase Auth / Firestore / Storage | **$0 at this scale** | Spark (free) plan covers a closed test easily. |
| Firebase **Crashlytics** | **$0** | Free on Spark. Recommended add for the beta (crash visibility). |
| In-app **feedback link** | **$0** | Just a `mailto:` / Google Form link. Recommended add for the beta. |
| Push notifications (FCM) | **$0 to send**, but… | FCM is free/unlimited. *Event-triggered* push (e.g. "new pal request") needs a **Cloud Function**, which requires the **Blaze** plan — a credit card on file. Free tier (2M invocations/mo) means $0 in practice, but it's not a hard cap by default. **Deferred for MVP.** If added: set a Cloud Billing budget alert + cap. |
| Google Calendar API (export, v0.2.26) | **$0** | Free, **no billing account, no Blaze** (unlike Maps). User writes to their own calendar on their own quota. `calendar.events` is a **sensitive** (not restricted) scope → OAuth verification is a **free** review; only *restricted* scopes (Gmail/Drive) need a paid security assessment. Verification deferred to before public launch; runs under the unverified-app grace meanwhile. See PLAY_STORE_LAUNCH.md §9. |

**Bottom line:** ongoing cost is **$0/month**; only spend is the $25 Play one-off. The single recurring cost in the whole stack (iOS, $99/yr) is intentionally avoided. The only thing that would put a credit card on file is event-driven push, which is deferred.

---

## GDPR & Play Store launch (in progress)

Goal: ship to the **Play Store closed-testing** track for feedback. See **`PLAY_STORE_LAUNCH.md`** for the full step-by-step.

**Done in code (this session, not yet released):**
- **Account deletion** (GDPR erasure) — Me tab → *Delete account*. `AuthService.deleteAccount`/`reauthenticateWithGoogle`, orchestrated by `AppProvider.deleteAccount`. Re-auths via Google, then wipes reviews, attendances, activity, pals (both mirror docs), pal requests, profile photo, user doc, then the auth account. Uses **individual deletes** (not batches) to respect the batch-delete-of-missing-doc gotcha.
- **Sign-up consent** — login screen shows a Privacy Policy notice/link (`flutter/gestures` `TapGestureRecognizer`); profile has Privacy Policy + Delete account links. Replaced the stale "No Play Store needed" line.
- **Privacy policy** — `docs/privacy.html`, **live on GitHub Pages** at https://maldonadocintia-code.github.io/racepal/privacy.html (source: master `/docs`, enabled 2026-06-19). Controller name/email filled in (Cintia Maldonado / cinmal1988@gmail.com). Wording describes all reviews as public.
- **Firebase Analytics dropped** — removed from `android/app/build.gradle.kts` (no analytics-consent burden). It was never in pubspec.
- **Release signing** — `build.gradle.kts` now reads `android/key.properties` (gitignored) for a real release `signingConfig`, falling back to debug signing when absent. **Keystore not yet generated** — the user owns that (password = permanent). `AppConstants.privacyPolicyUrl` added.

**Pending (user/console actions — see PLAY_STORE_LAUNCH.md):** generate keystore + `key.properties`; `flutter build appbundle`; **deploy Firestore rules** (new `users` self-delete rule — production); create Play dev account ($25); upload `.aab`; Data Safety + content rating + listing. (Privacy policy hosting ✅ done — live on GitHub Pages.)

**Decisions:** closed testing (not full launch); full client-side deletion (no Cloud Function); Google-only sign-in for launch, email/password as a fast-follow; passkeys parked (needs a paid backend).

## Release history (recent)

- **Unreleased (on `master`, not yet built/tagged)** — Privacy-policy hosting + reviews-public cleanup: **GitHub Pages enabled** so `docs/privacy.html` is now live (the in-app link previously 404'd); policy reworded so reviews are described as public; the vestigial `Review.isPublic` field (always-true, never read) removed from the model + all review call sites (profile `isPublic` untouched). `flutter analyze` clean.
- **Unreleased (in code on `master`, not yet built/tagged)** — Race-detail review & attendance fixes: (1) **"Who's going (N)"** count is now live off the attendee stream — the stored `attendeeCount` field was never written, so it always showed 0; (2) **dropped the everyone/pals-only review split** — all reviews are public to any signed-in user, the visibility radio is gone, the `reviews` query is a plain `where raceId==` sorted client-side (no composite index dependency, which was silently hiding reviews), and **`reviews` read rule changed to `if isSignedIn()`**; (3) **review count** shown as "Reviews (N)"; (4) **`All · Pals` review filter** + "Pal" badge + pals-first ordering. ⚠️ **Requires `firebase deploy --only firestore:rules` before/with the release** — client depends on the new read rule. ⚠️ Existing "Pals only" reviews become visible to everyone once deployed.
- **v0.2.29** — **Build marker (B8 diagnostic)** + full bundled test build. Added a small `build ${AppConstants.appVersion}` label under the Explore filter pills (`map_screen.dart` `_header`) so the running binary is identifiable on-device — a tester kept seeing the old scrolling pills, suggesting the installed APK didn't match the source. `AppConstants.appVersion` updated to `0.2.29+30` (was a stale `1.0.0`; **keep in sync with pubspec manually**). Built clean (`flutter clean` first) and **released with the Wave logo, Calendar, and B8–B11 all bundled**. **The marker is temporary — remove it once B8 is confirmed fixed on a real device.** GitHub release `v0.2.29-beta` (latest), `app-arm64-v8a-release.apk` attached.
- **v0.2.28** — **Wave app launcher icon** (new logo). Replaced the default Flutter icon with the "Wave" logo (volt pulse on midnight): adaptive icon (`mipmap-anydpi-v26/ic_launcher.xml` + `drawable/ic_launcher_background.xml`/`ic_launcher_foreground.xml`), all density mipmaps, and `ic_launcher-playstore.png`. Source assets + the original-icon backup live in `prototype/logo/` (untracked). **No v0.2.28 GitHub release** was cut — the icon shipped to testers bundled inside v0.2.29. ⚠️ Stray duplicate logo commits also landed on `master` (`ab867f9`); cleanup deferred.
- **v0.2.27** — **Explore/Plan bug fixes** (BACKLOG B8–B11). (B8) Explore filter pills now use a `Wrap` and show each filter's *name* at rest / *value* when active, so an overflowing pill drops to a second row instead of scrolling off-screen. (B9) Map markers are derived from the same filtered `_buildResults()` as the list and handed to `GoogleMap` as a **fresh `Set` each build** (`_markersFor`/`_circlesFor`; dropped the cached `_markers`/`_circles` fields) — fixes stale/extra pins when changing Distance/Month/Type in map view. (B10) Race-detail hero rating/count is now a `_HeaderRating` widget streaming `raceReviews` live, instead of reading the one-shot, 2-min-cached race doc — a just-posted review (incl. a race's first) shows immediately. (B11) Calendar day panel uses a new `_DayRaceCard` that drops the redundant date column and lists **every** attendee (You + each pal, avatar + name) with an "and N more" toggle, replacing the compact row that capped at a few avatars. Client-side only; no Firestore/rules changes. **First test build is debug-signed** (no `key.properties` locally).
- **v0.2.26** — **Google Calendar export** (BACKLOG #16). Wired the pre-built `GoogleCalendarService` to an **"Add to Google Calendar"** button on race detail (`_AddToCalendarButton` → `AppProvider.addRaceToCalendar`). Dated races only (parkruns plan a specific Saturday separately). Reuses the existing Google sign-in; prompts for the **sensitive** `calendar.events` scope on first use. **OAuth verification deferred to before public launch** — the scope was added to the production OAuth screen without submitting verification, so it runs under the unverified-app grace (≤100 testers see a one-time "unverified app" warning). Verification is **free** (sensitive, not restricted — no paid security assessment). See PLAY_STORE_LAUNCH.md §9 + `docs/tester-notes.md`. Client-side only; no Firestore/rules changes.
- **v0.2.25** — **Explore "Find your next race" redesign** (BACKLOG #14). Reshaped Explore around a search hub: a **launcher** (heading + three cards — By location / By month / By distance) that drops into the results list with that lens primed (`_searchStarted` gates launcher vs results; `_enter()` / `_goHome()`). Results header = back arrow + full-width **location pill** + Map/List toggle, a **radius slider shown only when a place is set** (fixes the v0.2.24 orphaned-slider bug), and quiet **Month / Distance / Type** filter pills (outline at rest, fill volt when active; each opens its own picker sheet via `_openPicker`). **New Month filter** (`_month`, 'yyyy-MM'; parkruns recur so they match any month). **Location now optional** — no place → browse by month/distance across the UK, tiles show a date instead of miles. **Distance pill disabled when Type=Parkruns**. Calm tiles: race name hero + one muted meta line (`mi · distance · place`) + muted rating (dropped the big number, colour badges, chevron). Client-side only. Supersedes the v0.2.24 header.
- **v0.2.24** — **Explore distance filter** (BACKLOG #3). Option A "filters in a sheet" redesign of the Explore header: location pill + **Filters** button (active-count badge) + Map/List toggle on one row, with a removable active-filter chip strip below. The radius slider, **Type** (All/Parkruns/Races) and new **Distance** (Any/5K/10K/10 mile/Half/Marathon/Ultra) live in a bottom sheet with a live "Show N results" button + Reset. New `lib/utils/distance.dart` (`DistanceBucket`, `bucketsFor()`) parses **multi-distance** events ("5K / 10K / Half" matches all three; "Half Marathon"→Half). Parkruns classed as 5K (single flag `_distAppliesToParkruns`). Result tiles show a distance badge. Unbucketed types (5-mile, Trail, Triathlon, Other) only appear under "Any". Client-side only — no Firestore/rules changes.
- **v0.2.23** — Two things: (1) **User-created parkrun venues** — if a parkrun isn't in `parkruns_uk.json`, "Add it manually" under the parkrun picker creates a shared *venue* (no date) in the new `parkrunVenues` collection; all users see it merged into both parkrun pickers (`add_race_screen.dart`, `plan_add_sheet.dart`) and pick their own Saturday. `RaceService.addParkrunVenue`/`parkrunVenues`; venue ids `prv_<docId>`, per-date races `prv_<docId>_<yyyyMMdd>`. **Requires the new `parkrunVenues` Firestore rule deployed** to function. Not yet on the Explore map (manual form collects no lat/lng). (2) **AAA rating/achievement pink** in both themes — dark `#FF3CAC`→`#FF8AD0` (7.6:1), light `#C0006A`→`#A8005C` (7.45:1).
- **v0.2.22** — **Date-locked race adds.** In the Plan tap-a-date sheet (`plan_add_sheet.dart`), a fixed-date race (bundled *or* community) can now only be added on the calendar day it actually takes place — new `_Known.addableOn(tapped)` (parkruns always addable; they take the tapped Saturday). Mismatched races stay visible but **disabled**, with the subtitle replaced by "Only addable on \<date>" + a busy icon. `_add()` also guards on `addableOn`. Explore → "Going" deliberately left unrestricted so future races can still be planned ahead.
- **v0.2.21** — Three fixes: (1) **planned parkruns can be cancelled** — a per-date parkrun doc the user marked "going" now shows a red **Not going** button in `RaceDetailScreen` (the `isParkrun` branch previously only offered "Plan a date"/"Review"); (2) **calendar weekday labels** no longer clipped (`daysOfWeekHeight: 24` on `TableCalendar`); (3) **account deletion now purges legacy `follows`** in both directions — otherwise re-signup re-ran the Pals migration and resurrected old connections. Firestore `follows` rule now allows either party to `delete` (create/update still locked); rules deployed.
- **v0.2.20** — **Volt & Velocity design system**: full rebrand (volt-green on midnight) + **light & dark themes** with a System/Light/Dark selector (Me → Appearance, persisted). Bundled Barlow Condensed + Space Grotesk fonts. New `AppColors`/`AppType`/`AppSpacing`/`AppRadius` tokens; all screens converted. (See "Design system" section.)
- **v0.2.19** — App-wide type scale (BACKLOG #7): 6-step scale in `theme.dart`, all screens snapped to tokens.
- **v0.2.18** — Feed redesigned as a timeline (day groups, type icons/colour, timestamps, quoted reviews); clearer review-visibility wording.
- **v0.2.17** — Explore shows ratings next to curated races/parkruns (B6); faster review posting + scrollable sheet (B7); calendar read/cost fix (race cache + no day-tap reload, #9).
- **v0.2.16** — GDPR: in-app account deletion, sign-up consent + privacy policy, dropped Analytics, release-signing config; `users` self-delete rule deployed.
- **v0.2.15** — Curated Manchester race set (hid findarace/major); fixed Explore race duplication.
- **v0.2.14** — Fixed accept-pal crash (batch-delete gotcha); incoming-request badge on Feed tab.
- **v0.2.13** — **Pals friendship model** (replaced follows); app renamed **RacePals**; "Add new event" wording; migration from follows.
- **v0.2.12** — Map→Explore (name search removed) / Calendar→Plan; tap-a-date add flow (`plan_add_sheet`); Feed header cleaned; profile "recent activity" removed.
- **v0.2.11** — Unfollow from lists; privacy enforced server-side (since superseded by Pals).
- **v0.2.10** — (pre-Pals) follow requests visible; reactive pals.

---

## Dev Commands

```bash
# Build release APKs split per ABI (full APK upload times out — attach arm64 only)
flutter build apk --release --split-per-abi
#   → build/app/outputs/flutter-apk/app-arm64-v8a-release.apk  (Pixel 9 + modern phones)

# Analyze
flutter analyze lib/

# Deploy Firestore rules (production — confirm first).
# Project is pinned in .firebaserc, so no --project flag is needed.
firebase deploy --only firestore:rules

# Publish a GitHub Release (gh CLI authed as maldonadocintia-code)
gh release create v0.2.x-beta "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk#RacePals-v0.2.x-beta-arm64.apk" --title "v0.2.x-beta" --notes-file <file> --latest
# Also copy the APK to C:\Users\maldo\OneDrive\Desktop\
```

> Releases are done **by the agent via `gh`**, not manual upload. Bump `version:` in `pubspec.yaml` (e.g. `0.2.15+16`) and commit before building. Direct push to `master` needs the user's OK (the harness prompts).
>
> **Release checklist — don't skip:** if `firestore.rules` (or `storage.rules`) changed since the last release, **deploy them** (`firebase deploy --only firestore:rules`) — client code that depends on new rules breaks in production until you do. The project is pinned in `.firebaserc` so the bare command targets `racepal-ae334`.

---

## Key Design Decisions / Gotchas

- **Pals = explicit symmetric friendship** (`pals/{a}_{b}` mirrored docs), not derived from follows any more.
- **Batch-delete of a non-existent doc denies the whole batch** when the rule reads `resource.data` (see above).
- **`ensureRace()`** — creates a Firestore race doc on demand with a deterministic id when a user adds a parkrun/curated race. Idempotent (no-op if it exists), so it's safe to call when adding an already-existing community race.
- **Deterministic race IDs** — parkruns `pr_<venueId>_<yyyyMMdd>` (bundled) or `prv_<docId>_<yyyyMMdd>` (user-created venue); curated events `fa_<urlSlug>` (or `evt_<name>_<date>` if no url); community races: Firestore auto-id.
- **User-created parkruns** (`parkrunVenues` collection) — adding a parkrun that isn't in `parkruns_uk.json` creates a *venue* (no date), via "Add it manually" under the parkrun picker. Venues are read by all users and merged into both parkrun pickers (`add_race_screen.dart`, `plan_add_sheet.dart`) so anyone can pick one and choose their own Saturday. Not yet shown on the Explore map (needs lat/lng, which the manual form doesn't collect).
- **Tapped-date semantics** — on Plan, parkruns are added on the tapped date; a known race keeps its own fixed date (shown in the result), since fixed-date races can't move.
- **`lightningBolt`** — `recommendPercent >= 0.8` AND `reviewCount >= 10`. ⚡ badge.
- **`AttendanceStatus`** lives in `lib/models/review_model.dart` (not race_model).
- **No Play Store** — sideloaded APK via GitHub Releases.
- **Maps billing** — the native Android SDK map (`google_maps_flutter`) uses the **"Mobile Native Dynamic Maps" SKU, which is $0 with unlimited usage** — map loads on Android are **free**. (The old "~$0.007/load / $200 free tier" note was wrong: that's the *web* JavaScript Maps SKU, which the app doesn't use. The $200 monthly credit was also scrapped in the March 2025 pricing change and replaced with per-SKU free caps — irrelevant here since the mobile SKU is free.) Location search uses the bundled `uk_places.json` gazetteer, **not** the billable Geocoding/Places APIs — keep it that way. List view still loads zero tiles, but the map view is free too. See the **Costs** section below.

---

## Backlog highlights (see BACKLOG.md)

- **GDPR account deletion** (required before public launch).
- **Scalable search** (SC1) — `searchUsers` loads ≤500 users; Plan add-search sees ≤30 upcoming community races.
- **Run North West** — add the 3 undated 2027 races (Trafford 10K, Alderley Edge 10K, Quarry Bank Trail) once dated; expand the curated set as needed.
- **Privacy/cleanup** — audit legacy follows (PR1), unused-rule check (PR2), delete `prototype/explore_plan_mockup.html` (C1).
- README/profile polish, font-size consistency, calendar/profile load perf.
