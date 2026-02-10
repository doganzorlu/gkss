import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gkss/features/election/application/election_service.dart';
import 'package:gkss/features/election/data/election_database.dart';
import 'package:gkss/features/election/domain/election_models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  ElectionService createService() {
    final uniquePath =
        '${inMemoryDatabasePath}_${DateTime.now().microsecondsSinceEpoch}';
    return ElectionService(
      ElectionDatabase(factory: databaseFactoryFfi, databasePath: uniquePath),
    );
  }

  test('candidate list can only be changed during setup', () async {
    final service = createService();
    await service.initialize();

    await service.addCandidate('Aday 1');
    await service.lockCandidates();

    await expectLater(
      () => service.addCandidate('Aday 2'),
      throwsA(isA<StateError>()),
    );
  });

  test('election title can only be updated during setup', () async {
    final service = createService();
    await service.initialize();

    await service.updateElectionTitle('2026 Genel Kurul');
    expect(service.snapshot!.title, '2026 Genel Kurul');

    await service.addCandidate('Aday 1');
    await service.lockCandidates();

    await expectLater(
      () => service.updateElectionTitle('Yeni Baslik'),
      throwsA(isA<StateError>()),
    );
  });

  test('bulk candidate entry preserves entry order', () async {
    final service = createService();
    await service.initialize();

    await service.addCandidatesBulk(['Aday A', 'Aday B', 'Aday C']);

    final candidates = service.snapshot!.candidates;
    expect(candidates.length, 3);
    expect(candidates[0].entryOrder, 1);
    expect(candidates[0].displayName, 'Aday A');
    expect(candidates[1].entryOrder, 2);
    expect(candidates[1].displayName, 'Aday B');
    expect(candidates[2].entryOrder, 3);
    expect(candidates[2].displayName, 'Aday C');
  });

  test('candidate can be renamed during setup', () async {
    final service = createService();
    await service.initialize();
    await service.addCandidate('Aday Eski');

    final candidateId = service.snapshot!.candidates.first.id;
    await service.renameCandidate(
      candidateId: candidateId,
      newDisplayName: 'Aday Yeni',
    );

    expect(service.snapshot!.candidates.first.displayName, 'Aday Yeni');
  });

  test(
    'candidate can be deleted during setup and order is reindexed',
    () async {
      final service = createService();
      await service.initialize();
      await service.addCandidatesBulk(['Aday A', 'Aday B', 'Aday C']);

      final secondId = service.snapshot!.candidates[1].id;
      await service.deleteCandidate(secondId);

      final candidates = service.snapshot!.candidates;
      expect(candidates.length, 2);
      expect(candidates[0].displayName, 'Aday A');
      expect(candidates[0].entryOrder, 1);
      expect(candidates[1].displayName, 'Aday C');
      expect(candidates[1].entryOrder, 2);
    },
  );

  test('votes only increment during counting', () async {
    final service = createService();
    await service.initialize();

    await service.addCandidate('Aday 1');

    final candidateId = service.snapshot!.candidates.first.id;

    await expectLater(
      () => service.incrementVote(candidateId),
      throwsA(isA<StateError>()),
    );

    await service.lockCandidates();
    await service.startCounting();
    await service.incrementVote(candidateId);

    expect(service.snapshot!.totalVotes, 1);
    expect(service.snapshot!.countsByCandidate[candidateId], 1);
  });

  test('finalized election is read-only for vote increments', () async {
    final service = createService();
    await service.initialize();

    await service.addCandidate('Aday 1');
    final candidateId = service.snapshot!.candidates.first.id;

    await service.lockCandidates();
    await service.startCounting();
    await service.incrementVote(candidateId);
    await service.finalizeElection();

    expect(service.snapshot!.status, ElectionStatus.finalized);

    await expectLater(
      () => service.incrementVote(candidateId),
      throwsA(isA<StateError>()),
    );
  });

  test('ledger integrity verification succeeds for valid chain', () async {
    final service = createService();
    await service.initialize();

    await service.addCandidate('Aday 1');
    await service.addCandidate('Aday 2');

    final candidates = service.snapshot!.candidates;

    await service.lockCandidates();
    await service.startCounting();

    await service.incrementVote(candidates[0].id);
    await service.incrementVote(candidates[1].id);
    await service.incrementVote(candidates[0].id);

    final report = await service.verifyIntegrity();

    expect(report.isValid, isTrue);
    expect(report.details, contains('3 kayıt kontrol edildi'));
  });

  test('audit export writes ledger and verification files', () async {
    final service = createService();
    await service.initialize();

    await service.updateElectionTitle('Genel Kurul 2026');
    await service.addCandidatesBulk(['Aday 1', 'Aday 2']);
    final candidates = service.snapshot!.candidates;
    await service.lockCandidates();
    await service.startCounting();
    await service.incrementVote(candidates.first.id);
    await service.finalizeElection();

    final exportRoot = Directory.systemTemp.createTempSync(
      'sandik_export_test_',
    );
    addTearDown(() async {
      if (exportRoot.existsSync()) {
        await exportRoot.delete(recursive: true);
      }
    });

    final result = await service.exportAuditPackage(
      outputBaseDirectory: exportRoot.path,
    );

    expect(File(result.ledgerCsvPath).existsSync(), isTrue);
    expect(File(result.summaryJsonPath).existsSync(), isTrue);
    expect(File(result.verificationReportPath).existsSync(), isTrue);

    final ledgerText = File(result.ledgerCsvPath).readAsStringSync();
    final reportText = File(result.verificationReportPath).readAsStringSync();

    expect(ledgerText, contains('seq_no,election_id,candidate_id'));
    expect(ledgerText, contains('Aday 1'));
    expect(reportText, contains('BütünlükGeçerli: true'));
  });

  test(
    'can open a new election session after finalized while preserving old data',
    () async {
      final service = createService();
      await service.initialize();

      await service.updateElectionTitle('Test Sayımı 1');
      await service.addCandidate('Aday 1');
      final candidateId = service.snapshot!.candidates.first.id;
      await service.lockCandidates();
      await service.startCounting();
      await service.incrementVote(candidateId);
      await service.finalizeElection();

      final previousElectionId = service.snapshot!.electionId;
      expect(service.snapshot!.status, ElectionStatus.finalized);

      await service.startNewElectionSession('Test Sayımı 2');

      expect(service.snapshot!.electionId, isNot(previousElectionId));
      expect(service.snapshot!.title, 'Test Sayımı 2');
      expect(service.snapshot!.status, ElectionStatus.setup);
      expect(service.snapshot!.totalVotes, 0);
      expect(service.snapshot!.candidates, isEmpty);
    },
  );

  test(
    'can record votes in a new session after previous session is finalized',
    () async {
      final service = createService();
      await service.initialize();

      await service.updateElectionTitle('İlk Sayım');
      await service.addCandidate('Aday 1');
      final firstCandidateId = service.snapshot!.candidates.first.id;
      await service.lockCandidates();
      await service.startCounting();
      await service.incrementVote(firstCandidateId);
      await service.finalizeElection();

      await service.startNewElectionSession('İkinci Sayım');
      await service.addCandidate('Aday 2');
      final secondCandidateId = service.snapshot!.candidates.first.id;
      await service.lockCandidates();
      await service.startCounting();
      await service.incrementVote(secondCandidateId);

      expect(service.snapshot!.totalVotes, 1);
      expect(service.snapshot!.countsByCandidate[secondCandidateId], 1);

      final integrity = await service.verifyIntegrity();
      expect(integrity.isValid, isTrue);
    },
  );
}
