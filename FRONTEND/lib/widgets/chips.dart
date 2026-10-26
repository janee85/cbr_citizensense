import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';

extension PriorityUi on Priority {
  String get label => switch (this) {
        Priority.low => 'Low',
        Priority.medium => 'Medium',
        Priority.high => 'High',
        Priority.critical => 'Critical',
      };

  Color get color => switch (this) {
        Priority.low => AppColors.forest,
        Priority.medium => const Color(0xFFC99A0B),
        Priority.high => const Color(0xFFEF7D1A),
        Priority.critical => AppColors.star,
      };

  int get level => index + 1;

  String get blurb => switch (this) {
        Priority.low => 'Routine concern. It will be handled in the regular queue.',
        Priority.medium => 'Needs attention soon. Staff will review it after urgent cases.',
        Priority.high => 'Urgent. This is moved up the staff queue.',
        Priority.critical =>
          'Possible emergency. For life-threatening situations, also call 911.',
      };
}

class PriorityChip extends StatelessWidget {
  const PriorityChip(this.priority, {super.key});
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final c = priority.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(priority.label,
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

/// Four-step bar: Low / Medium / High / Critical.
class PriorityMeter extends StatelessWidget {
  const PriorityMeter({super.key, this.priority});
  final Priority? priority;

  @override
  Widget build(BuildContext context) {
    final level = priority?.level ?? 0;
    final color = priority?.color ?? AppColors.line;
    return Column(children: [
      Row(
        children: List.generate(4, (i) {
          return Expanded(
            child: Container(
              height: 10,
              margin: EdgeInsets.only(right: i == 3 ? 0 : 4),
              decoration: BoxDecoration(
                color: i < level ? color : AppColors.line,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 6),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: Priority.values
            .map((p) => Text(p.label,
                style: TextStyle(
                  fontSize: 11,
                  color: p == priority ? p.color : AppColors.muted,
                  fontWeight: p == priority ? FontWeight.w800 : FontWeight.w500,
                )))
            .toList(),
      ),
    ]);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final ComplaintStatus status;

  @override
  Widget build(BuildContext context) {
    final Color c;
    final bool filled;
    switch (status) {
      case ComplaintStatus.submitted:
      case ComplaintStatus.received:
        c = AppColors.seal;
        filled = false;
      case ComplaintStatus.inProgress:
        c = const Color(0xFFEF7D1A);
        filled = false;
      case ComplaintStatus.resolved:
      case ComplaintStatus.closed:
        c = AppColors.forest;
        filled = true;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? c : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c, width: 1.2),
      ),
      child: Text(status.label,
          style: TextStyle(
              color: filled ? Colors.white : c,
              fontWeight: FontWeight.w700,
              fontSize: 11.5)),
    );
  }
}

/// Horizontal bars for report breakdowns.
class BarList extends StatelessWidget {
  const BarList({super.key, required this.items, this.color = AppColors.navy});
  final List<(String, int, Color?)> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No data for these filters.', style: TextStyle(color: AppColors.muted)),
      );
    }
    final peak = items.map((e) => e.$2).fold<int>(1, (a, b) => b > a ? b : a);
    return Column(children: [
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(it.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Text('${it.$2}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: it.$2 / peak,
                minHeight: 8,
                backgroundColor: AppColors.line,
                color: it.$3 ?? color,
              ),
            ),
          ]),
        ),
    ]);
  }
}
