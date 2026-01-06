import 'package:equatable/equatable.dart';

/// Author entity
class Author extends Equatable {
  final String id; // e.g., "OL2622837A"
  final String name;
  final int? photoId; // For cover image from photos field
  final String? bio;
  final DateTime? birthDate;
  final DateTime? deathDate;
  final int? workCount; // Number of works by this author

  const Author({
    required this.id,
    required this.name,
    this.photoId,
    this.bio,
    this.birthDate,
    this.deathDate,
    this.workCount,
  });

  @override
  List<Object?> get props => [id, name, photoId, bio, birthDate, deathDate, workCount];
}
