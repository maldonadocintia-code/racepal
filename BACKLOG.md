# RacePal — Outstanding Work

Effort: **S** = a few hours · **M** = a day or two · **L** = multiple sessions

---

## Bugs

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| B1 | Can't reach map / view toggle not visible | Map/List toggle now an explicit button in the Discover header. | S | ✅ Resolved (v0.2.8) |
| B2 | Can't unfollow / unfollow option not visible | Pals model replaced follows; you remove a pal from their profile ("Pals ✓" → tap). | S | ✅ Resolved (v0.2.11 / v0.2.13) |
| B3 | Accepting a pal request crashes | Batch-deleting a non-existent reverse request denied the whole batch (rule read null `resource.data`). | S | ✅ Resolved (v0.2.14) |
| B4 | Race duplication on Explore | Skipped Firestore copies of bundled races (`createdBy == 'system'`). | S | ✅ Resolved (v0.2.15) |
| B5 | Race info wrong / "made up" (bad addresses, websites) | Root cause: findarace data had mislabelled city/address fields. Replaced bundled data with a curated, verified Manchester set. | M | ✅ Resolved (v0.2.15) |
| B6 | Ratings not showing next to curated races/parkruns in Explore | Asset rows hard-coded `rating: null`; the matching Firestore stats doc (deterministic id `fa_<slug>` / `pr_<id>`) was skipped. Now Explore looks up stats by id and shows the rating; also fixed the stream guard that only refreshed `_races` on a count change. **Caveat:** `upcomingRaces()` still loads ≤30 races (SC1), so ratings won't show for races beyond that until search is paginated. | S | ✅ Resolved |
| B7 | Post review slow + button hidden behind keyboard | Stats recalc + feed write now run in the background (sheet closes promptly); review sheet is scrollable so Post sits above the keyboard. | S | ✅ Resolved |
| B8 | Explore filter pills overflow / horizontal-scroll | In the v0.2.25 results header the Month/Distance/Type pills don't fit one row, so the third scrolls off-screen (hidden filter = bad UX). **Fix:** show the filter's *name* at rest (`Month` / `Distance` / `Type`) and its *value* only when active (`Jun 2026` / `10K` / `Races`); replace the horizontal `ListView` in `_pillsRow` (`map_screen.dart`) with a **`Wrap`** so an overflowing pill drops to a second line instead of hiding. | S | 📋 Not started |
| B9 | Map pins never update with filters | In **map view**, changing Distance (any value — confirmed multiple), and likely Month/Type, leaves stale/extra pins while the **list is correct** (e.g. Distance=Marathon → 3 pins, list shows 1). Cause: markers are maintained in a persistent `Set _markers` (rebuilt via `_rebuild()`) and handed to `GoogleMap` as the **same instance** each build — a known `google_maps_flutter` gotcha. **Fix:** derive markers from the same filtered `_buildResults()` the list uses and pass `GoogleMap` a **fresh** `Set.of(...)` each build so map & list can't disagree. | S | 📋 Not started |
| B10 | Reviews count not updating | The **reviews count isn't updating** (needs repro to confirm which surface — race detail "Reviews (N)", profile Reviews stat, and/or the race `reviewCount` aggregate). Likely in the stats-recalc path (`RaceService._recalcRaceStats` / `addReview`) or a stream/count not refreshing. **Investigate:** post a review and watch each count; check whether the aggregate write happens and whether the UI stream re-reads. | S | 📋 Not started |
| B11 | Calendar day panel caps runs/people at 2 + needs redesign | On **Plan** (`calendar_screen.dart`), selecting a day shows a max of **2** when more people are attending. **Wanted:** one **card per race** that day, then the **list of people attending** under it; show **all** races happening that day (no cap), with as many attendees as there are. **Design problem:** doing this naively means a lot of scrolling — needs a layout that scales (e.g. race card + collapsed/expandable attendee list with a count, or attendee avatars + "and N more"). Mock first. | M | 📋 Not started |

---

