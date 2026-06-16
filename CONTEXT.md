# RacePal — Session Context

Use this file to brief Claude at the start of a new session:
> "Read CONTEXT.md and use it as the starting point for this session."

Also read: `BACKLOG.md` (outstanding work), `PROJECT_INSTRUCTIONS.md` (how to work on this project), `USE_CASES.md` (feature scope).

---

## What the app is

**RacePal** — Flutter Android app for UK runners. Discover races & parkruns on a map, log attendance, write reviews, follow other runners ("Pals"). Sideloaded APK, no Play Store. Firebase backend.

- GitHub: https://github.com/maldonadocintia-code/racepal (public)
- Latest release: https://github.com/maldonadocintia-code/racepal/releases/latest
- Current version: **v0.2.10-beta**
- Firebase project: **racepal-ae334**

---

## Tech Stack

| Layer | Technology |
|---|---|
| UI | Flutter / Dart (Android only) |
| Package ID | `com.racepal.app` |
| Auth | Firebase Auth (Google Sign-In) |
| Database | Cloud Firestore |
| Storage | Firebase Storage (profile photos) |
| Maps | `google_maps_flutter: ^2.9.0` |
| Calendar | `table_calendar: ^3.1.2` |
| Image upload | `image_picker: ^1.0.7` |
| State | `provider: ^6.1.2` — central `AppProvider` (`ChangeNotifier`) |
| Build | Kotlin DSL, Java 21, `android/app/build.gradle.kts` |
| Test device | Pixel 9 — `adb -s 46140DLAQ0047E` |

### Maps API key
- Stored in `android/local.properties` as `maps.apiKey=...`
- **This file is gitignored — NEVER commit it**
- Key is restricted to package `com.racepal.app` + SHA-1 in Google Cloud Console
- Read by `build.gradle.kts` via `manifestPlaceholders`

---

## Navigation — 4 tabs

```
Map  |  Feed  |  Calendar  |  Me
```

| Tab | File | Notes |
|---|---|---|
| Map | `lib/screens/map_screen.dart` | Full-screen Google Map + list view toggle |
| Feed | `lib/screens/feed_screen.dart` | Activity feed from followed users |
| Calendar | `lib/screens/calendar_screen.dart` | My races + Pals races toggle, month picker |
| Me | `lib/screens/profile_screen.dart` | Profile, stats, pals, reviews |

Shell/nav: `lib/screens/home_shell.dart`

---

## All Source Files

### Screens
| File | Purpose |
|---|---|
| `lib/screens/map_screen.dart` | Hero **Discover** screen (v0.2.8 redesign). **Location + radius search**: tap location bar → type a town (gazetteer type-ahead) → radius slider → results within radius **sorted by distance**, addresses shown. All/Parkruns/Races segment. List default; Map toggle shows a radius circle. Parkrun panel → "I'm doing this" (Saturday picker) + "Reviews" (venue detail). `_LocationPickerSheet`, `_Result` model inside. |
| `lib/screens/race_detail_screen.dart` | Race detail — attendance buttons (Going / Attended / Not going / Review), reviews list. **Parkruns** use a venue doc `pr_<id>`: row shows "Plan a date" (Saturday picker) + "Review"; per-date attendee/pals sections hidden |
| `lib/widgets/parkrun_helpers.dart` | Shared parkrun Saturday-picker + `planParkrunDate()` (used by map + race detail) |
| `lib/screens/add_race_screen.dart` | Community-add a race (Firestore write) |
| `lib/screens/calendar_screen.dart` | Month + list calendar (v0.2.8). **No Me/Pals tabs** — mine (purple) and pals (teal) shown together; pals' races show **their avatars** (variant C). `_entriesLoader` builds combined `_Entry` list. |
| `lib/screens/feed_screen.dart` | Activity feed from followingUids; appbar bell → pending follow-requests sheet (badge + Accept/Reject) |
| `lib/screens/profile_screen.dart` | Profile — photo, bio. **Tappable stats: Races (completed, from attendances) / Pals / Reviews** → `_UserRacesScreen` / PalsScreen / `_UserReviewsScreen`. Recent activity list. |
| `lib/screens/edit_profile_screen.dart` | Edit name/bio/photo. Camera or gallery pick → Firebase Storage upload |
| `lib/screens/pals_screen.dart` | 3 tabs: Pals / Following / Followers. Search in appbar → FindPalsScreen |
| `lib/screens/login_screen.dart` | Google Sign-In entry screen |

### Models
| File | Key Classes |
|---|---|
| `lib/models/race_model.dart` | `Race` — includes `recommendPercent`, `lightningBolt` (⚡ badge) |
| `lib/models/review_model.dart` | `Review`, `Attendance`, `AttendanceStatus` (`going` / `attended` / `interested`) |
| `lib/models/user_model.dart` | `AppUser`, `ActivityItem`, `Follow`, `FollowStatus` |

