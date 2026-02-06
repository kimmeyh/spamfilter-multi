import 'package:logger/logger.dart';
import 'database_helper.dart';

/// Store for account operations
class AccountStore {
  final DatabaseHelper _dbHelper;
  final Logger _logger = Logger();

  AccountStore(this._dbHelper);

  /// Get all accounts
  Future<List<Map<String, dynamic>>> getAllAccounts() async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query('accounts');
      _logger.d('Retrieved ${result.length} accounts from database');
      return result;
    } catch (e) {
      _logger.e('Failed to get all accounts', error: e);
      rethrow;
    }
  }

  /// Get account by ID
  Future<Map<String, dynamic>?> getAccount(String accountId) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'accounts',
        where: 'account_id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (result.isEmpty) {
        return null;
      }

      return result.first;
    } catch (e) {
      _logger.e('Failed to get account', error: e);
      rethrow;
    }
  }

  /// Insert a new account
  Future<void> insertAccount({
    required String accountId,
    required String platformId,
    required String email,
    String? displayName,
  }) async {
    try {
      final db = await _dbHelper.database;
      await db.insert(
        'accounts',
        {
          'account_id': accountId,
          'platform_id': platformId,
          'email': email,
          'display_name': displayName,
          'date_added': DateTime.now().millisecondsSinceEpoch,
        },
      );
      _logger.d('Inserted account: $accountId');
    } catch (e) {
      _logger.e('Failed to insert account', error: e);
      rethrow;
    }
  }

  /// Delete account by ID
  Future<void> deleteAccount(String accountId) async {
    try {
      final db = await _dbHelper.database;
      await db.delete(
        'accounts',
        where: 'account_id = ?',
        whereArgs: [accountId],
      );
      _logger.d('Deleted account: $accountId');
    } catch (e) {
      _logger.e('Failed to delete account', error: e);
      rethrow;
    }
  }
}
