import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/app_shell.dart';
import '../widgets/charts.dart';
import '../widgets/chips.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DashboardProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final user = context.watch<AuthProvider>().user;
    final data = dash.data;

    Widget body;
    if (dash.loading && data == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (dash.error != null) {
      body = Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(dash.error!),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.read<DashboardProvider>().load(),
            child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Try again')),
          ),
        ]),
      );
    } else if (data == null || user == null) {
      body = const SizedBox.shrink();
    } else {
      body = _Content(data: data, user: user);
    }

    return AppShell(title: 'Overview', activeLabel: 'Dashboard', child: body);
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.user});
  final DashboardData data;
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 900;
      final recent = _RecentCard(complaints: data.recent, isCitizen: user.role == UserRole.citizen, listRoute: user.role.listRoute);
      final cats = _CategoryCard(shares: data.categories);
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          _Greeting(user: user),
          const SizedBox(height: 16),
          _StatsPanel(d: data),
          const SizedBox(height: 18),
          _TrendCard(d: data),
          const SizedBox(height: 18),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: recent),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: cats),
            ])
          else ...[
            recent,
            const SizedBox(height: 18),
            cats,
          ],
        ],
      );
    });
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final sub = switch (user.role) {
      UserRole.citizen => 'Here is where your complaints stand.',
      UserRole.staff => 'Complaints routed to ${officeById(user.officeId ?? 7).shortName}.',
      UserRole.admin => 'Citywide complaint activity.',
    };
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 12,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Hello, ${user.firstName}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(color: AppColors.muted)),
        ]),
        if (user.role == UserRole.citizen)
          ElevatedButton.icon(
            onPressed: () => context.go('/submit-complaint'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Submit a complaint'),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stats panel (Pending / In Progress / Solved + service level + feedback)
// ---------------------------------------------------------------------------
class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.d});
  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final stats = [
      _StatBlock(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.seal,
        label: 'Pending',
        value: d.pending,
        delta: d.pendingDelta,
        goodWhenUp: false,
      ),
      _StatBlock(
        icon: Icons.autorenew_rounded,
        color: const Color(0xFFEF9F1A),
        label: 'In Progress',
        value: d.inProgress,
        delta: d.inProgressDelta,
        goodWhenUp: true,
      ),
      _StatBlock(
        icon: Icons.task_alt_rounded,
        color: AppColors.forest,
        label: 'Solved',
        value: d.solved,
        delta: d.solvedDelta,
        goodWhenUp: true,
      ),
    ];
    final ring = _ServiceRing(level: d.serviceLevel, target: d.serviceTarget);
    final feedback = _Feedback(rating: d.feedbackRating);

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 860;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppColors.panel, borderRadius: BorderRadius.circular(22)),
        child: wide
            ? Row(children: [
                Expanded(
                  flex: 6,
                  child: Row(children: [
                    for (var i = 0; i < stats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: stats[i]),
                    ],
                  ]),
                ),
                Container(width: 1, height: 160, color: AppColors.line, margin: const EdgeInsets.symmetric(horizontal: 22)),
                Expanded(
                  flex: 5,
                  child: Row(children: [Expanded(child: Center(child: ring)), Expanded(child: Center(child: feedback))]),
                ),
              ])
            : Column(children: [
                Wrap(spacing: 28, runSpacing: 20, children: [
                  for (final s in stats) SizedBox(width: 150, child: s),
                ]),
                const SizedBox(height: 20),
                const Divider(color: AppColors.line),
                const SizedBox(height: 12),
                Wrap(spacing: 32, runSpacing: 20, alignment: WrapAlignment.center, children: [ring, feedback]),
              ]),
      );
    });
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.delta,
    required this.goodWhenUp,
  });
  final IconData icon;
  final Color color;
  final String label;
  final int value, delta;
  final bool goodWhenUp;

  @override
  Widget build(BuildContext context) {
    final good = delta == 0 ? true : (delta > 0) == goodWhenUp;
    final badge = good ? AppColors.forest : AppColors.star;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 30),
      const SizedBox(height: 10),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      const Text('Last 7 days', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 8),
      Row(children: [
        Text('$value', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, height: 1.1)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(10)),
          child: Text('${delta > 0 ? '+' : ''}$delta%',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 12),
      Container(height: 3, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    ]);
  }
}

