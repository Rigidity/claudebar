import 'package:flutter/material.dart';

import 'usage.dart';
import 'usage_store.dart';

const panelWidth = 332.0;

/// Text shown in the menu bar next to the icon.
String menuBarTitle(UsageSnapshot? snapshot, {required bool hasError}) {
  if (hasError) return ' ⚠︎';
  if (snapshot == null) return '';
  final parts = [snapshot.session, snapshot.weekly]
      .whereType<LimitWindow>()
      .map((w) => '${w.id == 'session' ? 'S' : 'W'} ${w.usedPercent.round()}%');
  return ' ${parts.isEmpty ? '—' : parts.join(' · ')}';
}

class UsagePanel extends StatelessWidget {
  const UsagePanel({super.key, required this.store, required this.onQuit});

  final UsageStore store;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snapshot = store.snapshot;
    final error = store.error;

    return SizedBox(
      width: panelWidth,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Claude Usage', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (error != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(child: Text(error, style: const TextStyle(color: Colors.orange))),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (snapshot != null) ...[
              WindowRow(title: 'Session', window: snapshot.session, emptyText: 'No active session'),
              const SizedBox(height: 14),
              WindowRow(title: 'Weekly', window: snapshot.weekly, emptyText: 'Unavailable'),
              const SizedBox(height: 14),
              WindowRow(
                  title: 'Fable weekly', window: snapshot.fableWeekly, emptyText: 'No Fable limit on this plan'),
              const SizedBox(height: 14),
            ] else if (error == null) ...[
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              const SizedBox(height: 14),
            ],
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (store.lastUpdated case final updated?)
                  Text('Updated ${TimeOfDay.fromDateTime(updated).format(context)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
                const Spacer(),
                IconButton(
                  onPressed: store.isLoading ? null : store.refresh,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
                TextButton(
                  onPressed: onQuit,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: const Text('Quit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WindowRow extends StatelessWidget {
  const WindowRow({super.key, required this.title, required this.window, required this.emptyText});

  final String title;
  final LimitWindow? window;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall!;
    final window = this.window;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const Spacer(),
            if (window != null)
              Text('${window.usedPercent.round()}% used',
                  style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
        const SizedBox(height: 5),
        if (window != null) ...[
          PaceBar(used: window.usedPercent, expected: window.expectedPercent()),
          const SizedBox(height: 5),
          Row(
            children: [
              PaceText(delta: window.paceDelta()),
              const Spacer(),
              if (window.resetsAt case final resetsAt?)
                Text('Resets ${_relative(resetsAt)}', style: caption.copyWith(color: theme.hintColor)),
            ],
          ),
        ] else
          Text(emptyText, style: caption.copyWith(color: theme.hintColor)),
      ],
    );
  }

  static String _relative(DateTime date) {
    final d = date.difference(DateTime.now());
    if (d.isNegative) return 'now';
    if (d.inDays >= 1) return 'in ${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours >= 1) return 'in ${d.inHours}h ${d.inMinutes % 60}m';
    return 'in ${d.inMinutes < 1 ? 1 : d.inMinutes}m';
  }
}

/// Usage bar with a tick marking where usage would be at an even pace.
class PaceBar extends StatelessWidget {
  const PaceBar({super.key, required this.used, required this.expected});

  final double used;
  final double? expected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = used >= 90
        ? Colors.red
        : (expected != null && used > expected!)
            ? Colors.orange
            : theme.colorScheme.primary;

    return SizedBox(
      height: 12,
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              height: 8,
              width: width * used.clamp(0, 100) / 100,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
            ),
            if (expected != null)
              Positioned(
                left: width * expected! / 100 - 1,
                child: Container(width: 2, height: 12, color: theme.colorScheme.onSurface),
              ),
          ],
        );
      }),
    );
  }
}

class PaceText extends StatelessWidget {
  const PaceText({super.key, required this.delta});

  final double? delta;

  @override
  Widget build(BuildContext context) {
    final delta = this.delta;
    if (delta == null) return const SizedBox.shrink();

    final style = Theme.of(context).textTheme.bodySmall!;
    final amount = delta.abs().round();
    if (amount == 0) return Text('On pace', style: style.copyWith(color: Theme.of(context).hintColor));
    if (delta > 0) return Text('$amount% in reserve', style: style.copyWith(color: Colors.green));
    return Text('$amount% in deficit', style: style.copyWith(color: Colors.red));
  }
}
