import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/shelf.dart';
import 'book_model.dart';

part 'shelf_model.freezed.dart';
part 'shelf_model.g.dart';

/// Shelf model with JSON serialization
@freezed
class ShelfModel with _$ShelfModel {
  const ShelfModel._();

  const factory ShelfModel({
    required String key,
    required String name,
    required String olName,
    required int olId,
    @Default([]) List<BookModel> books,
    int? totalCount,
    @Default(ShelfSortOrder.dateAdded) ShelfSortOrder sortOrder,
    @Default(true) bool sortAscending,
    @Default(true) bool isVisible,
    @Default(0) int displayOrder,
    DateTime? lastSynced,
  }) = _ShelfModel;

  /// Convert to domain entity
  Shelf toEntity() {
    return Shelf(
      key: key,
      name: name,
      olName: olName,
      olId: olId,
      books: books.map((b) => b.toEntity()).toList(),
      totalCount: totalCount,
      sortOrder: sortOrder,
      sortAscending: sortAscending,
      isVisible: isVisible,
      displayOrder: displayOrder,
      lastSynced: lastSynced,
    );
  }

  /// Create from domain entity
  factory ShelfModel.fromEntity(Shelf shelf) {
    return ShelfModel(
      key: shelf.key,
      name: shelf.name,
      olName: shelf.olName,
      olId: shelf.olId,
      books: shelf.books.map((b) => BookModel.fromEntity(b)).toList(),
      totalCount: shelf.totalCount,
      sortOrder: shelf.sortOrder,
      sortAscending: shelf.sortAscending,
      isVisible: shelf.isVisible,
      displayOrder: shelf.displayOrder,
      lastSynced: shelf.lastSynced,
    );
  }

  /// Create from JSON
  factory ShelfModel.fromJson(Map<String, dynamic> json) => _$ShelfModelFromJson(json);
}
