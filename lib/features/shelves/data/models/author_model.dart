import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/author.dart';

part 'author_model.freezed.dart';

/// Author model with JSON serialization
@freezed
abstract class AuthorModel with _$AuthorModel {
  const AuthorModel._();

  const factory AuthorModel({
    required String id,
    required String name,
    int? photoId,
    String? bio,
    DateTime? birthDate,
    DateTime? deathDate,
    int? workCount,
  }) = _AuthorModel;

  /// Create from OpenLibrary author API response
  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    // Extract author ID from key
    String authorId = '';
    if (json['key'] != null) {
      authorId = (json['key'] as String).replaceFirst('/authors/', '');
    }

    // Extract name
    String name = json['name'] as String? ?? 'Unknown Author';

    // Extract photo ID from photos array
    int? photoId;
    if (json['photos'] != null && json['photos'] is List) {
      final photos = json['photos'] as List;
      if (photos.isNotEmpty) {
        photoId = photos[0] as int;
      }
    }

    // Extract bio
    String? bio;
    if (json['bio'] != null) {
      if (json['bio'] is String) {
        bio = json['bio'] as String;
      } else if (json['bio'] is Map && json['bio']['value'] != null) {
        bio = json['bio']['value'] as String;
      }
    }

    // Extract birth date
    DateTime? birthDate;
    if (json['birth_date'] != null) {
      try {
        birthDate = DateTime.parse(json['birth_date'] as String);
      } catch (e) {
        // Invalid date format, skip
      }
    }

    // Extract death date
    DateTime? deathDate;
    if (json['death_date'] != null) {
      try {
        deathDate = DateTime.parse(json['death_date'] as String);
      } catch (e) {
        // Invalid date format, skip
      }
    }

    // Extract work count
    int? workCount;
    if (json['work_count'] != null) {
      workCount = json['work_count'] as int;
    }

    return AuthorModel(
      id: authorId,
      name: name,
      photoId: photoId,
      bio: bio,
      birthDate: birthDate,
      deathDate: deathDate,
      workCount: workCount,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (photoId != null) 'photoId': photoId,
      if (bio != null) 'bio': bio,
      if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      if (deathDate != null) 'deathDate': deathDate!.toIso8601String(),
      if (workCount != null) 'workCount': workCount,
    };
  }

  /// Create from cached JSON (simpler than API response)
  factory AuthorModel.fromCachedJson(Map<String, dynamic> json) {
    return AuthorModel(
      id: json['id'] as String,
      name: json['name'] as String,
      photoId: json['photoId'] as int?,
      bio: json['bio'] as String?,
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'] as String)
          : null,
      deathDate: json['deathDate'] != null
          ? DateTime.parse(json['deathDate'] as String)
          : null,
      workCount: json['workCount'] as int?,
    );
  }

  /// Convert to domain entity
  Author toEntity() {
    return Author(
      id: id,
      name: name,
      photoId: photoId,
      bio: bio,
      birthDate: birthDate,
      deathDate: deathDate,
      workCount: workCount,
    );
  }
}
