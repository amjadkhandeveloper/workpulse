import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/job.dart';

class JobReviewScreen extends ConsumerStatefulWidget {
  const JobReviewScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobReviewScreen> createState() => _JobReviewScreenState();
}

class _JobReviewScreenState extends ConsumerState<JobReviewScreen> {
  Job? _job;
  List<({JobProof proof, String url})> _proofs = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(jobRepositoryProvider);
    final job = await repo.getById(widget.jobId);
    final proofs = await repo.listProofs(widget.jobId);
    final withUrls = <({JobProof proof, String url})>[];
    for (final proof in proofs) {
      withUrls.add((proof: proof, url: await repo.signedProofUrl(proof.storagePath)));
    }
    if (!mounted) return;
    setState(() {
      _job = job;
      _proofs = withUrls;
    });
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await ref.read(jobRepositoryProvider).setStatus(
            widget.jobId,
            JobStatus.completed,
            extra: {
              'reviewed_by': ref.read(sessionControllerProvider).profile?.id,
              'reviewed_at': DateTime.now().toUtc().toIso8601String(),
            },
          );
      ref.invalidate(adminJobsProvider);
      ref.invalidate(adminStatsProvider);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) showAppSnack(context, '$error', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = _job;
    return Scaffold(
      appBar: AppBar(title: const Text('Review job')),
      body: job == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(job.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text('Job ID ${job.displayId} • ${job.assignee?.name ?? 'Unassigned'}'),
                const SizedBox(height: 12),
                if (job.checkoutNote != null) Text(job.checkoutNote!),
                const SizedBox(height: 16),
                const Text('Proof photos', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _proofs
                      .where((p) => p.proof.kind == ProofKind.photo)
                      .map(
                        (p) => ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: p.url,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text('Signature', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._proofs.where((p) => p.proof.kind == ProofKind.signature).map(
                      (p) => CachedNetworkImage(imageUrl: p.url, height: 140),
                    ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Mark complete',
                  color: AppColors.success,
                  onPressed: _complete,
                  busy: _busy,
                ),
              ],
            ),
    );
  }
}
