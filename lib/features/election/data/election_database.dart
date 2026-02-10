import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../domain/election_models.dart';

const String genesisHash = 'GENESIS';

class ElectionDatabase {
  ElectionDatabase({DatabaseFactory? factory, String? databasePath})
    : _factory = factory ?? databaseFactoryFfi,
      _databasePath = databasePath;

  final DatabaseFactory _factory;
  final String? _databasePath;
  Database? _database;

  Future<void> open() async {
    if (_database != null) {
      return;
    }

    final path =
        _databasePath ??
        p.join(await _factory.getDatabasesPath(), 'sandik_sayim.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE election (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              status TEXT NOT NULL CHECK(status IN ('setup','locked','counting','finalized')),
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              locked_at TEXT,
              finalized_at TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE candidate (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              election_id INTEGER NOT NULL,
              entry_order INTEGER NOT NULL,
              display_name TEXT NOT NULL,
              created_at TEXT NOT NULL,
              UNIQUE(election_id, entry_order),
              FOREIGN KEY(election_id) REFERENCES election(id)
            )
          ''');

          await db.execute('''
            CREATE TABLE vote_ledger (
              seq_no INTEGER PRIMARY KEY,
              election_id INTEGER NOT NULL,
              candidate_id INTEGER NOT NULL,
              created_at TEXT NOT NULL,
              prev_hash TEXT NOT NULL,
              record_hash TEXT NOT NULL,
              FOREIGN KEY(election_id) REFERENCES election(id),
              FOREIGN KEY(candidate_id) REFERENCES candidate(id)
            )
          ''');

          await db.execute('''
            CREATE TRIGGER prevent_vote_ledger_update
            BEFORE UPDATE ON vote_ledger
            BEGIN
              SELECT RAISE(ABORT, 'vote_ledger is append-only');
            END;
          ''');

          await db.execute('''
            CREATE TRIGGER prevent_vote_ledger_delete
            BEFORE DELETE ON vote_ledger
            BEGIN
              SELECT RAISE(ABORT, 'vote_ledger is append-only');
            END;
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE election ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
            );
            await db.execute('UPDATE election SET is_active = 0');
            await db.execute('''
              UPDATE election
              SET is_active = 1
              WHERE id = (SELECT id FROM election ORDER BY id DESC LIMIT 1)
            ''');
          }
        },
      ),
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Database get db {
    final database = _database;
    if (database == null) {
      throw StateError('Database is not open.');
    }
    return database;
  }

  String buildRecordHash({
    required int seqNo,
    required int electionId,
    required int candidateId,
    required String createdAt,
    required String prevHash,
  }) {
    final input = '$seqNo|$electionId|$candidateId|$createdAt|$prevHash';
    return sha256.convert(utf8.encode(input)).toString();
  }

  Candidate mapCandidate(Map<String, Object?> row) {
    return Candidate(
      id: row['id'] as int,
      electionId: row['election_id'] as int,
      entryOrder: row['entry_order'] as int,
      displayName: row['display_name'] as String,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  VoteRecord mapVoteRecord(Map<String, Object?> row) {
    return VoteRecord(
      seqNo: row['seq_no'] as int,
      electionId: row['election_id'] as int,
      candidateId: row['candidate_id'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      prevHash: row['prev_hash'] as String,
      recordHash: row['record_hash'] as String,
    );
  }
}