### Services
| File | Purpose |
|---|---|
| `lib/services/app_provider.dart` | Central state — auth, `currentUser`, `followingUids`, `setAttendance`, `submitReview`, `toggleFollow`, `uploadProfilePhoto` |
| `lib/services/race_service.dart` | `ensureRace()`, `setAttendance()`, `removeAttendance()`, `submitReview()`, `attendancesForUsers()`, `_recalcRaceStats()` |
| `lib/services/follow_service.dart` | `follow()`, `unfollow()`, `getPals()` + **`palsStream()`** (reactive mutual-follow), **`searchUsers()`** (client-side case-insensitive `contains`, 30s cache), `pendingRequests()` (no orderBy — sorts client-side), `acceptRequest()`/`rejectRequest()`, `getFollowStatus()`, `followingUsers()`, `followerUsers()` |
| `lib/services/auth_service.dart` | Google Sign-In, `updateProfile()` |
| `lib/services/places_service.dart` | Loads `assets/uk_places.json`; `PlacesService.search()` type-ahead (place → coords) for Discover. Offline, free. |
| `lib/services/google_calendar_service.dart` | Google Calendar integration (export) |

### Other
| File | Purpose |
|---|---|
| `lib/main.dart` | App entry, Firebase init |
| `lib/theme.dart` | `AppTheme` — colours, text styles (note: Calendar pals colour `_palColor` teal `#22D3EE` is local to calendar_screen) |
| `lib/widgets/shared_widgets.dart` | `UserAvatar`, `RaceCard`, shared UI components |
| `lib/utils/geo.dart` | `milesBetween()` — haversine distance in miles for radius search |
| `lib/firebase_options.dart` | Firebase config (auto-generated, committed) |

---

## Data Assets

| File | Contents |
|---|---|
| `assets/parkruns_uk.json` | 884 UK parkruns — `id, name, location, lat, lng` |
| `assets/findarace_uk.json` | ~1,190 UK races — `name, url, startDate, city, lat, lng, price, description` |
| `assets/major_races_uk.json` | 55 major UK races 2026–2027 — `name, city, lat, lng, startDate, url, price` (price is a **string**, e.g. `"From £60"`, not a number) |
| `assets/uk_places.json` | ~120 UK towns/cities — `name, lat, lng`. Gazetteer for Discover location search (place → coords). Starter set; expandable. |

### Map markers
- Green = parkruns
- Orange = findarace events
- Yellow = community-added (Firestore)
- Major races come from `major_races_uk.json`, rendered as orange markers alongside findarace events

### Deterministic race IDs
- Parkruns: `pr_${parkrunId}_${yyyyMMdd}`
- Findarace events: `fa_${slug}`
- Major races: `mr_${slug}`
- Community races: UUID (from `add_race_screen.dart`)

---

## Firestore Structure

```
races/{raceId}
  name, lat, lng, date, type, creatorUid
  reviewCount, averageRating, recommendPercent, lightningBolt, attendeeCount

attendances/{uid}_{raceId}
  uid, raceId, status (going/attended/interested), date

reviews/{reviewId}
  raceId, uid, rating, text, recommend, visibility (public/followers_only)

users/{uid}
  displayName, photoUrl, bio, racesCount, followersCount, followingCount

follows/{followerId}_{targetId}
  followerUid, targetUid, createdAt

follow_requests/{requestId}
  requesterUid, targetUid, status

activity/{activityId}
  type, actorUid, targetUid, raceId, timestamp
```

---

## Firebase / Firestore Rules

- Races: creator can edit; any signed-in user can update aggregate fields only
- Reviews: public visible to all; followers-only visible to followers; owner can edit/delete
- `follow_requests` read rule has `resource == null ||` guard (needed for non-existent doc reads — bug was fixed in v0.2.5)
- Deploy rules: `firebase deploy --only firestore:rules --project racepal-ae334`
- Deploy storage rules: `firebase deploy --only storage --project racepal-ae334`

### Storage rules (`storage.rules`)
```
match /profile_photos/{userId}.jpg {
  allow read: if true;
  allow write: if request.auth != null && request.auth.uid == userId;
}
```

---

## Current Release State (v0.2.10-beta)

### New in v0.2.10-beta
- **Follow requests visible again** — `pendingRequests` dropped the `.orderBy('createdAt')` that needed a missing `(targetUid+createdAt)` composite index (it sorts client-side now). Requests show in the **Feed bell** (top-right), not on the profile.
- **Pals list reactive** — new `FollowService.palsStream(uid)` (combines following + followers streams via a StreamController) replaces the one-shot `getPals` future in the Pals tab + profile count, so it updates live after a follow / follow-back.

### New in v0.2.9-beta
- **Name search restored** — Discover has a "search by race/parkrun name" box again, alongside location+radius (a name query searches everything, ignoring radius).
- **Pal search fixed** — `searchUsers` now matches first OR last name, case-insensitive (client-side `contains` over a 30s-cached user list; was a case-sensitive prefix-only query).

