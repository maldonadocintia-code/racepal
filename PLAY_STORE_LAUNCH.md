# RacePals — Play Store Launch Guide (closed testing)

Step-by-step to get RacePals onto the Play Store as a **closed test** for feedback.
Code work (account deletion, consent, privacy policy, signing config) is **done** —
this is the checklist of things **you** do, plus the bits Claude can finish for you.

Legend: 👤 = you do it · 🤖 = ask Claude to do it · ⚠️ = important

---

## 0. One-time costs
- **Google Play developer account: $25, one-time.** The only cost. Everything else is free.

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

## 3. Host the privacy policy (free) 👤
The policy lives at `docs/privacy.html`. To publish it on GitHub Pages:
1. On GitHub: **Settings → Pages**.
2. Source: **Deploy from a branch**, Branch: **master**, Folder: **/docs**. Save.
3. After a minute it's live at:
   **https://maldonadocintia-code.github.io/racepal/privacy.html**
   (this URL is already wired into the app's login + profile links).
4. ⚠️ **Edit `docs/privacy.html`** and replace the highlighted placeholders:
   - `[YOUR FULL NAME]` — the data controller (you).
   - `[YOUR CONTACT EMAIL]` — a real email you'll monitor for deletion requests.

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

## Recap of what's already done in code
- ✅ In-app **account deletion** (Me tab → Delete account) — wipes profile, photo,
  reviews, race history, Pals, activity, then the auth account.
- ✅ **Consent notice** + Privacy Policy link on the login screen.
- ✅ **Privacy Policy** page (`docs/privacy.html`) — needs your name + email filled in.
- ✅ **Firebase Analytics dropped** (no analytics-consent burden).
- ✅ **Release signing config** wired to `key.properties`.
- ✅ Firestore **rule** for self-deletion of the user doc (needs deploy — step 4).
