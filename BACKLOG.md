# RacePal — Outstanding Work

Effort: **S** = a few hours · **M** = a day or two · **L** = multiple sessions

---

## Priority 1 — Complete the core concept

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| 1 | Profile photo (unblock) | Enable Firebase Storage in console (2 clicks), then deploy rules. Code is ready. | S | ✅ Done |
| 2 | Show pals on race detail | Core to the concept — show which pals have done this race | M | ✅ Done |
| 3 | Distance filter on search | Runners think in distances (5K, 10K, half, marathon) — needed for discovery. NOTE: unreliable name-matching distance chips were **removed** in the discovery-screen simplification (option C). A proper distance filter (using real distance data) is still wanted later. | M | 📋 Not started |
| 6 | Parkrun ratings & reviews | Parkruns must be reviewable/rateable like races. Gotcha: parkrun attendance is per-Saturday (`pr_{id}_{date}`), so reviews would fragment across dates. Plan: aggregate reviews on a stable venue-level doc `pr_{id}` while keeping per-Saturday attendance for the calendar. | M | 🔨 In progress |

## Priority 2 — Polish

| # | Item | Notes | Effort | Status |
|---|---|---|---|---|
| 4 | Profile page cleanup | Remove clutter, make it sleek | S | 📋 Not started |
| 5 | README update | Out of date — mentions screens and features that no longer exist | S | 📋 Not started |
| 7 | Font size consistency | Text sizes are inconsistent across screens — needs a consistent type scale (e.g. defined sizes in `theme.dart` and applied everywhere). | S | 📋 Not started |

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
