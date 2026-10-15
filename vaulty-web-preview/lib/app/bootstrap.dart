import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/live_capabilities.dart';
import '../domain/repositories/document_repository.dart';
import '../domain/repositories/share_repository.dart';
import '../domain/repositories/insights_repository.dart';
import '../domain/repositories/search_repository.dart';
import '../data/mock/mock_repositories.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final shareRepositoryProvider = Provider<ShareRepository>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final insightsRepositoryProvider = Provider<InsightsRepository>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);
final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => throw UnimplementedError('Override at bootstrap'),
);

List<Override> mockOverrides({MockScenario? scenario}) {
  const value = String.fromEnvironment('MOCK_SCENARIO', defaultValue: 'normal');
  final store = MockStore(
    scenario:
        scenario ??
        MockScenario.values.firstWhere(
          (s) => s.name == value,
          orElse: () => MockScenario.normal,
        ),
  );
  return [
    authRepositoryProvider.overrideWithValue(MockAuthRepository(store)),
    documentRepositoryProvider.overrideWithValue(MockDocumentRepository(store)),
    shareRepositoryProvider.overrideWithValue(MockShareRepository(store)),
    insightsRepositoryProvider.overrideWithValue(MockInsightsRepository(store)),
    searchRepositoryProvider.overrideWithValue(MockSearchRepository(store)),
  ];
}

final liveModeProvider = Provider<bool>(
  (ref) => ref.watch(authRepositoryProvider) is LiveAuthRepository,
);
final accountConnectionProvider = StreamProvider<AccountConnection>((
  ref,
) async* {
  final auth = ref.watch(authRepositoryProvider);
  if (auth is LiveAuthRepository) {
    yield auth.connection;
    yield* auth.connections;
  } else {
    yield const AccountConnection(id: 'demo', name: 'Demo', driveReady: true);
  }
});
final vaultIdentityProvider = Provider<String?>(
  (ref) => ref.watch(authRepositoryProvider) is LiveAuthRepository
      ? ref.watch(accountConnectionProvider).valueOrNull?.vaultIdentity
      : 'demo',
);
