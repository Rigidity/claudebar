/// One rate-limit window, with pace computed against a linear burn rate.
class LimitWindow {
  const LimitWindow({
    required this.id,
    required this.title,
    required this.usedPercent,
    required this.resetsAt,
    required this.duration,
  });

  final String id;
  final String title;
  final double usedPercent;
  final DateTime? resetsAt;
  final Duration duration;

  /// How much of the window should be used by now if usage were spread evenly.
  double? expectedPercent([DateTime? now]) {
    final resetsAt = this.resetsAt;
    if (resetsAt == null) return null;
    final remaining = resetsAt.difference(now ?? DateTime.now());
    final elapsed = duration - remaining;
    return (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0) * 100;
  }

  /// Positive = reserve (under pace), negative = deficit (over pace).
  double? paceDelta([DateTime? now]) {
    final expected = expectedPercent(now);
    return expected == null ? null : expected - usedPercent;
  }
}

class UsageSnapshot {
  UsageSnapshot._({this.session, this.weekly, this.fableWeekly});

  /// null when there's no active 5-hour session.
  final LimitWindow? session;
  final LimitWindow? weekly;

  /// null when the account has no Fable-scoped weekly limit.
  final LimitWindow? fableWeekly;

  static const _fiveHours = Duration(hours: 5);
  static const _sevenDays = Duration(days: 7);

  /// Builds a snapshot from the decoded `GET /api/oauth/usage` JSON.
  factory UsageSnapshot.fromJson(Map<String, dynamic> json) {
    final limits = [
      for (final l in (json['limits'] as List?) ?? const [])
        if (l is Map<String, dynamic>) l,
    ];
    Map<String, dynamic>? limit(bool Function(Map<String, dynamic>) test) {
      for (final l in limits) {
        if (test(l)) return l;
      }
      return null;
    }

    final fiveHour = json['five_hour'] as Map<String, dynamic>?;
    final sevenDay = json['seven_day'] as Map<String, dynamic>?;

    final sessionLimit = limit((l) =>
        l['group'] == 'session' || ((l['kind'] as String?)?.contains('five_hour') ?? false));
    final weeklyLimit = limit((l) => l['kind'] == 'weekly_all');
    final fableLimit = limit((l) {
      final model = ((l['scope'] as Map?)?['model'] as Map?)?['display_name'] as String?;
      return l['group'] == 'weekly' && (model?.toLowerCase().contains('fable') ?? false);
    });

    return UsageSnapshot._(
      session: _window('session', 'Session', _fiveHours,
          percent: fiveHour?['utilization'] ?? sessionLimit?['percent'],
          resetsAt: fiveHour?['resets_at'] ?? sessionLimit?['resets_at']),
      weekly: _window('weekly', 'Weekly', _sevenDays,
          percent: sevenDay?['utilization'] ?? weeklyLimit?['percent'],
          resetsAt: sevenDay?['resets_at'] ?? weeklyLimit?['resets_at']),
      fableWeekly: _window('fable', 'Fable weekly', _sevenDays,
          percent: fableLimit?['percent'], resetsAt: fableLimit?['resets_at']),
    );
  }

  static LimitWindow? _window(String id, String title, Duration duration,
      {required Object? percent, required Object? resetsAt}) {
    if (percent is! num) return null;
    return LimitWindow(
      id: id,
      title: title,
      usedPercent: percent.toDouble(),
      resetsAt: resetsAt is String ? _parseDate(resetsAt) : null,
      duration: duration,
    );
  }

  /// The API returns microsecond timestamps; drop the fraction so any ISO 8601 offset parses.
  static DateTime? _parseDate(String s) => DateTime.tryParse(s.replaceFirst(RegExp(r'\.\d+'), ''));
}
