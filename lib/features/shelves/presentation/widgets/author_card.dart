import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/navigation_extensions.dart';
import '../../domain/entities/author.dart';
import 'grid_item_card.dart';

/// Card widget for displaying an author in the grid
class AuthorCard extends StatelessWidget {
  final Author author;
  final double coverWidth;

  const AuthorCard({
    super.key,
    required this.author,
    required this.coverWidth,
  });

  @override
  Widget build(BuildContext context) {
    return GridItemCard(
      coverWidth: coverWidth,
      onTap: () {
        // Navigate to search with author filter
        // Use pushToSearch to maintain navigation stack
        context.pushToSearch(query: author.name, filter: 'author');
      },
      imageBuilder: (context, width, height) {
        return _buildAuthorImage();
      },
      textBuilder: (context) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 6),

            // "Author" label (where book shows author name)
            Text(
              'Author',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 11,
                    height: 1.2,
                  ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 2),

            // Author name (where book shows title)
            Text(
              author.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                    height: 1.2,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        );
      },
    );
  }

  Widget _buildAuthorImage() {
    if (author.photoId != null) {
      // Use covers API for author photos: https://covers.openlibrary.org/a/id/{id}-{size}.jpg
      final imageUrl =
          'https://covers.openlibrary.org/a/id/${author.photoId}-M.jpg';

      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          width: coverWidth,
          height: coverWidth * 1.5, // Same aspect ratio as book covers
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) => _buildPlaceholder(),
          // Generous caching settings for author photos
          memCacheWidth: 400,           // Good quality memory cache
          maxHeightDiskCache: 800,      // Preserve images on disk
          cacheKey: imageUrl,           // Custom cache key for reliable caching
          fadeInDuration: const Duration(milliseconds: 200), // Smooth fade-in
          fadeOutDuration: const Duration(milliseconds: 100), // Smooth fade-out
          // Web-specific optimizations

        ),
      );
    } else {
      // Show generic person icon when no photo available
      return _buildPlaceholder();
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      width: coverWidth,
      height: coverWidth * 1.5,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.person,
        size: coverWidth * 0.6,
        color: Colors.grey[600],
      ),
    );
  }
}
