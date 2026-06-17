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
- Current version: **v0.2.15-beta**
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
| `lib/screens/race_detail_screen.dart` | Race detail — attendance (Going/Attended/Not going), reviews. Review visibility radio: **Everyone / Pals only**. Parkruns use venue doc `pr_<id>` + Saturday picker. Shows pals who are going (`palService.getPals`). |
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
| `lib/services/google_calendar_service.dart` | Google Calendar export (built, not wired to a button). |

### Other
| File | Purpose |
|---|---|
| `lib/main.dart` | App entry, Firebase init, `RacePalApp` (class name unchanged). |
| `lib/theme.dart` | `AppTheme` (purple `#6C3CE1`, accent `#FFD600`), `AppConstants` (collection names incl. `palsCol`, `palRequestsCol`; `appName = 'RacePals'`). Calendar pals teal `#22D3EE` is local to `calendar_screen`. |
| `lib/widgets/shared_widgets.dart` | `UserAvatar`, `ActivityCard`, **`PalButton`** (states: Add pal / Requested / Accept pal / Pals ✓). |
| `lib/utils/geo.dart` | `milesBetween()` haversine for radius search. |

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
  raceId, userId, rating, body, recommend, isPublic (true = Everyone, false = Pals only)

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
- **reviews**: visible if `isPublic == true`, owner, or `isPal(author)`; create by self; edit/delete by owner.
- **pals**: read if signed-in; create/delete if you're either party in the doc (`ownerUid` or `otherUid`).
- **pal_requests**: read if signed-in and you're `fromUid`/`toUid` (with `resource == null ||` guard for status checks); create if `fromUid == you`; delete if you're either party.
- **follows / follow_requests**: read-only (`allow write: if false`) — kept for migration.
- Deploy: `firebase deploy --only firestore:rules --project racepal-ae334` (a **production action** — confirm with the user first).

**GOTCHA:** never batch-delete a doc that may not exist when its delete rule reads `resource.data.*` — a null `resource` errors and **denies the whole batch**. This caused the v0.2.13 accept-pal crash. See memory `project_firestore_batch_delete_gotcha`.

---

## Release history (recent)

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

# Deploy Firestore rules (production — confirm first)
firebase deploy --only firestore:rules --project racepal-ae334

# Publish a GitHub Release (gh CLI authed as maldonadocintia-code)
gh release create v0.2.x-beta "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk#RacePals-v0.2.x-beta-arm64.apk" --title "v0.2.x-beta" --notes-file <file> --latest
# Also copy the APK to C:\Users\maldo\OneDrive\Desktop\
```

> Releases are done **by the agent via `gh`**, not manual upload. Bump `version:` in `pubspec.yaml` (e.g. `0.2.15+16`) and commit before building. Direct push to `master` needs the user's OK (the harness prompts).

---

## Key Design Decisions / Gotchas

- **Pals = explicit symmetric friendship** (`pals/{a}_{b}` mirrored docs), not derived from follows any more.
- **Batch-delete of a non-existent doc denies the whole batch** when the rule reads `resource.data` (see above).
- **`ensureRace()`** — creates a Firestore race doc on demand with a deterministic id when a user adds a parkrun/curated race. Idempotent (no-op if it exists), so it's safe to call when adding an already-existing community race.
- **Deterministic race IDs** — parkruns `pr_<venueId>_<yyyyMMdd>`; curated events `fa_<urlSlug>` (or `evt_<name>_<date>` if no url); community races: Firestore auto-id.
- **Tapped-date semantics** — on Plan, parkruns are added on the tapped date; a known race keeps its own fixed date (shown in the result), since fixed-date races can't move.
- **`lightningBolt`** — `recommendPercent >= 0.8` AND `reviewCount >= 10`. ⚡ badge.
- **`AttendanceStatus`** lives in `lib/models/review_model.dart` (not race_model).
- **No Play Store** — sideloaded APK via GitHub Releases.
- **Maps billing** — list view loads zero tiles; map view costs ~$0.007/load. Free tier $200/mo.

---

## Backlog highlights (see BACKLOG.md)

- **GDPR account deletion** (required before public launch).
- **Scalable search** (SC1) — `searchUsers` loads ≤500 users; Plan add-search sees ≤30 upcoming community races.
- **Run North West** — add the 3 undated 2027 races (Trafford 10K, Alderley Edge 10K, Quarry Bank Trail) once dated; expand the curated set as needed.
- **Privacy/cleanup** — audit legacy follows (PR1), unused-rule check (PR2), delete `prototype/explore_plan_mockup.html` (C1).
- README/profile polish, font-size consistency, calendar/profile load perf.
