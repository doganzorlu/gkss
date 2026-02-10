import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/election_database.dart';
import '../domain/election_models.dart';

class ElectionService extends ChangeNotifier {
  ElectionService(this._database);

  final ElectionDatabase _database;

  ElectionSnapshot? _snapshot;
  ElectionSnapshot? get snapshot => _snapshot;

  Future<void> initialize() async {
    await _database.open();
    await _ensureElectionExists();
    await refresh();
  }

  Future<void> refresh() async {
    final database = _database.db;
    final electionRows = await database.query(
      'election',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (electionRows.isEmpty) {
      throw StateError('Seçim kaydı bulunamadı.');
    }

    final election = electionRows.first;
    final electionId = election['id'] as int;
    final title = election['title'] as String;
    final status = electionStatusFromDb(election['status'] as String);

    final candidateRows = await database.query(
      'candidate',
      where: 'election_id = ?',
      whereArgs: [electionId],
      orderBy: 'entry_order ASC',
    );

    final candidates = candidateRows.map(_database.mapCandidate).toList();

    final countRows = await database.rawQuery(
      'SELECT candidate_id, COUNT(*) AS vote_count '
      'FROM vote_ledger WHERE election_id = ? GROUP BY candidate_id',
      [electionId],
    );

    final countsByCandidate = <int, int>{
      for (final row in countRows)
        row['candidate_id'] as int: (row['vote_count'] as int?) ?? 0,
    };

    final totalRows = await database.rawQuery(
      'SELECT COUNT(*) AS total_votes, MAX(created_at) AS last_action_at '
      'FROM vote_ledger WHERE election_id = ?',
      [electionId],
    );

    final totals = totalRows.first;
    final totalVotes = (totals['total_votes'] as int?) ?? 0;
    final lastActionAtText = totals['last_action_at'] as String?;

    _snapshot = ElectionSnapshot(
      electionId: electionId,
      title: title,
      status: status,
      candidates: candidates,
      countsByCandidate: countsByCandidate,
      totalVotes: totalVotes,
      lastActionAt: lastActionAtText == null
          ? null
          : DateTime.parse(lastActionAtText),
    );

    notifyListeners();
  }

  Future<void> addCandidate(String displayName) async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.setup) {
      throw StateError('Adaylar yalnızca kurulum aşamasında eklenebilir.');
    }

