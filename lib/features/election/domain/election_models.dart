enum ElectionStatus { setup, locked, counting, finalized }

ElectionStatus electionStatusFromDb(String value) {
  switch (value) {
    case 'setup':
      return ElectionStatus.setup;
    case 'locked':
      return ElectionStatus.locked;
    case 'counting':
      return ElectionStatus.counting;
    case 'finalized':
      return ElectionStatus.finalized;
    default:
      throw ArgumentError('Bilinmeyen seçim durumu: $value');
  }
}

String electionStatusToDb(ElectionStatus status) {
  switch (status) {
    case ElectionStatus.setup:
      return 'setup';
    case ElectionStatus.locked:
      return 'locked';
    case ElectionStatus.counting:
      return 'counting';
    case ElectionStatus.finalized:
      return 'finalized';
  }
}

String electionStatusLabel(ElectionStatus status) {
  switch (status) {
    case ElectionStatus.setup:
      return 'Kurulum (Aday Girişi)';
    case ElectionStatus.locked:
      return 'Kilitli (Sayım Başlatılabilir)';
    case ElectionStatus.counting:
      return 'Sayım Devam Ediyor';
    case ElectionStatus.finalized:
      return 'Kesinleşti (Salt Okunur)';
  }
}

class Candidate {
  const Candidate({
    required this.id,
    required this.electionId,
    required this.entryOrder,
    required this.displayName,
    required this.createdAt,
  });

  final int id;
  final int electionId;
  final int entryOrder;
  final String displayName;
  final DateTime createdAt;
}

class VoteRecord {
  const VoteRecord({
    required this.seqNo,
    required this.electionId,
    required this.candidateId,
    required this.createdAt,
    required this.prevHash,
    required this.recordHash,
  });

  final int seqNo;
  final int electionId;
  final int candidateId;
  final DateTime createdAt;
  final String prevHash;
  final String recordHash;
}

class ElectionSnapshot {
  const ElectionSnapshot({
    required this.electionId,
    required this.title,
    required this.status,
    required this.candidates,
    required this.countsByCandidate,
    required this.totalVotes,
    required this.lastActionAt,
  });

  final int electionId;
  final String title;
  final ElectionStatus status;
  final List<Candidate> candidates;
  final Map<int, int> countsByCandidate;
  final int totalVotes;
  final DateTime? lastActionAt;
}

class IntegrityReport {
  const IntegrityReport({required this.isValid, required this.details});

  final bool isValid;
  final String details;
}

class CandidateStanding {
  const CandidateStanding({required this.candidate, required this.votes});

  final Candidate candidate;
  final int votes;
}

class AuditExportResult {
  const AuditExportResult({
    required this.directoryPath,
    required this.ledgerCsvPath,
    required this.summaryJsonPath,
    required this.verificationReportPath,
    required this.integrity,
  });

  final String directoryPath;
  final String ledgerCsvPath;
  final String summaryJsonPath;
  final String verificationReportPath;
  final IntegrityReport integrity;
}