### New in v0.2.8-beta
- **Discover = location + radius search** — type a town (offline UK-towns gazetteer), set a radius slider, results **sorted by distance** (finds nearby towns name-search missed), addresses shown, radius circle on map. Replaces name-only search.
- **Calendar colour-coded** — dropped Me/Pals tabs; mine (purple) + pals (teal) shown together; pals shown with **their avatars** (variant C). List + month views.
- **Profile tappable counts** — Races (completed, derived from attendances) / Pals / Reviews open their lists. Dead `racesCount` field no longer used for the count.

### Earlier — v0.2.7-beta
- Parkrun ratings & reviews via stable venue doc `pr_<id>`; follow "Could not update" rules fix; in-app follow requests (Feed bell)

### What's working
- Discovery: Parkruns / Races tabs + search, list (default) ↔ map toggle (list avoids Maps tile charges)
- Parkrun markers (884), findarace events, major UK races
- Month filter on Races tab (all data loaded, filtered client-side)
- Parkrun "I'm doing this" — date picker for any of next 16 Saturdays
- Parkrun reviews/ratings on the venue page
- Attendance: Going / Attended / Not going (any race, any time)
- Profile photo upload (camera or gallery) → Firebase Storage ✅ live
- Profile edit (name, bio, photo)
- Reviews with star rating + recommend flag + lightning bolt badge
- Follow / unfollow / follow-back in Pals; follow requests via Feed bell
- Google Sign-In
- Feed screen (activity from followed users)
- Calendar with Pals toggle + month picker
- Pals shown on race detail (avatar, name, Going / Been here status)

### Project docs (root of repo)
| File | Purpose |
|---|---|
| `CONTEXT.md` | Technical brief for Claude — start each session with "Read CONTEXT.md" |
| `BACKLOG.md` | Prioritised outstanding work — kept up to date as work is done |
| `USE_CASES.md` | Full list of app use cases |
| `PROJECT_DESCRIPTION.md` | One-paragraph product vision |
| `PROJECT_INSTRUCTIONS.md` | How Claude should work on this project |

### Known pending items
See [BACKLOG.md](BACKLOG.md) for the full prioritised list.

---

## Dev Commands

```powershell
# Build release APK
cd c:\Users\maldo\.claude\racepal
flutter build apk --release

# Install on Pixel 9
adb -s 46140DLAQ0047E install -r build\app\outputs\flutter-apk\app-release.apk

# Run in debug mode on device
flutter run -d 46140DLAQ0047E

# Deploy Firestore rules
firebase deploy --only firestore:rules --project racepal-ae334

# Deploy Storage rules (only after Storage is enabled in console)
firebase deploy --only storage --project racepal-ae334

# Check outdated packages
flutter pub outdated

# Publish a GitHub Release (gh CLI is installed & authenticated)
gh release create v0.2.x-beta "build\app\outputs\flutter-apk\app-release.apk#RacePal-v0.2.x-beta.apk" --title "v0.2.x-beta" --notes "..."
```

---

## Key Design Decisions / Gotchas

- **Price field in JSON is a string** — `major_races_uk.json` uses `"From £60"` not a number. The `_EventPanel` on the map handles this: `price is num ? '£${price.toStringAsFixed(0)}' : price.toString()`
- **No Play Store** — APK is sideloaded. Distributed via GitHub Releases, published by Claude using the `gh` CLI (installed & authenticated as `maldonadocintia-code`) — **not manual upload**. `gh release create v<ver> <apk>#<nice-name>.apk --notes ...`
- **Maps billing** — ~$0.007 per map load. $200/month free tier (recurring, separate from $300 trial credit). List view loads zero tiles. Budget alert: Google Cloud Console → Billing → Budgets & alerts.
- **`ensureRace()`** — Creates a Firestore race doc on demand with a deterministic ID when a user taps "I'm doing this" on a parkrun/event. Prevents duplicates.
- **Pals = mutual follows** — implemented as set intersection in `followService.getPals()`. Not stored as a separate collection.
- **`lightningBolt`** — set to `true` on a race when `recommendPercent >= 80` AND `reviewCount >= 10`. Shown as ⚡ badge on race cards.
- **Maps API key** — lives only in `android/local.properties` (gitignored). Never commit it.
- **`AttendanceStatus`** is in `lib/models/review_model.dart` (not race_model) — slightly non-obvious.

---

## Google Cloud / Billing

- Project: `racepal-ae334` on Google Cloud
- Maps API key restricted to package `com.racepal.app`
- Currently on $300 / 90-day free trial — cannot be charged during trial
- After trial: if not upgraded, Maps go grey (no charge); if upgraded to paid, budget alert needed
- Set alert: Cloud Console → Billing → Budgets & alerts → Create budget → ~£10 threshold
