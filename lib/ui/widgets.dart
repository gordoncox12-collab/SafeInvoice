import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/money.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.currency = 'ZAR', this.style});

  final double amount;
  final String currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(Za.money(amount, currency), style: style);
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      InvoiceStatus.draft => ('Draft', Colors.blueGrey),
      InvoiceStatus.sent => ('Sent', Colors.blue),
      InvoiceStatus.paid => ('Paid', Colors.green),
      InvoiceStatus.overdue => ('Overdue', Colors.red),
      InvoiceStatus.cancelled => ('Cancelled', Colors.grey),
    };
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.shade400),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color.shade800, fontWeight: FontWeight.w600),
    );
  }
}

class EmptyHint extends StatelessWidget {
  const EmptyHint({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class SearchableSelect<T> extends StatelessWidget {
  const SearchableSelect({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.subtitleOf,
    this.searchHint = 'Search',
    this.includeNone = false,
    this.noneLabel = '(none)',
    this.placeholder,
    this.enabled = true,
  });

  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final ValueChanged<T?> onChanged;
  final String searchHint;
  final bool includeNone;
  final String noneLabel;
  final String? placeholder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = value == null
        ? (includeNone ? noneLabel : (placeholder ?? 'Select ${label.toLowerCase()}'))
        : labelOf(value as T);
    final selectedSub = value == null || subtitleOf == null ? null : subtitleOf!(value as T);
    return InkWell(
      onTap: enabled ? () => _open(context) : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: enabled,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (selectedSub != null && selectedSub.isNotEmpty)
              Text(
                selectedSub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final result = await showModalBottomSheet<_SelectResult<T>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _SearchSheet<T>(
        title: label,
        items: items,
        labelOf: labelOf,
        subtitleOf: subtitleOf,
        searchHint: searchHint,
        includeNone: includeNone,
        noneLabel: noneLabel,
        selected: value,
      ),
    );
    if (result != null) onChanged(result.value);
  }
}

class _SelectResult<T> {
  const _SelectResult(this.value);
  final T? value;
}

class _SearchSheet<T> extends StatefulWidget {
  const _SearchSheet({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.subtitleOf,
    required this.searchHint,
    required this.includeNone,
    required this.noneLabel,
    required this.selected,
  });

  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final String Function(T)? subtitleOf;
  final String searchHint;
  final bool includeNone;
  final String noneLabel;
  final T? selected;

  @override
  State<_SearchSheet<T>> createState() => _SearchSheetState<T>();
}

class _SearchSheetState<T> extends State<_SearchSheet<T>> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final q = query.trim().toLowerCase();
    final filtered = widget.items.where((item) {
      if (q.isEmpty) return true;
      final label = widget.labelOf(item).toLowerCase();
      final sub = widget.subtitleOf?.call(item).toLowerCase() ?? '';
      return label.contains(q) || sub.contains(q);
    }).toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: widget.items.length > 6,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: widget.searchHint,
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (widget.includeNone)
                      ListTile(
                        title: Text(widget.noneLabel),
                        selected: widget.selected == null,
                        onTap: () => Navigator.pop(context, _SelectResult<T>(null)),
                      ),
                    if (filtered.isEmpty)
                      const ListTile(title: Text('No matches'))
                    else
                      for (final item in filtered)
                        ListTile(
                          title: Text(widget.labelOf(item)),
                          subtitle: widget.subtitleOf == null ? null : Text(widget.subtitleOf!(item)),
                          selected: widget.selected == item,
                          onTap: () => Navigator.pop(context, _SelectResult<T>(item)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: Theme.of(context).textTheme.titleMedium),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Reads bytes synchronously so logos/signatures render in widget tests and on-device.
class DiskImage extends StatelessWidget {
  const DiskImage(this.file, {super.key, this.height, this.fit = BoxFit.contain});

  final File file;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (!file.existsSync()) return const SizedBox.shrink();
    return Image.memory(file.readAsBytesSync(), height: height, fit: fit);
  }
}

Future<void> showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  return Future.value();
}

String niceEnum(Enum value) {
  final raw = value.name.replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m[0]}');
  final s = raw.trim();
  return s[0].toUpperCase() + s.substring(1);
}
