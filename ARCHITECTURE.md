# ARCHITECTURE.md

This file provides guidance to developers and AI assistants when working with code in this repository.

## Project Overview

Open Library Reader is a Flutter application for reading books from Open Library and Internet Archive. It implements **clean architecture** with strict separation between domain, data, and presentation layers across 7 feature modules.

## Commands

### Development
```bash
# Install dependencies
flutter pub get

# Generate dependency injection and serialization code
flutter pub run build_runner build --delete-conflicting-outputs

# Watch mode for continuous code generation during development
flutter pub run build_runner watch

# Analyze code
flutter analyze

# Run app
flutter run

# Run on specific device
flutter run -d <device-id>
```

### Code Generation
After modifying files with `@injectable`, `@lazySingleton`, `@freezed`, or `@JsonSerializable` annotations, regenerate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## Architecture

### Clean Architecture Layers

Each feature follows a strict 3-layer structure:

```
features/<feature_name>/
├── domain/              # Business logic (pure Dart, no Flutter)
│   ├── entities/        # Business objects (extends Equatable)
│   ├── repositories/    # Abstract repository interfaces
│   └── usecases/        # Single-responsibility use cases
├── data/                # Data handling
│   ├── datasources/     # Remote (API) and Local (cache) data sources
│   ├── models/          # DTOs with JSON serialization
│   └── repositories/    # Repository implementations (converts exceptions to failures)
└── presentation/        # UI layer
    ├── pages/           # Full-screen widgets
    ├── widgets/         # Reusable components
    └── state/           # State management (Notifier + State classes)
```

### Key Architectural Patterns

**Dependency Injection**: GetIt + Injectable
- Services: `@lazySingleton` (lazy initialization)
- Notifiers: `@injectable` (fresh instances)
- Retrieve via: `getIt<ServiceType>()`
- **Always regenerate DI after adding new services**

**State Management**: ChangeNotifier pattern
- Each feature has a `Notifier` extending `ChangeNotifier`
- State classes represent different states (Initial, Loading, Loaded, Error)
- UI listens via `ListenableBuilder`
- Pattern:
  ```dart
  @injectable
  class FeatureNotifier extends ChangeNotifier {
    FeatureState _state = const FeatureInitial();
    FeatureState get state => _state;

    void _emit(FeatureState newState) {
      _state = newState;
      notifyListeners();
    }
  }
  ```

**Error Handling**: Either<Failure, T> from dartz
- Data sources throw `AppException` subclasses (ServerException, NetworkException, etc.)
- Repositories catch exceptions and return `Either<Failure, T>`
- Use cases validate inputs and return `Either<Failure, T>`
- UI handles via `.fold(onFailure, onSuccess)`

**Routing**: GoRouter
- Route definitions in `lib/core/router/app_router.dart`
- Route constants in `lib/core/router/app_routes.dart`
- Navigate via context extensions: `context.go()`, `context.push()`, `context.pop()`

## Critical Patterns

### Adding a New Feature

1. **Domain Layer** (no Flutter dependencies):
   - Create entities extending `Equatable`
   - Define repository interface (abstract class)
   - Implement use cases with `@lazySingleton` annotation
   - Validate inputs in use cases, return `Left(ValidationFailure(...))` for invalid inputs

2. **Data Layer**:
   - Create models with `@freezed` and `@JsonSerializable` annotations
   - Implement data sources (remote and/or local) with `@LazySingleton` annotation
   - Implement repository with `@LazySingleton(as: RepositoryInterface)` annotation
   - Convert data source exceptions to failures in repository:
     ```dart
     try {
       final result = await dataSource.fetch();
       return Right(result.toEntity());
     } on ServerException catch (e) {
       return Left(ServerFailure(e.message));
     } on NetworkException catch (e) {
       return Left(NetworkFailure(e.message));
     }
     ```

3. **Presentation Layer**:
   - Create state classes (Initial, Loading, Loaded, Error)
   - Implement notifier with `@injectable` annotation
   - Build UI using `ListenableBuilder` to react to state changes

4. **Register and Generate**:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

### Shelf Caching and Refresh Strategy

**Important**: The app uses per-shelf caching with automatic staleness checking:

