import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/utils/format.dart';
import '../../../domain/models/document.dart';
import '../../../domain/models/search_filter.dart';
import '../providers/search_providers.dart';
import '../../../app/bootstrap.dart';

class AdvancedSearchSheet extends ConsumerStatefulWidget {
  const AdvancedSearchSheet({super.key, required this.initial});
  final SearchFilter initial;
  @override
  ConsumerState<AdvancedSearchSheet> createState() =>
      _AdvancedSearchSheetState();
}

class _AdvancedSearchSheetState extends ConsumerState<AdvancedSearchSheet> {
  final form = GlobalKey<FormState>();
  late FileKind? kind = widget.initial.kind;
  late String? owner = widget.initial.belongsTo;
  late bool? renewal = widget.initial.renewal, shared = widget.initial.shared;
  late DocumentSort sort = widget.initial.sort;
  late DateTimeRange? upload = widget.initial.uploadFrom == null
      ? null
      : DateTimeRange(
          start: widget.initial.uploadFrom!,
          end: widget.initial.uploadTo!,
        );
  late DateTimeRange? expiry = widget.initial.expiryFrom == null
      ? null
      : DateTimeRange(
          start: widget.initial.expiryFrom!,
          end: widget.initial.expiryTo!,
        );
  late final min = TextEditingController(
    text: widget.initial.minBytes == null
        ? ''
        : '${widget.initial.minBytes! / 1000000}',
  );
  late final max = TextEditingController(
    text: widget.initial.maxBytes == null
        ? ''
        : '${widget.initial.maxBytes! / 1000000}',
  );
  late final tags = TextEditingController(text: widget.initial.tags.join(', '));
  @override
  void dispose() {
    min.dispose();
    max.dispose();
    tags.dispose();
    super.dispose();
  }

  Future<void> pickRange(bool isExpiry) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 30),
      lastDate: DateTime(now.year + 50),
      initialDateRange: isExpiry ? expiry : upload,
    );
    if (mounted && range != null) {
      setState(() {
        if (isExpiry) {
          expiry = range;
        } else {
          upload = range;
        }
      });
    }
  }

  String? sizeError(String? value) => value == null || value.isEmpty
      ? null
      : double.tryParse(value) == null ||
            !double.parse(value).isFinite ||
            double.parse(value) < 0
      ? 'Enter a positive size.'
      : null;
  void apply() {
    if (!form.currentState!.validate()) return;
    Navigator.pop(
      context,
      SearchFilter(
        kind: kind,
        belongsTo: owner,
        renewal: renewal,
        shared: shared,
        uploadFrom: upload?.start,
        uploadTo: upload?.end,
        expiryFrom: expiry?.start,
        expiryTo: expiry?.end,
        minBytes: min.text.isEmpty
            ? null
            : (double.parse(min.text) * 1000000).round(),
        maxBytes: max.text.isEmpty
            ? null
            : (double.parse(max.text) * 1000000).round(),
        tags: tags.text
            .split(',')
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty)
            .toList(),
        sort: sort,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: form,
    child: ListView(
      padding: Space.page,
      children: [
        AppText('A more precise search.', style: context.type.displaySmall),
        const SizedBox(height: Space.lg),
        DropdownButtonFormField<FileKind>(
          initialValue: kind,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('File type')),
          items: [
            const DropdownMenuItem(value: null, child: AppText('Any type')),
            ...FileKind.values.map(
              (k) =>
                  DropdownMenuItem(value: k, child: Text(k.name.toUpperCase())),
            ),
          ],
          onChanged: (v) => setState(() => kind = v),
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<String>(
          initialValue: owner,
          isExpanded: true,
          decoration: InputDecoration(labelText: context.tr('Belongs to')),
          items: [
            const DropdownMenuItem(value: null, child: AppText('Anyone')),
            ...ref
                .watch(ownerSuggestionsProvider)
                .map((s) => DropdownMenuItem(value: s, child: Text(s))),
          ],
          onChanged: (v) => setState(() => owner = v),
        ),
        const SizedBox(height: Space.md),
        _RangeButton(
          label: 'Upload date range',
          range: upload,
          onTap: () => pickRange(false),
          onClear: () => setState(() => upload = null),
        ),
        const SizedBox(height: Space.sm),
        _RangeButton(
          label: 'Expiry date range',
          range: expiry,
          onTap: () => pickRange(true),
          onClear: () => setState(() => expiry = null),
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<bool>(
          initialValue: renewal,
          decoration: InputDecoration(
            labelText: context.tr('Renewal required'),
          ),
          items: const [
            DropdownMenuItem(value: null, child: AppText('Either')),
            DropdownMenuItem(value: true, child: AppText('Yes')),
            DropdownMenuItem(value: false, child: AppText('No')),
          ],
          onChanged: (v) => setState(() => renewal = v),
        ),
        const SizedBox(height: Space.md),
        if (!ref.watch(liveModeProvider))
          DropdownButtonFormField<bool>(
            initialValue: shared,
            decoration: InputDecoration(labelText: context.tr('Sharing')),
            items: const [
              DropdownMenuItem(value: null, child: AppText('Either')),
              DropdownMenuItem(value: true, child: AppText('Shared')),
              DropdownMenuItem(value: false, child: AppText('Not shared')),
            ],
            onChanged: (v) => setState(() => shared = v),
          ),
        const SizedBox(height: Space.md),
        AppTextField(
          label: 'Minimum size (MB)',
          controller: min,
          keyboardType: TextInputType.number,
          validator: sizeError,
        ),
        const SizedBox(height: Space.md),
        AppTextField(
          label: 'Maximum size (MB)',
          controller: max,
          keyboardType: TextInputType.number,
          validator: (v) {
            final base = sizeError(v);
            if (base != null) return base;
            if (v != null &&
                v.isNotEmpty &&
                min.text.isNotEmpty &&
                double.tryParse(min.text) != null &&
                double.parse(v) < double.parse(min.text)) {
              return 'Maximum must be at least the minimum.';
            }
            return null;
          },
        ),
        const SizedBox(height: Space.md),
        AppTextField(
          label: 'Tags, separated by commas',
          hint: 'personal, renewal',
          controller: tags,
        ),
        const SizedBox(height: Space.md),
        DropdownButtonFormField<DocumentSort>(
          initialValue: sort,
          decoration: InputDecoration(labelText: context.tr('Sort results')),
          items: DocumentSort.values
              .map(
                (s) =>
                    DropdownMenuItem(value: s, child: AppText('By ${s.name}')),
              )
              .toList(),
          onChanged: (v) => setState(() => sort = v!),
        ),
        const SizedBox(height: Space.lg),
        AppButton(label: 'Apply filters', onPressed: apply),
        const SizedBox(height: Space.sm),
        AppTextButton(
          onPressed: () => Navigator.pop(context, const SearchFilter()),
          child: const AppText('Reset all filters'),
        ),
      ],
    ),
  );
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.range,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final DateTimeRange? range;
  final VoidCallback onTap, onClear;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppButton(
        label: label,
        icon: AppIcons.calendar,
        secondary: true,
        onPressed: onTap,
      ),
      if (range != null)
        AppChip(
          label: '${dateLabel(range!.start)} – ${dateLabel(range!.end)}',
          onDeleted: onClear,
        ),
    ],
  );
}
