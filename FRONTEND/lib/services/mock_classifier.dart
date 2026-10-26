import '../core/constants.dart';
import '../models/models.dart';

/// Offline stand-in for the Flask NLP/ML component so the UI can be built and
/// demoed today. When USE_MOCK=false the same result shape comes from
/// POST /api/complaints/classify and this file is not used.
class MockClassifier {
  // Baseline urgency of each category (1..3).
  static const _base = {1: 2, 2: 2, 3: 3, 4: 1, 5: 3, 6: 3, 7: 2, 8: 2, 9: 1, 10: 1};

  static const _critical = [
    'sunog', 'fire', 'baha', 'flood', 'baril', 'gun', 'patay', 'namatay', 'dead',
    'died', 'emergency', 'aksidente', 'accident', 'nasugatan', 'injured', 'collapse',
    'nahulog', 'electrocut', 'live wire', 'nakuryente', 'hostage', 'explosion',
    'sumabog', 'outbreak', 'dengue', 'nalunod', 'drowning', 'landslide',
  ];
  static const _high = [
    'delikado', 'dangerous', 'unsafe', 'danger', 'peligro', 'severe', 'grabe',
    'nag-agas', 'leaking', 'sira', 'guba', 'broken', 'nahugno', 'walay tubig',
    'no water', 'blackout', 'walay suga', 'holdap', 'robbery', 'nakawan', 'stolen',
    'violence', 'gibunalan', 'threat', 'gipanghadlok',
  ];
  static const _medium = [
    'week', 'semana', 'adlaw', 'days', 'buwan', 'month', 'damo', 'many', 'lubak',
    'pothole', 'baho', 'smell', 'garbage', 'basura', 'traffic', 'noise', 'ingay',
    'clogged', 'barado',
  ];
  static const _negative = [
    'reklamo', 'complain', 'kapoy', 'daot', 'bad', 'worst', 'terrible', 'kahadlok',
    'scared', 'angry', 'disappointed', 'wala', 'walay', 'problema', 'problem',
  ];
  static const _positive = ['salamat', 'thank', 'maayo', 'good', 'appreciate'];

  static List<String> _hits(String text, List<String> words) =>
      words.where((w) => RegExp('\\b${RegExp.escape(w)}').hasMatch(text)).toList();

  static Classification classify(int categoryId, String description) {
    final text = description.toLowerCase();
    final cat = categoryById(categoryId);
    var score = _base[categoryId] ?? 1;

    final crit = _hits(text, _critical);
    final high = _hits(text, _high);
    final med = _hits(text, _medium);
    final neg = _hits(text, _negative);
    final pos = _hits(text, _positive);

    if (crit.isNotEmpty) score += 5 + (crit.length - 1);
    score += (high.length * 2).clamp(0, 4).toInt();
    score += med.length.clamp(0, 2).toInt();

    final priority = score >= 8
        ? Priority.critical
        : score >= 5
            ? Priority.high
            : score >= 3
                ? Priority.medium
                : Priority.low;

    final negScore = crit.length + high.length + neg.length;
    final sentiment = negScore >= 1 && negScore >= pos.length
        ? 'negative'
        : pos.isNotEmpty
            ? 'positive'
            : 'neutral';

    final categoryOnly = description.trim().length < 20;
    final keywords = {...crit, ...high, ...med}.take(5).toList();
    final confidence = categoryOnly
        ? 0.55
        : (0.68 + 0.05 * (crit.length + high.length + med.length)).clamp(0.68, 0.95);

    return Classification(
      category: cat.name,
      sentiment: categoryOnly && negScore == 0 ? 'neutral' : sentiment,
      priority: priority,
      confidence: confidence.toDouble(),
      officeId: cat.officeId,
      keywords: keywords,
      categoryOnly: categoryOnly,
    );
  }
}
