import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared configuration for book grid layouts
/// Use this to ensure consistent grid spacing and sizing across all book grids
class BookGridConfig {
  /// Default spacing between grid items horizontally
  static const double defaultCrossAxisSpacing = 16;

  /// Default spacing between grid items vertically
  static const double defaultMainAxisSpacing = 16;

  /// Default padding around the grid
  static const EdgeInsets defaultPadding = EdgeInsets.all(16);

  /// Base height for text area below book cover (at default 80px cover width)
  static const double baseTextAreaHeight = 72.0;

  /// Default cover width used as baseline for scaling
  static const double defaultCoverWidth = 80.0;

  /// Calculate the scaled text area height based on cover width
  static double calculateTextAreaHeight(double coverWidth) {
    return baseTextAreaHeight * math.sqrt(coverWidth / defaultCoverWidth);
  }

  /// Calculate the total item height for a grid item
  /// This includes the cover image height plus the scaled text area
  static double calculateItemHeight(double coverWidth) {
    // Allow for taller books by using 1.6x ratio instead of 1.5x
    return (coverWidth * 1.6) + calculateTextAreaHeight(coverWidth);
  }

  /// Create a grid delegate for use with GridView or SliverGrid
  static SliverGridDelegateWithMaxCrossAxisExtent createGridDelegate({
    required double coverWidth,
    double? crossAxisSpacing,
    double? mainAxisSpacing,
  }) {
    return SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: coverWidth,
      mainAxisExtent: calculateItemHeight(coverWidth),
      crossAxisSpacing: crossAxisSpacing ?? defaultCrossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing ?? defaultMainAxisSpacing,
    );
  }
}
