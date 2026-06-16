# RacePal — Outstanding Work

Effort: **S** = a few hours · **M** = a day or two · **L** = multiple sessions

---

## Bugs

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| B1 | Can't reach map / view toggle not visible | Map/List toggle now an explicit button in the Discover header. | S | ✅ Resolved (v0.2.8) |

---

## Priority 1 — Complete the core concept

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| 1 | Profile photo (unblock) | Enable Firebase Storage in console (2 clicks), then deploy rules. Code is ready. | S | ✅ Done |
| 2 | Show pals on race detail | Core to the concept — show which pals have done this race | M | ✅ Done |
| 3 | Distance filter on search | Runners think in distances (5K, 10K, half, marathon) — needed for discovery. NOTE: unreliable name-matching distance chips were **removed** in the discovery-screen simplification (option C). A proper distance filter (using real distance data) is still wanted later. | M | 📋 Not started |
| 6 | Parkrun ratings & reviews | Reviews aggregate on a stable venue doc `pr_{id}`; per-Saturday attendance kept for the calendar. | M | ✅ Done (v0.2.7) |
| 10 | Region/radius search ("near Manchester within 10 mi") | Done: typed location (assets/uk_places.json gazetteer) + radius slider, results sorted by distance. Supersedes #3. Follow-up: expand the towns list as needed. | M | ✅ Done (v0.2.8) |
| 11 | Add Run North West Races data | Add Run North West (NW England race organiser) events to the dataset — needs name, date, location, coords per event. Data-sourcing task. | M | 📋 Not started |

## Priority 2 — Polish

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| 4 | Profile page cleanup | Remove clutter, make it sleek | S | 📋 Not started |
| 5 | README update | Out of date — mentions screens and features that no longer exist | S | 📋 Not started |
| 7 | Font size consistency | Text sizes are inconsistent across screens — needs a consistent type scale (e.g. defined sizes in `theme.dart` and applied everywhere). | S | 📋 Not started |
| 8 | Follow-back on requests/new followers | When a new follower (or follow-requester) isn't followed back yet, show a "Follow back" action in the follow-requests sheet (Feed bell) — ideally Accept + follow-back in one tap to become Pals instantly. (Followers tab already has follow-back since v0.2.5.) | S | 📋 Not started |
| 9 | Calendar/Profile load performance | Calendar re-fetches every race one-by-one on every redraw (slow + burns Firestore reads); Profile reloads Pals on every redraw. Cache lookups / create futures once. (Map stream fix already shipped v0.2.7.) | S | 📋 Not started |

---

## GDPR

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| G1 | Account deletion | User must be able to delete their account and all their data (profile, reviews, attendances, follows, activity feed entries, profile photo). Required by GDPR before opening to the public. | M | 📋 Not started |

---

## Parkrun special dates (Christmas Day / New Year's Day)

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| P1 | parkruns on special days | Many parkruns run on Christmas Day and New Year's Day, not just Saturdays — but `parkruns_uk.json` has no schedule data (only name/location/coords), and which parkruns run those days varies each year. Needs a data source before it can be modelled. Out of scope for MVP. | M | 📋 Not started |

---

## Parked — built but not exposed yet

| Item | Notes |
|---|---|
| Google Calendar export | `lib/services/google_calendar_service.dart` is written but not wired to any button. Add a UI entry point once the app is more mature. |

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
