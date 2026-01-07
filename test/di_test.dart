import 'package:flutter_test/flutter_test.dart';
import 'package:openlibrary_reader/core/di/injection.dart';
import 'package:openlibrary_reader/core/storage/preferences_service.dart';

void main() {
  test('DI Test - Verify dependency injection works', () async {
    // This should not throw an exception if DI is working
    configureDependencies();
    
    // Try to get a service that should be registered
    final preferencesService = getIt<PreferencesService>();
    
    // If we get here without exceptions, DI is working
    expect(preferencesService, isNotNull);
  });
}