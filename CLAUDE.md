# Fellowship — Setup Guide for Claude

Fellowship is a private shared app for couples. It syncs shopping lists, recipes, trips, and budgets in real time between two phones using Firebase Firestore. Built in SwiftUI (iOS 17+).

This file is written for Claude Code. Read it fully before starting, then walk the user through each step in order. Do not skip steps — each one is a dependency for the next.

---

## Overview of what needs to be done

1. Create a Firebase project (the backend — free)
2. Update the bundle identifier (unique to their Apple Developer account)
3. Replace GoogleService-Info.plist with their own
4. Apply Firestore security rules
5. Build and deploy to both phones via Xcode Cloud + TestFlight

Total time: ~1 hour. Most of it is waiting for Xcode Cloud to build.

---

## Step 1 — Firebase project

The user must do this manually in a browser. Guide them through each sub-step:

1. Go to [console.firebase.google.com](https://console.firebase.google.com) → **Add project**
2. Name it anything (e.g. "fellowship") → disable Google Analytics → Create
3. Once inside: click **Add app → iOS (the Apple icon)**
4. For **iOS bundle ID**: use `com.YOURNAME.fellowship` — they'll need to decide this now, it must match Step 2
5. Download the `GoogleService-Info.plist` file — keep it handy
6. Skip the remaining Firebase setup steps (no need to add the SDK — it's already in the project)
7. Back in Firebase Console: **Firestore Database → Create database → Start in production mode** → choose a region close to them (e.g. `europe-west` for Europe)

---

## Step 2 — Bundle identifier

1. Open `Ours.xcodeproj` in Xcode
2. Click the **Ours** target in the left sidebar → **General** tab
3. Change **Bundle Identifier** to match exactly what they used in Step 1 (e.g. `com.YOURNAME.fellowship`)
4. Do the same under **Signing & Capabilities** if it appears separately

---

## Step 3 — Replace GoogleService-Info.plist

1. In Finder, drag the downloaded `GoogleService-Info.plist` into the root of the project folder
2. Replace the existing placeholder file when prompted
3. In Xcode, verify the file appears in the project navigator (it should already be referenced)

---

## Step 4 — Firestore security rules

In Firebase Console → **Firestore Database → Rules**, replace everything with:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if false;
    }
    match /pairings/{code} {
      allow read: if request.time < resource.data.createdAt + duration.value(24, 'h');
      allow create: if request.resource.data.keys().hasAll(['createdBy', 'createdAt']) && code.size() == 6;
      allow update, delete: if false;
    }
    match /couples/{coupleID}/{subcollection}/{docId} {
      allow read, write: if coupleID.size() == 6;
    }
  }
}
```

Click **Publish**. Without this step the app will not sync.

---

## Step 5 — Xcode Cloud setup

This requires an Apple Developer account ($99/year). Without it, they can still build and run locally on their own device via Xcode, but not deploy to both phones wirelessly.

1. In Xcode: **Product → Xcode Cloud → Create Workflow**
2. Follow the prompts to connect to App Store Connect
3. Set the workflow to trigger on **Branch Changes → main**
4. Under **Actions → Archive - iOS → Distribution Preparation**: select **"App Store Connect"**
   - ⚠️ This is critical. "TestFlight (Internal Testing Only)" produces builds that cannot be selected for App Store submission and are harder to manage. Always use "App Store Connect".
5. Add a **Post-Action → TestFlight Internal Testing**
   - Create a new group (e.g. "Familj") and add both users' Apple IDs
6. Push any change to `main` to trigger the first build (takes ~15 min)
7. Both users install **TestFlight** from the App Store, accept the invite, and install Fellowship

---

## How the app works

- On first launch, one person creates a profile (picks an emoji, enters a name) and receives a **6-character couple code**
- The other person enters that code on their first launch to pair
- All data syncs in real time — no manual refresh needed
- The couple code is the only "authentication" — keep it private

### Categories
- **Shopping** — shared shopping lists with items
- **Resor** — trip planning with blocks (notes, budget, shopping lists)
- **Ekonomi** — budget tracking with income/expense blocks
- **Koder & Info** — freeform notes and codes (WiFi passwords, PINs, etc.)
- **Discover** — general lists
- **Recept** — recipes, importable via URL, photo (OCR), or manual entry

---

## Known pitfalls

- **Distribution Preparation must be "App Store Connect"** in the Xcode Cloud workflow — not "TestFlight (Internal Testing Only)". This is the single most common setup mistake and causes all App Store builds to be unselectable. See Step 5.
- **Bundle ID must match Firebase exactly** — a mismatch causes Firebase to silently fail on launch
- **Firebase Spark plan (free) does not include Storage in all regions** — photo storage in this app uses base64 blobs stored directly in Firestore to avoid this. This works fine for a small number of photos but is not efficient at scale.
- **App Review takes 24–48 hours** for the first submission. TestFlight builds are available immediately after Xcode Cloud finishes.
- **Build numbers increment automatically** via Xcode Cloud. Don't manually edit `CURRENT_PROJECT_VERSION`.
- **The UI is in Swedish** — all strings in the Views folder. Easy to change but not extracted to a localisation file yet.
- **Pairing codes expire after 24 hours** (enforced by Firestore rules) — if the second person doesn't pair in time, the first person needs to generate a new code from Profile settings.

---

## Tech stack

- SwiftUI (iOS 17+), no UIKit
- Firebase Firestore for real-time sync (Swift Package Manager, no CocoaPods)
- Firebase SDK 12.x
- Xcode Cloud for CI/CD
- No third-party UI libraries

## Project structure

```
Ours/
  Models/          — data models (OursCategory, OursSubcategory, OursItem, etc.)
  ViewModels/      — AppViewModel (single source of truth, @MainActor)
  Views/           — all SwiftUI views
  Services/        — Firebase sync, recipe import, photo handling
  Fonts/           — Cormorant Garamond, JetBrains Mono
```

---

## App Store submission (optional, for permanent install without TestFlight)

TestFlight builds expire after 90 days. For a permanent install, submit to the App Store:

1. In App Store Connect, the Xcode Cloud workflow (with "App Store Connect" distribution) produces builds eligible for submission
2. Required fields: Description, Keywords, Support URL, Screenshots (6.5" slot, 1284×2778px), Privacy Policy URL, Category, Pricing (Free), Content Rights, Copyright
3. App Privacy: "Data Not Collected" is accurate for this app
4. Age Rating: complete the questionnaire (all answers are "No" / "None")
5. Review takes 24–48 hours. After approval the app is permanently available via a direct App Store link (can be kept unlisted)
