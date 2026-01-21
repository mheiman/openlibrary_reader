import 'package:freezed_annotation/freezed_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

/// User model with JSON serialization
@freezed
abstract class UserModel with _$UserModel {
  const UserModel._();

  const factory UserModel({
    required String userId,
    required String username,
    required String displayName,
    @Default('') String email,
  }) = _UserModel;

  /// Convert to domain entity
  User toEntity() {
    return User(
      userId: userId,
      username: username,
      displayName: displayName,
      email: email,
    );
  }

  /// Create from domain entity
  factory UserModel.fromEntity(User user) {
    return UserModel(
      userId: user.userId,
      username: user.username,
      displayName: user.displayName,
      email: user.email,
    );
  }

  /// Create from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);
}
