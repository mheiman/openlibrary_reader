import 'package:equatable/equatable.dart';

import '../../domain/entities/user.dart';

/// Authentication state
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial/idle state
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state (login/logout in progress)
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// Authenticated state (user is logged in)
class Authenticated extends AuthState {
  final User user;

  const Authenticated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Unauthenticated state (user is not logged in)
class Unauthenticated extends AuthState {
  final String? message;

  const Unauthenticated([this.message]);

  @override
  List<Object?> get props => [message];
}

/// Authentication error state
class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