- Shelves are cached individually with `lastSynced` timestamp
- Cache validity: 6 hours (defined in `ApiConstants.cacheValidityHours`)
- **Auto-refresh on navigation**: When user switches to a shelf tab, it checks staleness and refreshes if needed
- **Refresh button**: Only refreshes the currently visible shelf, not all shelves
- **Post-login refresh**: All shelves refresh after successful login
- **Never auto-refresh stale shelves** until user navigates to them

Key methods in `ShelvesNotifier`:
- `refreshShelf(shelfKey)` - Refresh single shelf
- `refreshShelfIfStale(shelfKey)` - Check staleness before refreshing
- `loadShelves(forceRefresh: bool)` - Load all shelves (with optional force)

### Authentication State Detection

`ShelvesNotifier` listens to `AuthNotifier` to detect logins:
- Only triggers full refresh on `Unauthenticated` → `Authenticated` transition
- Ignores `AuthInitial` → `Authenticated` (app startup)
- This prevents false login detection during hot restart

### Model-Entity Conversion

Models (data layer) have JSON serialization; entities (domain layer) are pure business objects:
```dart
// Model
@freezed
class ItemModel with _$ItemModel {
  const factory ItemModel({required String id}) = _ItemModel;
  factory ItemModel.fromJson(Map<String, dynamic> json) => _$ItemModelFromJson(json);
}

// Entity
class Item extends Equatable {
  final String id;
  const Item({required this.id});
  @override
  List<Object?> get props => [id];
}

// Conversion
extension ItemModelX on ItemModel {
  Item toEntity() => Item(id: id);
}
```

### Storage Keys (Backwards Compatible)

**SharedPreferences keys** (defined in `ApiConstants`):
- `moveReading` - Auto-move books to "currently-reading" on opening reader
- `showChrome` - Show system UI chrome in reader
- `keepAwake` - Keep screen awake while reading
- `coverSize` - Book cover width
- `sortOrder` - Default shelf sort order
- `shelfVisibility` - Which shelves are visible
- `showLists` - Show/hide Lists tab

**FlutterSecureStorage keys** (in `AuthRemoteDataSource`):
- `username` - User's login username
- `password` - User's login password
- `session_cookie` - OpenLibrary session cookie

**These keys match the previous app version for seamless upgrades.**

### Pagination Pattern

For paginated APIs (like search):
```dart
Future<void> loadMore() async {
  final currentState = _state as Loaded;
  if (!currentState.hasMore) return;

  _emit(Loading(isLoadingMore: true));

  final result = await useCase(page: currentState.page + 1);
  result.fold(
    (failure) => _emit(Error(failure.message)),
    (newData) {
      final combined = [...currentState.items, ...newData.items];
      _emit(Loaded(items: combined, page: newData.page));
    },
  );
}
```

## Network and API

**Base URLs** (from `ApiConstants`):
- OpenLibrary: `https://openlibrary.org`
- Internet Archive: `https://archive.org`

**HTTP Client**: Dio with interceptors for logging and error handling
- Timeout: 30 seconds (connection and receive)
- Automatic error conversion: `DioException` → `AppException` → `Failure`

**API Error Handling**:
- 401 → `UnauthorizedException` → `AuthFailure`
- 404 → `NotFoundException` → `NotFoundFailure`
- 5xx → `ServerException` → `ServerFailure`
- Network errors → `NetworkException` → `NetworkFailure`

## Common Issues

**"Unhandled Exception: The get_it instance has already been configured"**
- Run: `flutter pub run build_runner clean && flutter pub run build_runner build --delete-conflicting-outputs`

**State not updating in UI**
- Ensure `notifyListeners()` is called after state changes
- Check that `ListenableBuilder` is listening to the correct notifier

**"Stack Overflow" during state changes**
- Check for infinite loops in state listeners
- Example: Avoid calling refresh methods from state change listeners without guards (e.g., check `isRefreshing` flag)

**Hot restart triggers unwanted network requests**
- Check if auth state listener is properly detecting login vs. startup
- Only `Unauthenticated` → `Authenticated` should trigger refresh, not `AuthInitial` → `Authenticated`

## Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/search/search_test.dart

# Coverage
flutter test --coverage
```

For testing with GetIt:
```dart
setUp(() {
  getIt.allowReassignment = true;
  getIt.registerLazySingleton<Repository>(() => MockRepository());
});

tearDown(() => getIt.reset());
```
