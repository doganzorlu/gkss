import 'election_models.dart';

List<CandidateStanding> buildStandings(ElectionSnapshot snapshot) {
  final standings = snapshot.candidates
      .map(
        (candidate) => CandidateStanding(
          candidate: candidate,
          votes: snapshot.countsByCandidate[candidate.id] ?? 0,
        ),
      )
      .toList();

  standings.sort((a, b) {
    final votesCompare = b.votes.compareTo(a.votes);
    if (votesCompare != 0) {
      return votesCompare;
    }
    return a.candidate.entryOrder.compareTo(b.candidate.entryOrder);
  });

  return standings;
}
