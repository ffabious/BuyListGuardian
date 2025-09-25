# BuyListGuardian

A lightweight Flutter app for tracking the items you still need to buy. Add new entries, toggle them off when they’re handled, and swipe to remove them entirely. Everything is stored locally on the device, so your list is ready the next time you open the app.

## ✨ Features

- Quick-add dialog for new shopping items
- Checkbox toggle to mark items as “still needed” or “done”
- Swipe-to-delete with an extra delete button for accessibility
- Local persistence powered by [`shared_preferences`](https://pub.dev/packages/shared_preferences)

## 🚀 Getting started

```bash
flutter pub get
flutter run
```

## ✅ Tests

```bash
flutter test
```

## 📦 Data storage

Items are serialized as JSON and stored in `SharedPreferences` under the key `buylistguardian.items`. Deleting the app (or clearing app data) resets the list.
