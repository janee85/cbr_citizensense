import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/models.dart';
import 'chips.dart';

/// "ML Classification Result Card" from Activity 6: category, sentiment,
/// priority, confidence, and the office the complaint will go to.
class ClassificationCard extends StatelessWidget {
  const ClassificationCard({
    super.key,
    required this.hasCategory,
    required this.loading,
    this.result,
    this.error,
    this.title = 'Priority check',
  });
  final String title;
  final bool hasCategory;
  final bool loading;
  final Classification? result;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final r = result;
    Widget content;
    if (!hasCategory) {
      content = const _Idle();
    } else if (error != null && r == null) {
      content = _Notice(
        icon: Icons.cloud_off_rounded,
        text: 'Could not rate the priority right now. You can still submit; the server will classify it.',
      );
    } else if (r == null) {
      content = const _Analyzing();
    } else {
      content = _Result(r: r, loading: loading);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.navy),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          if (loading && r != null)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ]),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey('${hasCategory}_${r?.priority.name}_${r == null ? loading : false}'),
            child: content,
          ),
        ),
      ]),
    );
  }
}

class _Idle extends StatelessWidget {
  const _Idle();

  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Choose a category and the system rates how urgent your complaint is, right away.',
            style: TextStyle(color: AppColors.muted, height: 1.45)),
        SizedBox(height: 18),
        PriorityMeter(),
      ]);
}

class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) => const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Analyzing your complaint…', style: TextStyle(fontWeight: FontWeight.w600)),
        SizedBox(height: 14),
        LinearProgressIndicator(minHeight: 6, color: AppColors.navy, backgroundColor: AppColors.line),
      ]);
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: AppColors.muted, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted, height: 1.45))),
      ]);
}

class _Result extends StatelessWidget {
  const _Result({required this.r, required this.loading});
  final Classification r;
  final bool loading;

  IconData get _sentimentIcon => switch (r.sentiment) {
        'negative' => Icons.sentiment_dissatisfied_rounded,
        'positive' => Icons.sentiment_satisfied_alt_rounded,
        _ => Icons.sentiment_neutral_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = r.priority;
    final office = r.officeId == null ? null : officeById(r.officeId!);
    return Opacity(
      opacity: loading ? 0.55 : 1,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(p.label, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: p.color)),
          const SizedBox(width: 8),
          const Text('priority', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        PriorityMeter(priority: p),
        const SizedBox(height: 12),
        Text(p.blurb, style: const TextStyle(height: 1.45)),
        const SizedBox(height: 16),
        const Divider(color: AppColors.line, height: 1),
        const SizedBox(height: 14),
        _Row(label: 'Category', child: Text(r.category, style: const TextStyle(fontWeight: FontWeight.w700))),
        _Row(
          label: 'Sentiment',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_sentimentIcon, size: 18, color: AppColors.navy),
            const SizedBox(width: 6),
            Text(r.sentiment[0].toUpperCase() + r.sentiment.substring(1),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        _Row(
          label: 'Confidence',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: r.confidence,
                  minHeight: 6,
                  color: AppColors.navy,
                  backgroundColor: AppColors.line,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(r.confidence * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
          ]),
        ),
        if (office != null)
          _Row(label: 'Suggested office', child: Text(office.shortName, style: const TextStyle(fontWeight: FontWeight.w700))),
        if (r.categoryOnly) ...[
          const SizedBox(height: 10),
          const _Notice(
            icon: Icons.edit_note_rounded,
            text: 'Based on the category only. Describe the problem for a more accurate rating.',
          ),
        ] else if (r.keywords.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Picked up from your description', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final k in r.keywords)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(14)),
                child: Text(k, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.navy)),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Flexible(child: Align(alignment: Alignment.centerRight, child: child)),
        ]),
      );
}
