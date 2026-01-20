import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Simple connectivity service that detects network status
/// and provides clear user feedback
class ConnectivityService with ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  bool _hasNetwork = true;
  bool _openLibraryAvailable = true;
  bool _archiveOrgAvailable = true;

  bool get hasNetwork => _hasNetwork;
  bool get openLibraryAvailable => _openLibraryAvailable;
  bool get archiveOrgAvailable => _archiveOrgAvailable;

  /// Check if we have basic network connectivity
  bool get isOffline => !_hasNetwork;

  /// Check if OpenLibrary is specifically unavailable
  bool get isOpenLibraryDown => _hasNetwork && !_openLibraryAvailable;

  /// Check if Archive.org is specifically unavailable
  bool get isArchiveOrgDown => _hasNetwork && !_archiveOrgAvailable;

  ConnectivityService() {
    _init();
  }

  Future<void> _init() async {
    await _checkNetworkConnectivity();
    
    // Listen for network changes
    _connectivity.onConnectivityChanged.listen((result) async {
      await _checkNetworkConnectivity();
    });
  }

  Future<void> _checkNetworkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final wasConnected = _hasNetwork;
      // Has network if any result is not 'none'
      _hasNetwork = results.any((r) => r != ConnectivityResult.none);

      if (_hasNetwork != wasConnected) {
        notifyListeners();
      }
    } catch (e) {
      _hasNetwork = false;
      notifyListeners();
    }
  }

  /// Mark OpenLibrary as unavailable (called when API calls fail)
  void markOpenLibraryUnavailable() {
    _openLibraryAvailable = false;
    notifyListeners();
  }

  /// Mark OpenLibrary as available again
  void markOpenLibraryAvailable() {
    _openLibraryAvailable = true;
    notifyListeners();
  }

  /// Mark Archive.org as unavailable
  void markArchiveOrgUnavailable() {
    _archiveOrgAvailable = false;
    notifyListeners();
  }

  /// Mark Archive.org as available again
  void markArchiveOrgAvailable() {
    _archiveOrgAvailable = true;
    notifyListeners();
  }

  /// Reset all service availability flags
  void resetServiceAvailability() {
    _openLibraryAvailable = true;
    _archiveOrgAvailable = true;
    notifyListeners();
  }
}