class _ServiceRing extends StatelessWidget {
  const _ServiceRing({required this.level, required this.target});
  final double level, target;

  @override
  Widget build(BuildContext context) {
    final color = level >= target ? AppColors.forest : const Color(0xFFEF9F1A);
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(alignment: Alignment.center, children: [
        Positioned.fill(child: CustomPaint(painter: RingPainter(value: level / 100, color: color))),
        Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Service Level', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text('${level.toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text('Target ${target.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.muted, fontSize: 11.5)),
        ]),
      ]),
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.sentiment_satisfied_alt_rounded, size: 46, color: AppColors.navy),
      const SizedBox(height: 8),
      const Text('Feedback Rating', style: TextStyle(fontWeight: FontWeight.w800)),
      const Text('All time', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 6),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          const Text('of 5', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600)),
        ],
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Total complaints trend
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.d});
  final DashboardData d;

  @override
  Widget build(BuildContext context) {
    final hasData = d.pendingSeries.length >= 2 && d.chartLabels.length == d.pendingSeries.length;
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Total Complaints', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.line),
            ),
            child: const Text('Last 14 days', style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: const [
          _Legend(color: Color(0xFF2F6BDB), label: 'Pending'),
          SizedBox(width: 16),
          _Legend(color: Color(0xFF35C2F0), label: 'In Progress'),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 260,
          child: hasData
              ? LineChartView(
                  labels: d.chartLabels,
                  a: d.pendingSeries,
                  b: d.inProgressSeries,
                  aName: 'Pending',
                  bName: 'In Progress',
                  aColor: const Color(0xFF2F6BDB),
                  bColor: const Color(0xFF35C2F0),
                )
              : const Center(child: Text('No chart data yet.', style: TextStyle(color: AppColors.muted))),
        ),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 4, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      ]);
}

// ---------------------------------------------------------------------------
// Recent complaints + category bars
// ---------------------------------------------------------------------------
class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.complaints, required this.isCitizen, required this.listRoute});
  final List<Complaint> complaints;
  final bool isCitizen;
  final String listRoute;

  @override
  Widget build(BuildContext context) {
    const head = TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.muted);
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Recent Complaints', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          TextButton(onPressed: () => context.go(listRoute), child: const Text('View all')),
        ]),
        const SizedBox(height: 8),
        if (complaints.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(children: [
                const Icon(Icons.inbox_outlined, size: 36, color: AppColors.muted),
                const SizedBox(height: 8),
                Text(isCitizen ? 'No complaints yet.' : 'No complaints to show.',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                if (isCitizen) ...[
                  const SizedBox(height: 4),
                  const Text('File one and it will show up here.', style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.go('/submit-complaint'), child: const Text('Submit a complaint')),
                ],
              ]),
            ),
          )
        else ...[
          const Row(children: [
            Expanded(flex: 3, child: Text('Date', style: head)),
            Expanded(flex: 4, child: Text('Category', style: head)),
            Expanded(flex: 3, child: Text('Priority', style: head)),
            Expanded(flex: 3, child: Text('Status', style: head)),
          ]),
          const Divider(color: AppColors.line, height: 18),
          for (final c in complaints) ...[
            InkWell(onTap: () => context.go('/complaints/${c.id}'), child: Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(flex: 3, child: Text(fmtDate(c.createdAt), style: const TextStyle(fontSize: 12))),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(categoryById(c.categoryId).name,
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                ),
              ),
              Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: PriorityChip(c.priority))),
              Expanded(flex: 3, child: Align(alignment: Alignment.centerLeft, child: StatusChip(c.status))),
            ]))),
            const Divider(color: AppColors.line, height: 14),
          ],
        ],
      ]),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.shares});
  final List<CategoryShare> shares;

  static const _colors = [AppColors.navy, Color(0xFFEF9F1A), AppColors.forest, AppColors.seal];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Complaints in Category', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (shares.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Categories appear after the first complaint.', style: TextStyle(color: AppColors.muted))),
          )
        else
          for (var i = 0; i < shares.length; i++) ...[
            Row(children: [
              Expanded(child: Text(shares[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              Text('${shares[i].percent}%', style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: shares[i].percent / 100,
                minHeight: 8,
                backgroundColor: AppColors.line,
                color: _colors[i % _colors.length],
              ),
            ),
            const SizedBox(height: 16),
          ],
      ]),
    );
  }
}
