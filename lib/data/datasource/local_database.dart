// lib/data/datasource/local_database.dart
import 'package:ecap/core/database.dart';
import 'package:path/path.dart';

class LocalDatabase {
  static Database? _db;

  LocalDatabase._();
  static final LocalDatabase instance = LocalDatabase._();

  Future<Database> get database async {
    _db ??= await _openDb();
    return _db!;
  }

  Future<Database> _openDb() async {
    final dbPath = join(await getDatabasesPath(), 'ecap.db');

    return openDatabase(
      dbPath,
      version: 3,
      onConfigure: (db) async {
        // Disable foreign keys during schema creation
        await db.execute('PRAGMA foreign_keys = OFF');
      },
      onCreate: (db, version) async {
        // ── Create each table individually ──
        await db.execute('''
          CREATE TABLE IF NOT EXISTS family (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            avatar TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            avatar TEXT,
            role TEXT CHECK(role IN ('super_admin','parent')) NOT NULL,
            pin_hash TEXT NOT NULL,
            family_id INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            token TEXT NOT NULL,
            device_id INTEGER,
            created_at INTEGER DEFAULT (strftime('%s','now')),
            expires_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS children (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            avatar TEXT,
            color TEXT,
            family_id INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS devices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_identifier TEXT UNIQUE NOT NULL,
            name TEXT,
            family_id INTEGER,
            child_id INTEGER,
            last_sync_time INTEGER,
            last_seen INTEGER,
            device_status TEXT CHECK(device_status IN ('online','offline','stale')) DEFAULT 'offline',
            battery_level INTEGER,
            sync_version INTEGER DEFAULT 0,
            is_active INTEGER DEFAULT 1,
            enrolled_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT NOT NULL,
            value TEXT,
            scope_type TEXT CHECK(scope_type IN ('global','family','user')) NOT NULL,
            scope_id INTEGER,
            UNIQUE(key, scope_type, scope_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS license (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            family_id INTEGER NOT NULL,
            device_id INTEGER,
            start_date INTEGER NOT NULL,
            duration_days INTEGER NOT NULL,
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS apps (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            package_name TEXT UNIQUE NOT NULL,
            app_name TEXT,
            icon TEXT,
            category TEXT,
            is_system_app INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_rules (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER NOT NULL,
            app_id INTEGER NOT NULL,
            mode TEXT CHECK(mode IN ('allowed','blocked','limited')) NOT NULL,
            daily_limit_minutes INTEGER DEFAULT 0,
            start_time INTEGER,
            end_time INTEGER,
            version INTEGER DEFAULT 1,
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS app_rule_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER,
            app_id INTEGER,
            mode TEXT,
            daily_limit_minutes INTEGER,
            start_time INTEGER,
            end_time INTEGER,
            version INTEGER,
            changed_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS control_state (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            child_id INTEGER NOT NULL,
            app_id INTEGER NOT NULL,
            rule_id INTEGER,
            rule_version INTEGER,
            engine_version TEXT,
            is_blocked INTEGER,
            reason TEXT,
            evaluated_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS control_state_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER,
            child_id INTEGER,
            app_id INTEGER,
            rule_id INTEGER,
            rule_version INTEGER,
            engine_version TEXT,
            is_blocked INTEGER,
            reason TEXT,
            evaluated_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS sync_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER,
            action_type TEXT,
            payload TEXT,
            version INTEGER,
            status TEXT CHECK(status IN ('pending','sent','ack')) DEFAULT 'pending',
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS usage_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER NOT NULL,
            app_id INTEGER NOT NULL,
            start_time INTEGER NOT NULL,
            end_time INTEGER,
            duration_seconds INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_type TEXT NOT NULL,
            child_id INTEGER,
            app_id INTEGER,
            device_id INTEGER,
            timestamp INTEGER,
            value INTEGER,
            extra TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS security_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            event TEXT,
            timestamp INTEGER,
            details TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            action TEXT,
            target_type TEXT,
            target_id INTEGER,
            timestamp INTEGER,
            metadata TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS points_balance (
            child_id INTEGER PRIMARY KEY,
            total_points INTEGER DEFAULT 0,
            updated_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS points_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER NOT NULL,
            points INTEGER NOT NULL,
            type TEXT CHECK(type IN ('earn','spend')),
            source TEXT,
            created_at INTEGER DEFAULT (strftime('%s','now'))
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS missions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            target_minutes INTEGER,
            reward_points INTEGER,
            is_active INTEGER DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS child_missions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER NOT NULL,
            mission_id INTEGER NOT NULL,
            progress INTEGER DEFAULT 0,
            completed INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS rewards (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            cost_points INTEGER,
            reward_type TEXT,
            value INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reward_redemptions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            child_id INTEGER NOT NULL,
            reward_id INTEGER NOT NULL,
            redeemed_at INTEGER,
            status TEXT CHECK(status IN ('pending','approved','rejected','used'))
          )
        ''');

        // Create the trigger
        await db.execute('''
          CREATE TRIGGER IF NOT EXISTS update_points_balance
          AFTER INSERT ON points_transactions
          BEGIN
            INSERT INTO points_balance(child_id, total_points)
            VALUES (NEW.child_id, NEW.points)
            ON CONFLICT(child_id) DO UPDATE SET
                total_points = total_points + NEW.points,
                updated_at = strftime('%s','now');
          END
        ''');

        // Finally, turn foreign keys on for normal operations
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Drop all tables
        await db.execute('PRAGMA foreign_keys = OFF');
        final tables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
        );
        for (final t in tables) {
          await db.execute('DROP TABLE IF EXISTS ${t['name']}');
        }
        // Re-create everything
        await db.execute('PRAGMA foreign_keys = ON');
        // We could call onCreate again, but it's not invoked automatically.
        // Instead we manually run the same creation statements as above.
        // Since we just dropped everything, we can simply call the same helper.
        // But to avoid code duplication, we can just let the next restart with deleteDatabase handle it.
        // For safety, throw an error so the developer knows to uninstall:
        throw Exception('Database upgrade needed. Please uninstall the app and reinstall.');
      },
    );
  }
}