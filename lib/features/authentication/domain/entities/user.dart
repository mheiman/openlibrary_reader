import 'package:equatable/equatable.dart';

/// User entity representing an authenticated OpenLibrary user
class User extends Equatable {
  final String userId;
  final String username;
  final String displayName;
  final String email;

  const User({
    required this.userId,
    required this.username,
    required this.displayName,
    this.email = '',
  });

  @override
  List<Object?> get props => [userId, username, displayName, email];

  @override
  String toString() => 'User(userId: $userId, username: $username, displayName: $displayName)';
}
