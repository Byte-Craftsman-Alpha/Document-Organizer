import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../domain/repositories/live_capabilities.dart';
import '../../../app/bootstrap.dart';

final sessionProvider = AsyncNotifierProvider<SessionController, String?>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<String?> {
  @override
  FutureOr<String?> build() {
    final repo = ref.watch(authRepositoryProvider);
    if (repo is LiveAuthRepository) {
      final account =
          ref.watch(accountConnectionProvider).valueOrNull ?? repo.connection;
      return account.driveReady ? account.name ?? account.email : null;
    }
    return repo.currentUser();
  }

  Future<void> signIn() async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    final result = await AsyncValue.guard(repo.signIn);
    if (repo is LiveAuthRepository) {
      final current = repo.connection;
      state = current.driveReady
          ? AsyncData(current.name ?? current.email)
          : result.hasError
          ? AsyncError(result.error!, result.stackTrace!)
          : const AsyncData(null);
    } else {
      state = result;
    }
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    if (repo is LiveAuthRepository && repo.connection.driveReady) {
      state = AsyncData(repo.connection.name ?? repo.connection.email);
    } else {
      state = const AsyncData(null);
    }
  }
}
