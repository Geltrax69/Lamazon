# Lamazon

Amazon-style shopping app built with Flutter.

## 📲 Download

[![Build APK](https://github.com/Geltrax69/Lamazon/actions/workflows/build-apk.yml/badge.svg)](https://github.com/Geltrax69/Lamazon/actions/workflows/build-apk.yml)

**[⬇️ Download the latest APK](https://github.com/Geltrax69/Lamazon/releases/latest/download/app-release.apk)**

This link always serves the newest build — every push to `main` automatically
rebuilds the APK and replaces it, so re-downloading gives you the updated app.

## Run from source

```bash
flutter pub get
flutter run
```

## Structure

```
lib/
  main.dart              app entry + theme
  models/product.dart    Product / Category models
  data/catalog.dart      paste image/product links here — the UI renders them
  screens/home_screen.dart
  widgets/product_card.dart
```
