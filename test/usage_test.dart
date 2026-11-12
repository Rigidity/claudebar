import 'package:claudebar/usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 1, 8);
  const week = Duration(days: 7);

  LimitWindow window(double used, DateTime resetsAt) => LimitWindow(
      id: 'weekly', title: 'Weekly', usedPercent: used, resetsAt: resetsAt, duration: week);

  test('under pace is reserve', () {
    // 40% of the week elapsed, 30% used.
    final w = window(30, now.add(week * 0.6));
    expect(w.expectedPercent(now), closeTo(40, 0.01));
    expect(w.paceDelta(now), closeTo(10, 0.01));
  });

  test('over pace is deficit', () {
    expect(window(50, now.add(week * 0.6)).paceDelta(now), closeTo(-10, 0.01));
  });

  test('expected percent is clamped to the window', () {
    expect(window(0, now.subtract(const Duration(days: 1))).expectedPercent(now), 100);
    expect(window(0, now.add(week * 2)).expectedPercent(now), 0);
  });

  test('parses windows, microsecond timestamps and the Fable limit', () {
    final snapshot = UsageSnapshot.fromJson({
      'five_hour': {'utilization': 12.0, 'resets_at': '2026-01-08T03:00:00.123456+00:00'},
      'seven_day': null,
      'limits': [
        {'kind': 'weekly_all', 'group': 'weekly', 'percent': 41, 'resets_at': '2026-01-12T00:00:00Z'},
        {
          'group': 'weekly',
          'percent': 7.5,
          'resets_at': '2026-01-12T00:00:00Z',
          'scope': {'model': {'display_name': 'Fable 5.1'}},
        },
      ],
    });
    expect(snapshot.session?.usedPercent, 12);
    expect(snapshot.session?.resetsAt, DateTime.utc(2026, 1, 8, 3));
    expect(snapshot.weekly?.usedPercent, 41);
    expect(snapshot.fableWeekly?.usedPercent, 7.5);
  });

  test('missing data yields null windows', () {
    final snapshot = UsageSnapshot.fromJson({});
    expect(snapshot.session, isNull);
    expect(snapshot.weekly, isNull);
    expect(snapshot.fableWeekly, isNull);
  });
}
