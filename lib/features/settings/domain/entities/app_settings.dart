import 'package:equatable/equatable.dart';

/// Application settings entity
class AppSettings extends Equatable {
  /// Move books to "Reading" shelf when borrowing
  final bool moveToReading;

  /// Show UI chrome overlay in reader
  final bool showChrome;

  /// Keep screen awake while reading
  final bool keepAwake;

  /// Cover image width in pixels (60-140)
  final double coverWidth;

  /// Default sort order for shelves
  final String sortOrder;

  /// Visible shelf keys
  final List<String> visibleShelves;

  /// Search sort order
  final String searchSortOrder;

  /// Search sort ascending
  final bool searchSortAscending;

  /// Show Lists tab
  final bool showLists;

  /// Dark mode setting: 'off', 'on', 'auto'
  final String darkMode;

  /// Dark mode options
  static const String darkModeOff = 'off';
  static const String darkModeOn = 'on';
  static const String darkModeAuto = 'auto';

  /// Default cover width
  static const double defaultCoverWidth = 80.0;

  /// Minimum cover width
  static const double minCoverWidth = 60.0;

  /// Maximum cover width
  static const double maxCoverWidth = 140.0;

  const AppSettings({
    this.moveToReading = true,
    this.showChrome = false,
    this.keepAwake = true,
    this.coverWidth = defaultCoverWidth,
    this.sortOrder = 'dateAdded',
    this.visibleShelves = const [],
    this.searchSortOrder = 'datePublished',
    this.searchSortAscending = true,
    this.showLists = false,
    this.darkMode = darkModeOff,
  });

  /// Get cover height based on width (1.5 aspect ratio)
  double get coverHeight => coverWidth * 1.5;

  @override
  List<Object?> get props => [
        moveToReading,
        showChrome,
        keepAwake,
        coverWidth,
        sortOrder,
        visibleShelves,
        searchSortOrder,
        searchSortAscending,
        showLists,
        darkMode,
      ];

  /// Copy with updated fields
  AppSettings copyWith({
    bool? moveToReading,
    bool? showChrome,
    bool? keepAwake,
    double? coverWidth,
    String? sortOrder,
    List<String>? visibleShelves,
    String? searchSortOrder,
    bool? searchSortAscending,
    bool? showLists,
    String? darkMode,
  }) {
    return AppSettings(
      moveToReading: moveToReading ?? this.moveToReading,
      showChrome: showChrome ?? this.showChrome,
      keepAwake: keepAwake ?? this.keepAwake,
      coverWidth: coverWidth ?? this.coverWidth,
      sortOrder: sortOrder ?? this.sortOrder,
      visibleShelves: visibleShelves ?? this.visibleShelves,
      searchSortOrder: searchSortOrder ?? this.searchSortOrder,
      searchSortAscending: searchSortAscending ?? this.searchSortAscending,
      showLists: showLists ?? this.showLists,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
