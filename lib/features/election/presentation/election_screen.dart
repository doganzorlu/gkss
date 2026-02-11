import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';

import '../../../core/utils/time_format.dart';
import '../application/election_service.dart';
import '../domain/election_models.dart';
import '../domain/ranking.dart';

class ElectionScreen extends StatefulWidget {
  const ElectionScreen({super.key, required this.service});

  final ElectionService service;

  @override
  State<ElectionScreen> createState() => _ElectionScreenState();
}

class _ElectionScreenState extends State<ElectionScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _candidateController = TextEditingController();
  final TextEditingController _bulkCandidateController =
      TextEditingController();
  final ScrollController _setupPanelScrollController = ScrollController();
  String _feedbackMessage = 'Sistem hazır.';
  bool _feedbackIsError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _candidateController.dispose();
    _bulkCandidateController.dispose();
    _setupPanelScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final snapshot = widget.service.snapshot;
        if (snapshot == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_titleController.text.isEmpty ||
            _titleController.text != snapshot.title) {
          _titleController.text = snapshot.title;
        }

        final standings = _buildDisplayStandings(snapshot);
        const appBarTitleFontSize = 38.0;
        const appBarLogoHeight = appBarTitleFontSize * (8 / 3);
        final appBarToolbarHeight = (appBarLogoHeight + 10.0).clamp(
          kToolbarHeight,
          220.0,
        );

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: appBarToolbarHeight,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Image.asset(
                    'lib/assets/images/mosb_logo.png',
                    height: appBarLogoHeight,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: appBarLogoHeight,
                    child: const VerticalDivider(thickness: 1.4, width: 1),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MOSB Genel Kurul Sayım Sistemi',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: appBarTitleFontSize,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          snapshot.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w600,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: _StatusBadge(status: snapshot.status),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final setupPanelHeight = _calculateSetupPanelHeight(
                  constraints.maxHeight,
                  snapshot.status,
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummary(snapshot),
                    const SizedBox(height: 12),
                    if (snapshot.status == ElectionStatus.setup) ...[
                      SizedBox(
                        height: setupPanelHeight,
                        child: Scrollbar(
                          controller: _setupPanelScrollController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _setupPanelScrollController,
                            child: _buildSetupPanel(snapshot),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Expanded(
                      child: _buildCandidateListCard(snapshot, standings),
                    ),
                    const SizedBox(height: 12),
                    SafeArea(top: false, child: _buildActions(snapshot)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary(ElectionSnapshot snapshot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                Text(
                  'Seçim: ${snapshot.title}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Toplam Oy: ${snapshot.totalVotes}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Son İşlem: ${formatTimestamp(snapshot.lastActionAt)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _feedbackIsError
                    ? Colors.red.withValues(alpha: 0.12)
                    : Colors.green.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _feedbackIsError ? Colors.red : Colors.green,
                ),
              ),
              child: Text(
                _feedbackMessage,
                style: TextStyle(
                  fontSize: 15,
                  color: _feedbackIsError
                      ? Colors.red.shade900
                      : Colors.green.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<CandidateStanding> _buildDisplayStandings(ElectionSnapshot snapshot) {
    if (snapshot.status == ElectionStatus.finalized) {
      return buildStandings(snapshot);
    }

    return snapshot.candidates
        .map(
          (candidate) => CandidateStanding(
            candidate: candidate,
            votes: snapshot.countsByCandidate[candidate.id] ?? 0,
          ),
        )
        .toList();
  }

  Widget _buildCandidateListCard(
    ElectionSnapshot snapshot,
    List<CandidateStanding> standings,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final candidateCount = standings.isEmpty ? 1 : standings.length;
            final headerHeight = 54.0;
            final separatorCount = standings.isEmpty ? 0 : standings.length - 1;
            final listAreaHeight = (constraints.maxHeight - headerHeight).clamp(
              80.0,
              constraints.maxHeight,
            );
            final rowHeight =
                (listAreaHeight - separatorCount) / candidateCount;
            final typography = _candidateTypography(
              context: context,
              rowHeight: rowHeight,
              candidateCount: standings.length,
            );
            final isCompact = rowHeight < 68;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Aday Listesi (Sabit Sıra)',
                  style: TextStyle(
                    fontSize: typography.titleSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: standings.isEmpty
                      ? const Center(child: Text('Aday bulunmuyor.'))
                      : ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: standings.length,
                          itemExtent: rowHeight,
                          itemBuilder: (context, index) {
                            final standing = standings[index];
                            final canIncrement =
                                snapshot.status == ElectionStatus.counting;
                            final isSetup =
                                snapshot.status == ElectionStatus.setup;

                            return Container(
                              decoration: BoxDecoration(
                                border: index == standings.length - 1
                                    ? null
                                    : const Border(
                                        bottom: BorderSide(
                                          color: Colors.black12,
                                        ),
                                      ),
                              ),
                              child: ListTile(
                                dense: isCompact,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: isCompact ? 2 : 6,
                                ),
                                leading: CircleAvatar(
                                  radius: isCompact ? 16 : 20,
                                  child: Text(
                                    '${standing.candidate.entryOrder}',
                                    style: TextStyle(
                                      fontSize: typography.orderSize,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  standing.candidate.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: typography.nameSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Oy: ${standing.votes}',
                                  style: TextStyle(
                                    fontSize: typography.voteSize,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                trailing: isSetup
                                    ? _buildSetupTrailingActions(
                                        standing.candidate,
                                        typography.buttonSize,
                                        isCompact,
                                      )
                                    : _buildCountTrailingAction(
                                        standing.candidate,
                                        canIncrement,
                                        typography.buttonSize,
                                        isCompact,
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSetupTrailingActions(
    Candidate candidate,
    double buttonFontSize,
    bool isCompact,
  ) {
    if (isCompact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Düzenle',
            onPressed: () => _showRenameCandidateDialog(candidate),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Sil',
            onPressed: () => _confirmDeleteCandidate(candidate),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton(
          onPressed: () => _showRenameCandidateDialog(candidate),
          child: Text('Düzelt', style: TextStyle(fontSize: buttonFontSize)),
        ),
        OutlinedButton(
          onPressed: () => _confirmDeleteCandidate(candidate),
          child: Text('Sil', style: TextStyle(fontSize: buttonFontSize)),
        ),
      ],
    );
  }

  Widget _buildCountTrailingAction(
    Candidate candidate,
    bool canIncrement,
    double buttonFontSize,
    bool isCompact,
  ) {
    return FilledButton(
      onPressed: canIncrement ? () => _confirmAndIncrement(candidate) : null,
      child: isCompact
          ? const Icon(Icons.add)
          : Text('Oy +1', style: TextStyle(fontSize: buttonFontSize)),
    );
  }

  double _calculateSetupPanelHeight(
    double availableHeight,
    ElectionStatus status,
  ) {
    if (status != ElectionStatus.setup) {
      return 0;
    }
    const reservedForSummaryAndActions = 220.0;
    const minCandidateArea = 170.0;

    final usable = availableHeight - reservedForSummaryAndActions;
    if (usable <= 0) {
      return 120.0;
    }

    final preferred = usable * 0.34;
    final maxAllowed = usable - minCandidateArea;
    final upperBound = maxAllowed < 120.0 ? 120.0 : maxAllowed;
    return preferred.clamp(120.0, upperBound);
  }

  _CandidateTypography _candidateTypography({
    required BuildContext context,
    required double rowHeight,
    required int candidateCount,
  }) {
    final width = MediaQuery.of(context).size.width;
    final widthScale = width >= 1800
        ? 1.14
        : width >= 1400
        ? 1.0
        : width >= 1100
        ? 0.92
        : 0.85;
    final densityScale = candidateCount >= 18
        ? 0.72
        : candidateCount >= 12
        ? 0.84
        : candidateCount >= 8
        ? 0.92
        : 1.0;
    final baseScale = widthScale * densityScale;

    final name = (rowHeight * 0.32 * baseScale).clamp(12.0, 42.0);
    final vote = (rowHeight * 0.25 * baseScale).clamp(11.0, 36.0);
    final order = (rowHeight * 0.22 * baseScale).clamp(10.0, 30.0);
    final button = (rowHeight * 0.20 * baseScale).clamp(10.0, 24.0);
    final title = (rowHeight * 0.28 * baseScale).clamp(14.0, 30.0);

    return _CandidateTypography(
      titleSize: title,
      nameSize: name,
      voteSize: vote,
      orderSize: order,
      buttonSize: button,
    );
  }

  Widget _buildSetupPanel(ElectionSnapshot snapshot) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Kurulum',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Seçim başlığı',
                      hintText: 'Örn: 2026 Genel Kurul Başkanlık Seçimi',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.service.updateElectionTitle(
                        _titleController.text,
                      );
                      if (!mounted) {
                        return;
                      }
                      _showMessage('Seçim başlığı güncellendi.');
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }
                      _showMessage(error.toString(), isError: true);
                    }
                  },
                  child: const Text('Başlığı Kaydet'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _candidateController,
                    decoration: const InputDecoration(
                      labelText: 'Tek aday ekle',
                      hintText: 'Aday adını giriniz',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    try {
                      await widget.service.addCandidate(
                        _candidateController.text,
                      );
                      _candidateController.clear();
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }
                      _showMessage(error.toString(), isError: true);
                    }
                  },
                  child: const Text('Aday Ekle'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bulkCandidateController,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Toplu aday girişi',
                hintText: 'Her satıra bir aday gelecek şekilde yapıştırın.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton(
                  onPressed: () async {
                    final names = _bulkCandidateController.text
                        .split('\n')
                        .map((line) => line.trim())
                        .where((line) => line.isNotEmpty)
                        .toList();
                    try {
                      await widget.service.addCandidatesBulk(names);
                      _bulkCandidateController.clear();
                      if (!mounted) {
                        return;
                      }
                      _showMessage('${names.length} aday eklendi.');
                    } catch (error) {
                      if (!mounted) {
                        return;
                      }
                      _showMessage(error.toString(), isError: true);
                    }
                  },
                  child: const Text('Toplu Ekle'),
                ),
                Text('Aday sayısı: ${snapshot.candidates.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(ElectionSnapshot snapshot) {
    final canLock = snapshot.status == ElectionStatus.setup;
    final canStart = snapshot.status == ElectionStatus.locked;
    final canFinalize = snapshot.status == ElectionStatus.counting;
    final canOpenNewSession = snapshot.status == ElectionStatus.finalized;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton(
          onPressed: canLock
              ? () async {
                  final approved = await _confirmLockCandidates(snapshot);
                  if (approved != true) {
                    return;
                  }

                  try {
                    await widget.service.lockCandidates();
                    if (!mounted) {
                      return;
                    }
                    _showMessage('Aday listesi kilitlendi.');
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }
                    _showMessage(error.toString(), isError: true);
                  }
                }
              : null,
          child: const Text('Adayları Kilitle'),
        ),
        FilledButton(
          onPressed: canStart
              ? () async {
                  try {
                    await widget.service.startCounting();
                    if (!mounted) {
                      return;
                    }
                    _showMessage('Sayım başlatıldı.');
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }
                    _showMessage(error.toString(), isError: true);
                  }
                }
              : null,
          child: const Text('Sayımı Başlat'),
        ),
        FilledButton(
          onPressed: canFinalize
              ? () async {
                  final approved = await _confirmFinalizeElection();
                  if (approved != true) {
                    return;
                  }
                  try {
                    await widget.service.finalizeElection();
                    if (!mounted) {
                      return;
                    }
                    _showMessage('Seçim kesinleştirildi.');
                  } catch (error) {
                    if (!mounted) {
                      return;
                    }
                    _showMessage(error.toString(), isError: true);
                  }
                }
              : null,
          child: const Text('Kesinleştir'),
        ),
        OutlinedButton(
          onPressed: canOpenNewSession ? _openNewElectionSessionDialog : null,
          child: const Text('Yeni Sayım Aç'),
        ),
        OutlinedButton(
          onPressed: () async {
            final report = await widget.service.verifyIntegrity();
            if (!mounted) {
              return;
            }
            _showMessage(report.details, isError: !report.isValid);
          },
          child: const Text('Bütünlük Doğrula'),
        ),
        OutlinedButton(
          onPressed: () async {
            await _exportAuditPackageWithFolderSelection();
          },
          child: const Text('Denetim Paketi Üret'),
        ),
      ],
    );
  }

  Future<void> _exportAuditPackageWithFolderSelection() async {
    String? selectedDirectory;
    Object? pickerError;
    try {
      selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Denetim paketi için hedef klasör seçin',
        lockParentWindow: true,
      );
    } catch (error) {
      pickerError = error;
      selectedDirectory = await getDirectoryPath(
        confirmButtonText: 'Bu Klasöre Kaydet',
      );
    }

    if (selectedDirectory == null || selectedDirectory.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      if (pickerError != null) {
        _showMessage(
          'Klasör seçici açılamadı. macOS erişim iznini kontrol edin ve uygulamayı yeniden başlatın.',
          isError: true,
        );
      } else {
        _showMessage('Denetim paketi oluşturma iptal edildi.');
      }
      return;
    }

    try {
      final result = await widget.service.exportAuditPackage(
        outputBaseDirectory: selectedDirectory,
      );
      if (!mounted) {
        return;
      }
      _showMessage(
        'Denetim paketi oluşturuldu: ${result.directoryPath}',
        isError: !result.integrity.isValid,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<bool?> _confirmFinalizeElection() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kesinleştirme Onayı'),
          content: const Text(
            'Sayım kesinleştirildiğinde oy girişi durur. Devam etmek istiyor musunuz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Evet, Kesinleştir'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openNewElectionSessionDialog() async {
    final currentTitle = widget.service.snapshot?.title ?? '';
    final controller = TextEditingController(
      text: '$currentTitle - Yeni Sayım',
    );

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Yeni Sayım Aç'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Mevcut sayım arşivde saklanacak. Yeni bir sayım oturumu başlatılacak.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni sayım başlığı',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yeni Sayım Aç'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      controller.dispose();
      return;
    }

    try {
      await widget.service.startNewElectionSession(controller.text);
      if (!mounted) {
        return;
      }
      _showMessage('Yeni sayım oturumu açıldı.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    } finally {
      controller.dispose();
    }
  }

  Future<bool?> _confirmLockCandidates(ElectionSnapshot snapshot) {
    final candidates = snapshot.candidates;
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kilitleme Onayı'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Seçim: ${snapshot.title}'),
                const SizedBox(height: 8),
                const Text('Adaylar kilitlenecek. Bu işlem geri alınmaz.'),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final candidate in candidates)
                          Text(
                            '${candidate.entryOrder}. ${candidate.displayName}',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Onayla ve Kilitle'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRenameCandidateDialog(Candidate candidate) async {
    final controller = TextEditingController(text: candidate.displayName);
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aday Düzelt'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Aday adı'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      controller.dispose();
      return;
    }

    try {
      await widget.service.renameCandidate(
        candidateId: candidate.id,
        newDisplayName: controller.text,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Aday bilgisi güncellendi.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _confirmDeleteCandidate(Candidate candidate) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Aday Silme Onayı'),
          content: Text(
            '${candidate.entryOrder}. sıradaki ${candidate.displayName} adayı silinsin mi?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil'),
            ),
          ],
        );
      },
    );

    if (approved != true) {
      return;
    }

    try {
      await widget.service.deleteCandidate(candidate.id);
      if (!mounted) {
        return;
      }
      _showMessage('Aday silindi. Sıra numaraları güncellendi.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _confirmAndIncrement(Candidate candidate) async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: AlertDialog(
              title: const Text('Oy Artış Onayı'),
              content: Text(
                'Seçilen aday: ${candidate.displayName} (Sıra ${candidate.entryOrder})\n\nBu adaya +1 oy eklensin mi?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Onayla (+1)'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (approved != true) {
      return;
    }

    try {
      await widget.service.incrementVote(candidate.id);
      if (!mounted) {
        return;
      }
      _showMessage('${candidate.displayName} adayı için +1 oy kaydedildi.');
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showMessage(error.toString(), isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _feedbackMessage = text;
      _feedbackIsError = isError;
    });
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ElectionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ElectionStatus.setup => Colors.blue,
      ElectionStatus.locked => Colors.orange,
      ElectionStatus.counting => Colors.green,
      ElectionStatus.finalized => Colors.grey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color),
      ),
      child: Text(
        electionStatusLabel(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CandidateTypography {
  const _CandidateTypography({
    required this.titleSize,
    required this.nameSize,
    required this.voteSize,
    required this.orderSize,
    required this.buttonSize,
  });

  final double titleSize;
  final double nameSize;
  final double voteSize;
  final double orderSize;
  final double buttonSize;
}
