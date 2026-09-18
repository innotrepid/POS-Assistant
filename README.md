# POS-Assistant

A Flutter-based Point of Sale (POS) Assistant application.

## Getting Started

This project is the foundation for the POS Assistant app.

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK

### Setup

```bash
git clone https://github.com/innotrepid/POS-Assistant.git
cd POS-Assistant
git checkout foundation
flutter pub get
flutter run
```

### Project Structure

```
POS-Assistant/
├── .github/workflows/
│   └── ci.yml             # GitHub Actions CI
├── lib/
│   └── main.dart          # App entry point
├── test/
│   └── widget_test.dart   # Basic tests
├── pubspec.yaml           # Dependencies
├── analysis_options.yaml  # Linter rules
└── README.md
```

## Continuous Integration

GitHub Actions runs on every push and pull request to `main` and `foundation`:

- Checkout code
- Setup Flutter (stable)
- `flutter pub get`
- Format check (`dart format`)
- Static analysis (`flutter analyze`)
- Unit/widget tests (`flutter test`)

Workflow file: [`.github/workflows/ci.yml`](.github/workflows/ci.yml)

## Foundation Branch

This branch contains the initial Flutter project scaffolding.
