# Ours — Setup Guide

A native iPhone app for two people. Dark UI, coloured category cards, real-time CloudKit sync.

---

## 1. Create the Xcode Project

1. Open **Xcode → File → New → Project**
2. Choose **iOS → App**
3. Fill in:
   - **Product Name:** `Ours`
   - **Bundle Identifier:** `com.yourname.ours` (pick anything — must be unique)
   - **Interface:** SwiftUI
   - **Language:** Swift
4. Save the project **inside** the `/Users/mahe/Ours/` folder (so the project sits at `Ours/Ours.xcodeproj`)
5. Delete Xcode's generated `ContentView.swift`

---

## 2. Add the Source Files

Drag the entire `Ours/` source folder into Xcode's Project Navigator (the left sidebar).

When prompted, make sure **"Copy items if needed"** is **unchecked** (the files already live in the project folder) and **"Add to target: Ours"** is checked.

The files you're adding:

```
OursApp.swift
Models/AppModels.swift
Services/CloudKitService.swift
ViewModels/AppViewModel.swift
Views/HomeView.swift
Views/CategoryView.swift
Views/SubcategoryView.swift
Views/AddSubcategorySheet.swift
Views/AddItemSheet.swift
Views/ProfileSetupView.swift
Extensions/Color+Hex.swift
```

---

## 3. Configure Your Apple Developer Account

1. In Xcode, select the **Ours** project in the Navigator
2. Select the **Ours** target → **Signing & Capabilities**
3. Set your **Team** (requires a free or paid Apple Developer account)
4. Xcode auto-fills the bundle ID

---

## 4. Add Capabilities

Still in **Signing & Capabilities**, click **+ Capability** and add:

| Capability | Setting |
|---|---|
| **iCloud** | Check **CloudKit**, then click **+** under containers and add `iCloud.com.yourname.ours` (match your bundle ID) |
| **Push Notifications** | (just add it — no config needed) |
| **Background Modes** | Check **Remote notifications** |

---

## 5. Update the Container Identifier

Open `Services/CloudKitService.swift` and replace the constant at the top:

```swift
private let kContainerID = "iCloud.com.yourname.ours"
```

Use the **exact same string** you entered in step 4.

---

## 6. Set Up CloudKit Schema (automatic)

CloudKit creates record types automatically on first use. The app seeds the 5 categories on first launch.

To inspect data: go to [CloudKit Console](https://icloud.developer.apple.com/), choose your container, and open **Data → Public Database**.

---

## 7. Build & Run

- **Simulator:** Most features work, but push notifications (real-time sync trigger) require a real device.
- **Real device:** Sync works fully. Both partners need to run the app at least once for their profiles to appear.

---

## How Sync Works

- All data lives in the **CloudKit public database** — both devices read/write to the same store.
- On launch the app registers **CloudKit subscriptions** for each record type.
- When your partner changes anything, CloudKit sends a silent push notification; the app fetches the latest data and updates the UI.
- No accounts or logins needed — the app is private by virtue of only being on your two phones.

---

## Two Iphones Setup

1. Install the app on both iPhones (via Xcode, TestFlight, or direct install)
2. Each person enters their name and picks an emoji on first launch
3. Within seconds, each person's profile appears on the other's phone
4. All lists and items sync in real time

---

## Project Structure

```
Ours/
├── OursApp.swift              App entry, AppDelegate (push notifications)
├── Models/
│   └── AppModels.swift        OursCategory, OursSubcategory, ListItem, UserProfile
├── Services/
│   └── CloudKitService.swift  All CloudKit read/write/subscribe operations
├── ViewModels/
│   └── AppViewModel.swift     ObservableObject; drives all UI state
├── Views/
│   ├── HomeView.swift         Home screen + CategoryCard + ProfileSheet
│   ├── CategoryView.swift     Category detail + SubcategoryRow
│   ├── SubcategoryView.swift  Item list + ListItemRow (checkbox, notes, link)
│   ├── AddSubcategorySheet.swift
│   ├── AddItemSheet.swift
│   └── ProfileSetupView.swift First-launch name + emoji picker
└── Extensions/
    └── Color+Hex.swift        Color(hex:) + app palette constants
```

---

## Roadmap (already in mind, not yet built)

- [ ] AI shopping suggestions based on purchase history
- [ ] Shared budget tracking under Finance
- [ ] Discover subcategories: Movies, Series, Games, Places
- [ ] Swedish localisation (`Localizable.strings`)
- [ ] Widget for quick shopping list access