## Priority 1 — Complete the core concept

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| 1 | Profile photo (unblock) | Enable Firebase Storage in console (2 clicks), then deploy rules. Code is ready. | S | ✅ Done |
| 2 | Show pals on race detail | Core to the concept — show which pals have done this race | M | ✅ Done |
| 3 | Distance filter on search | Runners think in distances (5K, 10K, half, marathon) — needed for discovery. NOTE: unreliable name-matching distance chips were **removed** in the discovery-screen simplification (option C). A proper distance filter (using real distance data) is still wanted later. **Design chosen:** "Filters in a sheet" — a Filters button (with active-count badge) opening a bottom sheet with Radius / Type / Distance, plus a removable active-filter chip strip (keeps the Explore header to ~1 row). Mockups: `prototype/explore_option_a_mockup.html` (chosen) + `prototype/distance_filter_options.html` (A vs B compare). | M | ✅ Done (v0.2.24) — `lib/utils/distance.dart` + Explore filter sheet. Parkruns classed as 5K. Unbucketed types (5-mile, Trail, etc.) show only under "Any" — add a chip if such races become common. |
| 6 | Parkrun ratings & reviews | Reviews aggregate on a stable venue doc `pr_{id}`; per-Saturday attendance kept for the calendar. | M | ✅ Done (v0.2.7) |
| 10 | Region/radius search ("near Manchester within 10 mi") | Done: typed location (assets/uk_places.json gazetteer) + radius slider, results sorted by distance. Supersedes #3. Follow-up: expand the towns list as needed. | M | ✅ Done (v0.2.8) |
| 11 | Add Run North West Races data | Curated Manchester-area set added v0.2.15 (`assets/manchester_races.json`) incl. dated Run North West events. **Still pending:** their 3 undated 2027 races (Trafford 10K, Alderley Edge 10K, Quarry Bank Trail) — add once dates are published. | M | 🟡 Partly done (v0.2.15) |
| 12 | Pals friendship model | Replaced follow/follower/mutual + public-private with one symmetric "Pals" friendship (request → accept → pals both ways). In-app alerts via Feed bell + Feed-tab badge. Migration from legacy follows. | L | ✅ Done (v0.2.13–v0.2.14) |
| 14 | Explore "Find your next race" redesign | Reshape Explore around a search hub: a launcher (heading **"Find your next race or parkrun"** + three entry cards — **By location / By month / By distance**) that drops into a results list with that lens primed. Results header = location pill + radius **slider** (only shown once a place is set, so it never looks empty) + **Month / Distance / Type** filter pills. **New: Month filter** (the main fix for overwhelming result lists; parkruns are recurring so they match any month). Location is optional now — no place = browse by month/distance across the UK, tiles show a date chip instead of miles. **Distance pill disabled when Type=Parkruns** ("all parkruns are 5K"). Supersedes the v0.2.24 Filters-sheet header (which truncated the search bar + hid the slider on-device). Mockup: `prototype/explore_location_first_mockup.html`. Use Material icons, not emoji. | L | ✅ Done (v0.2.25) — `map_screen.dart` launcher + month filter + calm pills/tiles. Parkruns match any month; distance pill disabled under Parkruns. **Not yet eyeballed on device.** |
| 15 | First-run activation (no wizard) | Get new users to their activation moment via **empty-state CTAs + a dismissible "Get started" checklist** (☐ Find your first race ☐ Add a pal ☐ Add a photo), NOT a forced onboarding flow. Race-first (solo-achievable, core value), pals second (retention). Plan-empty → Explore launcher; Feed-empty → find pals. Single skippable welcome after sign-in OK; no multi-step gate. | M | 📋 Not started |

