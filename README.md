# Open Library Reader

A Flutter application for reading books from Open Library and Internet Archive.

## Features

- Browse and manage books on your Open Library shelves
- Search for books across OpenLibrary's catalog
- Read books directly from Internet Archive
- Create and manage reading lists
- Track book loans and borrowing

## Architecture

This project implements **Clean Architecture** with strict separation between domain, data, and presentation layers. See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation.

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / Xcode for mobile development
- An Open Library account

### Installation

1. Clone the repository:
```bash
git clone https://github.com/mheiman/openlibrary_reader
cd openlibrary_reader
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate code (for dependency injection and serialization):
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Android Signing Setup

For release builds, you'll need to configure Android signing:

1. Create a keystore file (or use an existing one)
2. Copy `android/key.properties.example` to `android/key.properties`
3. Update `android/key.properties` with your keystore details:
```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=YOUR_KEY_ALIAS
storeFile=/path/to/your/keystore.jks
```

**⚠️ Never commit `key.properties` or keystore files to version control!**

### Running the App

```bash
# Run in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>

# Build release APK
flutter build apk --release
```

## Development

### Code Generation

After modifying files with `@injectable`, `@freezed`, or `@JsonSerializable` annotations:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Analysis

```bash
flutter analyze
```

### Testing

```bash
flutter test
```

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture and development guide

## License

GPL-3.0 license
