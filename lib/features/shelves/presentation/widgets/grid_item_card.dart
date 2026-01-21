import 'package:flutter/material.dart';

import 'book_grid_config.dart';

/// Centralized grid item card widget that provides consistent layout
/// for books, authors, and other grid items.
///
/// This widget ensures all grid items have:
/// - Bottom-aligned images (using Alignment.bottomCenter)
/// - Consistent aspect ratios and sizing
/// - Scaled text area at bottom (based on cover width)
/// - Optional overlay widgets (menu buttons, badges, etc.)
class GridItemCard extends StatelessWidget {
  final double coverWidth;
  final Widget Function(BuildContext context, double width, double height) imageBuilder;
  final Widget Function(BuildContext context) textBuilder;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final List<Widget> overlayWidgets;

  const GridItemCard({
    super.key,
    required this.coverWidth,
    required this.imageBuilder,
    required this.textBuilder,
    this.onTap,
    this.onDoubleTap,
    this.overlayWidgets = const [],
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use actual available width, but don't exceed the specified coverWidth
        final actualWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(0.0, coverWidth)
            : coverWidth;
        final coverHeight = actualWidth * 1.5;
        // Match BookGrid's height allocation (1.6x ratio for taller items)
        final maxCoverHeight = actualWidth * 1.6;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Image area with optional overlays
            GestureDetector(
              onTap: onTap,
              onDoubleTap: onDoubleTap,
              child: Container(
                alignment: Alignment.bottomCenter,
                constraints: BoxConstraints(
                  minWidth: actualWidth,
                  maxWidth: actualWidth,
                  minHeight: coverHeight,
                  maxHeight: maxCoverHeight,
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.passthrough,
                  children: [
                    // Main image
                    imageBuilder(context, actualWidth, coverHeight),
                    // Optional overlay widgets (menu buttons, badges, etc.)
                    ...overlayWidgets,
                  ],
                ),
              ),
            ),

            // Text area with scaled height to match text scaling
            SizedBox(
              height: BookGridConfig.calculateTextAreaHeight(coverWidth),
              child: SingleChildScrollView(
                child: textBuilder(context),
              ),
            ),
          ],
        );
      },
    );
  }
}
