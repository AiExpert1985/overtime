import 'package:sqflite/sqflite.dart';

import '../domain/user_role.dart';

// Credentials live in the same app_settings table as every other config
// value (seeded via AppDatabase's _settingsDefaults), as two keys per role:
// '{role}_username' and '{role}_password'. Role identity itself is fixed in
// code (UserRole) and never stored or editable.
class AuthRepository {
  const AuthRepository(this._db);

  final Database _db;

  Future<Map<UserRole, (String username, String password)>>
  loadAccounts() async {
    final rows = await _db.query('app_settings');
    final map = {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
    return {
      for (final role in UserRole.values)
        role: (
          map['${role.name}_username'] ?? '',
          map['${role.name}_password'] ?? '',
        ),
    };
  }

  UserRole? authenticate(
    Map<UserRole, (String, String)> accounts,
    String username,
    String password,
  ) {
    for (final entry in accounts.entries) {
      final (storedUsername, storedPassword) = entry.value;
      if (storedUsername == username && storedPassword == password) {
        return entry.key;
      }
    }
    return null;
  }

  Future<void> updateUsername(UserRole role, String username) async {
    await _db.update(
      'app_settings',
      {'value': username},
      where: 'key = ?',
      whereArgs: ['${role.name}_username'],
    );
  }

  Future<void> updatePassword(UserRole role, String password) async {
    await _db.update(
      'app_settings',
      {'value': password},
      where: 'key = ?',
      whereArgs: ['${role.name}_password'],
    );
  }
}