## Priority 2 — Polish

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| 4 | Profile page cleanup | Remove clutter, make it sleek | S | 📋 Not started |
| 5 | README update | Out of date — mentions screens and features that no longer exist | S | 📋 Not started |
| 7 | Font size consistency | 6-step type scale in `theme.dart` (`AppTheme.fsDisplay 20 / fsHeading 18 / fsTitle 16 / fsBody 14 / fsSecondary 13 / fsCaption 12`) applied across all screens; odd sizes (15/17/22/24) snapped to the scale. Intentional micro labels (10/11) and the 40px login hero left as-is. **Best confirmed on-device** (broad visual change). | S | ✅ Done |
| 8 | Follow-back on requests/new followers | When a new follower (or follow-requester) isn't followed back yet, show a "Follow back" action in the follow-requests sheet (Feed bell) — ideally Accept + follow-back in one tap to become Pals instantly. (Followers tab already has follow-back since v0.2.5.) | S | 📋 Not started |
| 13 | Surface filter (Road / Trail) | A terrain category, **separate from the distance axis** ("Trail" is not a distance — a Trail 10K and a Road 10K are both 10K). Would slot into the #3 filter sheet as a third "Surface" section + a removable chip. **Parked pending demand** — only build if testers ask for it. Needs a new `surface: road\|trail` field on every curated race + a rule for parkruns (most are mixed/park paths; likely just exclude parkruns from this filter). Prototyped then removed in `prototype/explore_option_a_mockup.html` history. | M | 🅿️ Parked (validate demand) |
| 9 | Calendar/Profile load performance | Calendar re-fetched every race one-by-one on every redraw (burned Firestore reads). **Fixed:** added a 2-min TTL race-doc cache in `RaceService.getRace` (busted on stat writes), and split `_MonthView` into a stateless loader + stateful `_MonthCalendar` so day-tap/month-change no longer re-runs the loader. Profile `getRace` calls now share the same cache. | S | ✅ Done (calendar; cost fix) |
| 16 | Export races to Google Calendar | Let a user add a race they're attending to their own Google Calendar. Wired: **"Add to Google Calendar"** button on race detail (dated races only — parkruns plan a specific Saturday separately) → `AppProvider.addRaceToCalendar` → `GoogleCalendarService` (reuses the existing Google sign-in, prompts for the `calendar.events` scope on first use). Scope **added to the production OAuth screen without submitting verification** — runs under the unverified-app grace (≤100 testers see a one-time warning). **OAuth verification deferred to before public launch** (free; sensitive not restricted scope — see PLAY_STORE_LAUNCH.md §9). **Still pending:** on-device test of the consent flow; optional follow-up = export a *planned parkrun date* from the Plan day panel. | S | 🟡 Wired — verification deferred, needs on-device test |

---

## Authentication

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| A1 | Email + password sign-up/sign-in | Let users join without a Google account. Firebase Auth `createUserWithEmailAndPassword` / `signInWithEmailAndPassword` (free). Needs: a sign-up form (email, password, display name), a sign-in form, and validation. Planned **fast-follow** after the closed-test launch. Deletion + consent already cover any provider. | M | 📋 Not started |
| A2 | Password reset | "Forgot password?" → `sendPasswordResetEmail` (free, Firebase sends the email). Needed alongside A1. | S | 📋 Not started |
| A3 | Email verification | Send a verification email on sign-up (`sendEmailVerification`); optionally gate some actions until verified. Reduces spam/fake accounts. | S | 📋 Not started |
| A4 | Username (display handle) | Optional: a unique @username separate from display name (for search / sharing). Needs a uniqueness check (a `usernames/{handle}` reservation collection). Decide if it's worth it for MVP. | M | 📋 Not started |
| A5 | Passkeys (parked) | Modern passwordless login. **Firebase Auth has no native passkey support** — needs Android Credential Manager wired to a custom backend (leaves the free tier). Revisit only if the app gains traction. | L | 🅿️ Parked |

## GDPR

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| G1 | Account deletion | In-app **Delete account** (Me tab) — re-auths via Google then wipes profile, photo, reviews, attendances, pals (both mirror docs), pal requests, activity, then the auth account. Needs the new `users` delete rule **deployed** (see PLAY_STORE_LAUNCH.md step 4). | M | ✅ Done (code) — rule deploy pending |
| G2 | Sign-up consent + privacy policy | Consent notice + Privacy Policy link on login; policy at `docs/privacy.html` — name/email filled, **live on GitHub Pages**. Firebase Analytics dropped to avoid analytics consent. | S | ✅ Done — hosted & live |
| G3 | Known limitation: stale race aggregates after deletion | Deleting a user's reviews/attendances leaves a race's `reviewCount`/`averageRating`/`attendeeCount` slightly stale (not recalculated). Acceptable for MVP; recalc on delete if it becomes visible. | S | 📋 Not started |

---

