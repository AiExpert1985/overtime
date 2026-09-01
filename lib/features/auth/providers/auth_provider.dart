import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../data/auth_repository.dart';
import '../domain/user_role.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dbProvider));
});

// The logged-in role, in memory only — by design there is no persisted
// session, so the app always starts at the login screen. routerProvider
// watches this to gate navigation.
class CurrentUserNotifier extends Notifier<UserRole?> {
  @override
  UserRole? build() => null;

  void login(UserRole role) => state = role;

  void logout() => state = null;
}

final currentUserProvider = NotifierProvider<CurrentUserNotifier, UserRole?>(
  CurrentUserNotifier.new,
);

// --- Accounts (credentials) ---

class AccountsNotifier extends AsyncNotifier<Map<UserRole, (String, String)>> {
  @override
  Future<Map<UserRole, (String, String)>> build() =>
      ref.read(authRepositoryProvider).loadAccounts();

  Future<UserRole?> login(String username, String password) async {
    final accounts = await future;
    return ref
        .read(authRepositoryProvider)
        .authenticate(accounts, username, password);
  }

  Future<void> updateUsername(UserRole role, String username) async {
    await ref.read(authRepositoryProvider).updateUsername(role, username);
    await _reload();
  }

  Future<void> updatePassword(UserRole role, String password) async {
    await ref.read(authRepositoryProvider).updatePassword(role, password);
    await _reload();
  }

  Future<void> _reload() async {
    state = AsyncData(await ref.read(authRepositoryProvider).loadAccounts());
  }
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, Map<UserRole, (String, String)>>(
      AccountsNotifier.new,
    );
