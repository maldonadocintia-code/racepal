# RacePals — Play Store Launch Guide (closed testing)

Step-by-step to get RacePals onto the Play Store as a **closed test** for feedback.
Code work (account deletion, consent, privacy policy, signing config) is **done** —
this is the checklist of things **you** do, plus the bits Claude can finish for you.

Legend: 👤 = you do it · 🤖 = ask Claude to do it · ⚠️ = important

---

## 0. One-time costs
- **Google Play developer account: $25, one-time.** The only cost. Everything else is free.
- **iOS is deliberately not shipped** — see "iPhone / web users" below. (Apple's program is $99/year, recurring, with no free tier — avoided.)

---

## iPhone / web users (no Apple $99/yr)

**Decision (June 2026): launch the first closed test Android-only; do NOT pay for iOS.**

Why this is fine for a *social* app: the pals graph lives in **Firestore**, not on the device. Any client that talks to the same Firebase project shares one graph/Feed/reviews — platform never splits the *data*, only which *client* a person can run.

**There is no free native-iOS path:**
- TestFlight requires the **$99/year Apple Developer Program**.
- Xcode free-sideloading expires after **7 days** + needs a Mac/cable per device — impractical for testers.

**The free workaround when iPhone users are actually needed: a Flutter Web / PWA build.**
1. `flutter build web` → host on **Firebase Hosting** (free tier, already in the project).
2. iPhone users open the URL in Safari → **Share → Add to Home Screen** → full-screen app icon (PWA). No App Store, no Apple account, **$0**.
3. Same Firebase backend → iPhone web users and Android native users are **fully connected as pals**.

Effort, not money — an **M** task with caveats:
- **Google Sign-In on web** needs separate config (web client ID + authorized domains).
- **Maps**: `google_maps_flutter` doesn't run cleanly on web → on web, default to the **existing list view and hide the map toggle** (discovery works fine as a list; no new billing).
- Flutter web is heavier/less polished → needs its own test pass.
- iOS web push needs iOS 16.4+ *and* Home-Screen install — irrelevant while push is deferred.

**Sequencing:**
- **Now:** Android-only closed test (you pick the tester list — recruit Android users, sidestep the problem). $0.
- **Next, if an iPhone user must be included / when opening up:** ship the Flutter-web PWA. Still $0.
- **Only if it gains real traction:** native iOS via the $99/yr Apple program.

---

## 1. Generate your release signing key 👤 ⚠️
Google rejects debug-signed uploads. You need a release keystore. Run this once
(uses the JDK that ships with Flutter — `keytool` is on your PATH after Flutter setup):

```bash
keytool -genkey -v -keystore racepal-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias racepal
```

- It asks for a **password** and some name/org details (name/org can be anything sensible).
- Save the `.jks` file **outside the repo** (e.g. `C:\Users\maldo\keys\racepal-release.jks`).
- ⚠️ **BACK UP the keystore file AND the password** (password manager + a copy in your
  OneDrive). If you lose them you can't ship updates under the same upload key.

Then create `android/key.properties` (already gitignored — never commit it):

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=racepal
storeFile=C:/Users/maldo/keys/racepal-release.jks
```

> Use forward slashes in `storeFile` and an **absolute path**. Gradle picks this up
> automatically (see `android/app/build.gradle.kts`); with it present, release builds
> are signed with your real key. Without it, they fall back to debug signing.

---

## 2. Build the App Bundle 🤖
Play prefers an `.aab` (App Bundle), not an APK:

```bash
flutter build appbundle --release
#   → build/app/outputs/bundle/release/app-release.aab
```

(Once `key.properties` exists, this `.aab` is signed with your upload key.)

---

## 3. Host the privacy policy (free) ✅ DONE
The policy lives at `docs/privacy.html` and is **live on GitHub Pages** (enabled
2026-06-19, source: branch **master**, folder **/docs**):
   **https://maldonadocintia-code.github.io/racepal/privacy.html**
   (this URL is already wired into the app's login + profile links).
Placeholders are filled in — data controller **Cintia Maldonado**, contact
**cinmal1988@gmail.com**. Any future edit to `docs/privacy.html` auto-redeploys
on push to `master`.

---

## 4. Deploy the updated Firestore rules 🤖 ⚠️ (production)
Account deletion needs the new `users` delete rule. This is a **production deploy** —
confirm, then:

```bash
firebase deploy --only firestore:rules --project racepal-ae334
```

---

## 5. Create the app in Play Console 👤
1. Sign up at https://play.google.com/console ($25).
2. **Create app** → name "RacePals", language English (UK), **App**, **Free**.
3. Left nav → **Testing → Closed testing** → create a track → create a release →
   upload `app-release.aab`.
4. **Testers:** add an email list (or a Google Group) of your testers. They get an
   opt-in link to install from the Play Store.

> Closed testing has a much lighter review than full production and is the fastest
> route to real-device feedback.

---

## 6. Data Safety form 👤 (content below)
Play asks what data you collect. Declare:

| Data type | Collected? | Shared? | Why | Notes |
|---|---|---|---|---|
| Name | Yes | No | App functionality, account | From Google sign-in |
| Email address | Yes | No | Account management | From Google sign-in |
| Photos | Yes (optional) | No | App functionality | Profile photo |
| App activity (reviews, race history, Pals) | Yes | No | App functionality | User-generated |
| Location | **No** | — | — | You type a town name; no GPS/device location |

Also tick:
- **Data is encrypted in transit** — Yes (Firebase uses HTTPS).
- **Users can request data deletion** — Yes. Provide the deletion URL:
  **https://maldonadocintia-code.github.io/racepal/privacy.html** (the policy explains
  in-app deletion + the email route).
- Firebase/Google is a **service provider (processor)**, not third-party "sharing".

---

## 7. Content rating 👤
Fill the IARC questionnaire honestly:
- Category: **Social / Communication**.
- Yes: app has **social features / user interaction** and **user-generated content**
  (reviews). No violence, gambling, etc.
- Likely outcome: PEGI 3 / Everyone-ish (social UGC may nudge it slightly higher).

---

## 8. Store listing (minimum for closed testing) 👤
- **App name:** RacePals
- **Short description:** Discover UK races & parkruns, log your runs, and connect with running pals.
- **Full description:** (expand on the above — features: discover by location, calendar,
  reviews with ⚡ ratings, Pals.)
- **App icon:** 512×512 PNG.
- **Feature graphic:** 1024×500 PNG.
- **Screenshots:** 2–8 phone screenshots (grab from the Pixel 9).
- **Privacy policy URL:** the GitHub Pages link from step 3.

🤖 Claude can draft the short/full description text — just ask.

---

## 9. Google Calendar export — OAuth scope verification 👤 ⚠️ (deferred — do before public launch)

The "Add to Google Calendar" button (race detail) uses the sensitive scope
`https://www.googleapis.com/auth/calendar.events`. This needs a one-time
**OAuth verification** with Google — but **not yet**.

**Decision (June 2026): defer verification; run under the unverified-app grace for the closed test.**

Why we can wait:
- The OAuth consent screen is **In production** *on purpose* — Testing mode would
  (a) only let manually-listed test users sign in, and (b) expire refresh tokens
  every **7 days** (testers silently logged out weekly). Production avoids both, so
  **leave it In production.**
- A production app + a **sensitive** scope is what triggers Google's verification ask.
  But an unverified production app **still works for up to 100 users**, with a
  *"Google hasn't verified this app → Advanced → continue"* warning screen. That's
  fine for a closed test.
- So: the `calendar.events` scope was **added without submitting the verification
  form**. Testers click through the warning once.

⚠️ **Cost note (the recurring worry):** verifying a **sensitive** scope is **FREE** —
it's a review process (days to ~2 weeks, may ask for the privacy-policy URL, which is
already hosted). Only **restricted** scopes (Gmail, full Drive) need a *paid*
third-party security assessment. `calendar.events` is **sensitive, not restricted** —
**no payment, ever.**

**To do before opening to the public (not for the closed test):**
1. Google Auth Platform → **Verification Center** → start verification for the
   `calendar.events` scope.
2. Supply the privacy-policy URL (the GitHub Pages link from step 3) and a short
   justification ("let users add a race they're attending to their own calendar").
3. Wait for approval → the "unverified app" warning disappears for everyone.

Until then the feature is fully usable by your ≤100 closed testers.

---

## Recap of what's already done in code
- ✅ In-app **account deletion** (Me tab → Delete account) — wipes profile, photo,
  reviews, race history, Pals, activity, then the auth account.
- ✅ **Consent notice** + Privacy Policy link on the login screen.
- ✅ **Privacy Policy** page (`docs/privacy.html`) — name + email filled in, **live on GitHub Pages**.
- ✅ **Firebase Analytics dropped** (no analytics-consent burden).
- ✅ **Release signing config** wired to `key.properties`.
- ✅ Firestore **rule** for self-deletion of the user doc (needs deploy — step 4).