## Parkrun special dates (Christmas Day / New Year's Day)

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| P1 | parkruns on special days | Many parkruns run on Christmas Day and New Year's Day, not just Saturdays — but `parkruns_uk.json` has no schedule data (only name/location/coords), and which parkruns run those days varies each year. Needs a data source before it can be modelled. Out of scope for MVP. | M | 📋 Not started |

---

## Scale — before public launch

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| SC1 | Scalable search | `searchUsers` loads up to 500 user docs client-side; Plan's "add a race" search only sees the first 30 upcoming community races (`upcomingRaces` limit). Move both to tokenised/indexed search before opening to the public. | M | 📋 Not started |

---

## Safety / Moderation — before public launch

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| M1 | Report content (reviews) | A social app with user-generated reviews needs a way to flag/report inappropriate content, and for you to remove it. Google Play expects UGC moderation before public launch. OK to skip for trusted closed testers. | M | 📋 Not started |
| M2 | Block a user | Let a user block another so they can't pal-request or appear to them. Safeguarding basic for a stranger-connecting social app. Before public launch. | M | 📋 Not started |
| M3 | Onboarding: data-visibility notice | Make clear at sign-up that display name, photo, public reviews and attended races are visible to other signed-in users. Sets expectations / GDPR transparency. | S | 📋 Not started |

## Privacy / Security

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| PR1 | Audit legacy bypassed follows | Before v0.2.11 the `follows` rules let anyone create a follow to a private account (privacy was client-side only; now enforced server-side). Audit and clean any direct follows of private accounts created under the old rules. | S | 📋 Not started |
| PR2 | Unused `canViewUser` rule | `firestore.rules` defines `canViewUser()` but nothing references it — verify whether a collection should be gating reads to followers (possible privacy gap). | S | 📋 Not started |

---

## Chores

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| C1 | Delete Explore/Plan prototype | Remove throwaway `prototype/explore_plan_mockup.html` once the v0.2.12 Explore/Plan redesign is confirmed on-device. | S | 📋 Not started |

---

## Don't build for MVP

| Item | Reason |
|---|---|
| Country flags on profile | Doesn't test the core concept |
| Fav tune / fav distance on profile | Not relevant to race discovery |
| Review photos | Text + rating is enough to test the concept |
| International parkruns | UK is enough for MVP |
| In-app notifications | Useful later, not needed now |
| Auto-updating race data | Manual data is fine for MVP |
| Tests | Premature for MVP |

---

## Done

| Item | Version |
|---|---|
| Map crash on race tap | v0.2.5 |
| Map overcrowded / Add Race button hidden | v0.2.5 |
| List view to reduce Maps API cost | v0.2.5 |
| Follow button missing in search | v0.2.5 |
| Follow-back from Followers tab | v0.2.5 |
| Parkrun any-Saturday scheduling | v0.2.5 |
| Show pals on race detail | v0.2.6 |
| Profile photo upload | v0.2.6 |
| Simplified discovery screen (Parkruns/Races tabs + search) | v0.2.7 |
| Parkrun ratings & reviews (venue doc) | v0.2.7 |
| Follow bug fix ("Could not update" — rules) | v0.2.7 |
| In-app follow requests (Feed bell, Accept/Reject) | v0.2.7 |
| Map data stream created once (perf) | v0.2.7 |
| Discover: location + radius search (distance-sorted, addresses) | v0.2.8 |
| Calendar colour-coding (mine purple / pals teal + avatars, no tabs) | v0.2.8 |
| Profile: tappable Races/Reviews/Pals counts | v0.2.8 |
| Map/List toggle made explicit (B1) | v0.2.8 |
| Race-name search restored on Discover | v0.2.9 |
| Pal search by first/last name (case-insensitive) | v0.2.9 |
| Follow requests visible (dropped index-requiring orderBy) | v0.2.10 |
| Pals list reactive (palsStream) | v0.2.10 |
| Unfollow from Following/Pals lists; server-side privacy | v0.2.11 |
| Map→Explore, Calendar→Plan; tap-a-date add flow; Feed header cleanup; profile recent-activity removed | v0.2.12 |
| Pals friendship model (request/accept); app renamed RacePals; "Add new event" wording | v0.2.13 |
| Accept-pal crash fix; incoming-request badge on Feed tab | v0.2.14 |
| Curated Manchester race set (hid findarace/major); Explore dedup fix | v0.2.15 |