    final normalized = displayName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Aday adı boş olamaz.');
    }

    final exists = current.candidates.any(
      (candidate) =>
          candidate.displayName.toLowerCase() == normalized.toLowerCase(),
    );
    if (exists) {
      throw ArgumentError('Aday zaten mevcut.');
    }

    final nextOrder = current.candidates.length + 1;
    await _database.db.insert('candidate', {
      'election_id': current.electionId,
      'entry_order': nextOrder,
      'display_name': normalized,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    await refresh();
  }

  Future<void> addCandidatesBulk(List<String> names) async {
    final normalizedNames = names
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (normalizedNames.isEmpty) {
      throw ArgumentError('En az bir aday adı gereklidir.');
    }

    for (final name in normalizedNames) {
      await addCandidate(name);
    }
  }

  Future<void> renameCandidate({
    required int candidateId,
    required String newDisplayName,
  }) async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.setup) {
      throw StateError('Adaylar yalnızca kurulum aşamasında düzenlenebilir.');
    }

    final normalized = newDisplayName.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Aday adı boş olamaz.');
    }

    final candidateExists = current.candidates.any(
      (candidate) => candidate.id == candidateId,
    );
    if (!candidateExists) {
      throw ArgumentError('Aday bulunamadı.');
    }

    final duplicateExists = current.candidates.any(
      (candidate) =>
          candidate.id != candidateId &&
          candidate.displayName.toLowerCase() == normalized.toLowerCase(),
    );
    if (duplicateExists) {
      throw ArgumentError('Aday zaten mevcut.');
    }

    await _database.db.update(
      'candidate',
      {'display_name': normalized},
      where: 'id = ?',
      whereArgs: [candidateId],
    );

    await refresh();
  }

  Future<void> deleteCandidate(int candidateId) async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.setup) {
      throw StateError('Adaylar yalnızca kurulum aşamasında silinebilir.');
    }

    final target = current.candidates.where(
      (candidate) => candidate.id == candidateId,
    );
    if (target.isEmpty) {
      throw ArgumentError('Aday bulunamadı.');
    }

    final removedOrder = target.first.entryOrder;
    final database = _database.db;

    await database.transaction((txn) async {
      await txn.delete('candidate', where: 'id = ?', whereArgs: [candidateId]);
      await txn.rawUpdate(
        'UPDATE candidate SET entry_order = entry_order - 1 '
        'WHERE election_id = ? AND entry_order > ?',
        [current.electionId, removedOrder],
      );
    });

    await refresh();
  }

  Future<void> updateElectionTitle(String title) async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.setup) {
      throw StateError(
        'Seçim başlığı yalnızca kurulum aşamasında güncellenebilir.',
      );
    }

    final normalized = title.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Seçim başlığı boş olamaz.');
    }

    await _database.db.update(
      'election',
      {'title': normalized},
      where: 'id = ?',
      whereArgs: [current.electionId],
    );

    await refresh();
  }

  Future<void> lockCandidates() async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.setup) {
      throw StateError('Adaylar yalnızca kurulum durumunda kilitlenebilir.');
    }
    if (current.candidates.isEmpty) {
      throw StateError('Kilitlemeden önce en az bir aday gereklidir.');
    }

    await _database.db.update(
      'election',
      {
        'status': electionStatusToDb(ElectionStatus.locked),
        'locked_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [current.electionId],
    );

    await refresh();
  }

  Future<void> startCounting() async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.locked) {
      throw StateError('Sayım yalnızca kilitli durumdan başlatılabilir.');
    }

    await _database.db.update(
      'election',
      {'status': electionStatusToDb(ElectionStatus.counting)},
      where: 'id = ?',
      whereArgs: [current.electionId],
    );

    await refresh();
  }

  Future<void> incrementVote(int candidateId) async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.counting) {
      throw StateError('Oylar yalnızca sayım sırasında artırılabilir.');
    }

    final candidateExists = current.candidates.any(
      (candidate) => candidate.id == candidateId,
    );
    if (!candidateExists) {
      throw ArgumentError('Aday bulunamadı.');
    }

    final database = _database.db;

    // Retry on rare seq_no race/constraint collisions.
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await database.transaction((txn) async {
          final lastRowsInElection = await txn.query(
            'vote_ledger',
            columns: ['seq_no', 'record_hash'],
            where: 'election_id = ?',
            whereArgs: [current.electionId],
            orderBy: 'seq_no DESC',
            limit: 1,
          );
          final lastRowsGlobal = await txn.rawQuery(
            'SELECT MAX(seq_no) AS max_seq FROM vote_ledger',
          );

          final globalMaxSeq = (lastRowsGlobal.first['max_seq'] as int?) ?? 0;
          final seqNo = globalMaxSeq + 1;
          final lastHash = lastRowsInElection.isEmpty
              ? genesisHash
              : lastRowsInElection.first['record_hash'] as String;
          final createdAt = DateTime.now().toUtc().toIso8601String();
          final recordHash = _database.buildRecordHash(
            seqNo: seqNo,
            electionId: current.electionId,
            candidateId: candidateId,
            createdAt: createdAt,
            prevHash: lastHash,
          );

          await txn.insert('vote_ledger', {
            'seq_no': seqNo,
            'election_id': current.electionId,
            'candidate_id': candidateId,
            'created_at': createdAt,
            'prev_hash': lastHash,
            'record_hash': recordHash,
          });
        });

        await refresh();
        return;
      } catch (error) {
        final isLastAttempt = attempt == 2;
        final canRetry = _isSeqNoConstraintError(error) && !isLastAttempt;
        if (!canRetry) {
          rethrow;
        }
      }
    }

    throw StateError('Oy kaydı eklenemedi. Lütfen tekrar deneyin.');
  }

  Future<void> finalizeElection() async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.counting) {
      throw StateError('Seçim yalnızca sayım sırasında kesinleştirilebilir.');
    }

    await _database.db.update(
      'election',
      {
        'status': electionStatusToDb(ElectionStatus.finalized),
        'finalized_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [current.electionId],
    );

    await refresh();
  }

  Future<void> startNewElectionSession(String title) async {
    final current = _requireSnapshot();
    if (current.status != ElectionStatus.finalized) {
      throw StateError(
        'Yeni sayım yalnızca kesinleşmiş seçimden sonra açılabilir.',
      );
    }

    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Yeni sayım başlığı boş olamaz.');
    }

    final database = _database.db;
    await database.transaction((txn) async {
      await txn.update(
        'election',
        {'is_active': 0},
        where: 'id = ?',
        whereArgs: [current.electionId],
      );

      await txn.insert('election', {
        'title': normalizedTitle,
        'status': electionStatusToDb(ElectionStatus.setup),
        'is_active': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    });

    await refresh();
  }

  Future<IntegrityReport> verifyIntegrity() async {
    final current = _requireSnapshot();

    final rows = await _database.db.query(
      'vote_ledger',
      where: 'election_id = ?',
      whereArgs: [current.electionId],
      orderBy: 'seq_no ASC',
    );

    var expectedSeqNo = rows.isEmpty ? 1 : rows.first['seq_no'] as int;
    var expectedPrevHash = genesisHash;

    for (final row in rows) {
      final record = _database.mapVoteRecord(row);
      if (record.seqNo != expectedSeqNo) {
        return IntegrityReport(
          isValid: false,
          details:
              'Kayıt ${record.seqNo} için sıra numarası uyumsuz. Beklenen: $expectedSeqNo.',
        );
      }

      if (record.prevHash != expectedPrevHash) {
        return IntegrityReport(
          isValid: false,
          details: '${record.seqNo}. kayıtta önceki hash uyumsuzluğu var.',
        );
      }

      final recalculated = _database.buildRecordHash(
        seqNo: record.seqNo,
        electionId: record.electionId,
        candidateId: record.candidateId,
        createdAt: record.createdAt.toUtc().toIso8601String(),
        prevHash: record.prevHash,
      );

      if (recalculated != record.recordHash) {
        return IntegrityReport(
          isValid: false,
          details: '${record.seqNo}. kayıtta hash doğrulama hatası var.',
        );
      }

      expectedSeqNo += 1;
      expectedPrevHash = record.recordHash;
    }

    return IntegrityReport(
      isValid: true,
      details: 'Kayıt zinciri doğrulandı. ${rows.length} kayıt kontrol edildi.',
    );
  }

  Future<AuditExportResult> exportAuditPackage({
    String? outputBaseDirectory,
  }) async {
    final current = _requireSnapshot();
    final timestamp = DateTime.now().toUtc().toIso8601String();
    final safeTitle = _slugify(current.title);
    final exportBase =
        outputBaseDirectory ?? p.join(Directory.current.path, 'audit_exports');
    final exportDirectoryPath = p.join(
      exportBase,
      '${safeTitle}_$timestamp'.replaceAll(':', '-'),
    );

    final exportDirectory = Directory(exportDirectoryPath);
    await exportDirectory.create(recursive: true);

    final integrity = await verifyIntegrity();
    final ledgerRows = await _database.db.query(
      'vote_ledger',
      where: 'election_id = ?',
      whereArgs: [current.electionId],
      orderBy: 'seq_no ASC',
    );

    final candidateNameById = {
      for (final candidate in current.candidates)
        candidate.id: candidate.displayName,
    };

    final ledgerCsvPath = p.join(exportDirectoryPath, 'vote_ledger.csv');
    final summaryJsonPath = p.join(exportDirectoryPath, 'summary.json');
    final verificationPath = p.join(
      exportDirectoryPath,
      'verification_report.txt',
    );

    final csvBuffer = StringBuffer(
      'seq_no,election_id,candidate_id,candidate_name,created_at,prev_hash,record_hash\n',
    );
    for (final row in ledgerRows) {
      final candidateId = row['candidate_id'] as int;
      final candidateName = candidateNameById[candidateId] ?? 'UNKNOWN';
      csvBuffer.writeln(
        '${row['seq_no']},${row['election_id']},$candidateId,'
        '${_escapeCsv(candidateName)},${row['created_at']},'
        '${row['prev_hash']},${row['record_hash']}',
      );
    }

    await File(ledgerCsvPath).writeAsString(csvBuffer.toString());

    final summaryJson = {
      'election': {
        'id': current.electionId,
        'title': current.title,
        'status': electionStatusToDb(current.status),
      },
      'totals': {
        'totalVotes': current.totalVotes,
        'lastActionAt': current.lastActionAt?.toUtc().toIso8601String(),
      },
      'candidates': [
        for (final candidate in current.candidates)
          {
            'id': candidate.id,
            'entryOrder': candidate.entryOrder,
            'displayName': candidate.displayName,
            'votes': current.countsByCandidate[candidate.id] ?? 0,
          },
      ],
      'integrity': {'isValid': integrity.isValid, 'details': integrity.details},
      'exportedAtUtc': timestamp,
    };

    await File(
      summaryJsonPath,
    ).writeAsString(const JsonEncoder.withIndent('  ').convert(summaryJson));

    final reportText = StringBuffer()
      ..writeln('MOSB Genel Kurul Sayım Sistemi Doğrulama Raporu')
      ..writeln('DışaAktarımZamaniUtc: $timestamp')
      ..writeln('SeçimId: ${current.electionId}')
      ..writeln('SeçimBaşlığı: ${current.title}')
      ..writeln('SeçimDurumu: ${electionStatusToDb(current.status)}')
      ..writeln('ToplamOy: ${current.totalVotes}')
      ..writeln(
        'SonİşlemZamanı: ${current.lastActionAt?.toUtc().toIso8601String() ?? '-'}',
      )
      ..writeln('BütünlükGeçerli: ${integrity.isValid}')
      ..writeln('BütünlükDetayı: ${integrity.details}')
      ..writeln('OyZinciriCsv: $ledgerCsvPath')
      ..writeln('ÖzetJson: $summaryJsonPath');

    await File(verificationPath).writeAsString(reportText.toString());

    return AuditExportResult(
      directoryPath: exportDirectoryPath,
      ledgerCsvPath: ledgerCsvPath,
      summaryJsonPath: summaryJsonPath,
      verificationReportPath: verificationPath,
      integrity: integrity,
    );
  }

  Future<void> _ensureElectionExists() async {
    final database = _database.db;
    final rows = await database.query(
      'election',
      where: 'is_active = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return;
    }

    await database.insert('election', {
      'title': 'MOSB Genel Kurul',
      'status': electionStatusToDb(ElectionStatus.setup),
      'is_active': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  ElectionSnapshot _requireSnapshot() {
    final current = _snapshot;
    if (current == null) {
      throw StateError('Seçim servisi henüz başlatılmadı.');
    }
    return current;
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _slugify(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isEmpty ? 'election' : normalized;
  }

  bool _isSeqNoConstraintError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('unique constraint failed') &&
        text.contains('vote_ledger.seq_no');
  }
}
