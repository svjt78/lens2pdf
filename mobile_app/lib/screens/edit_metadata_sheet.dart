import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/library_repository.dart';
import '../services/receipt_intel.dart';

class EditMetadataResult {
  const EditMetadataResult({required this.updated});

  final bool updated;
}

class EditMetadataSheet extends StatefulWidget {
  const EditMetadataSheet({
    super.key,
    required this.pdfPath,
    this.existingReceipt,
    this.existingMetadata,
  });

  final String pdfPath;
  final ReceiptIntelResult? existingReceipt;
  final Map<String, dynamic>? existingMetadata;

  static Future<EditMetadataResult?> show(
    BuildContext context, {
    required String pdfPath,
    ReceiptIntelResult? existingReceipt,
    Map<String, dynamic>? existingMetadata,
  }) {
    return showModalBottomSheet<EditMetadataResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => EditMetadataSheet(
        pdfPath: pdfPath,
        existingReceipt: existingReceipt,
        existingMetadata: existingMetadata,
      ),
    );
  }

  @override
  State<EditMetadataSheet> createState() => _EditMetadataSheetState();
}

class _EditMetadataSheetState extends State<EditMetadataSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vendorController;
  late final TextEditingController _totalController;
  late final TextEditingController _paymentController;
  late final TextEditingController _last4Controller;
  late final TextEditingController _tagsController;
  late final TextEditingController _notesController;
  late final TextEditingController _documentTypeController;
  DateTime? _purchaseDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final metadata = widget.existingMetadata;
    final receipt = widget.existingReceipt;

    _vendorController = TextEditingController(
      text: metadata?['vendor'] as String? ?? receipt?.vendor ?? '',
    );
    _totalController = TextEditingController(
      text: _formatTotal(
        metadata?['total'],
        receipt?.total?.value,
      ),
    );
    _paymentController = TextEditingController(
      text:
          metadata?['paymentMethod'] as String? ?? receipt?.paymentMethod ?? '',
    );
    _last4Controller = TextEditingController(
      text: metadata?['last4'] as String? ?? receipt?.last4 ?? '',
    );
    _notesController = TextEditingController(
      text: metadata?['notes'] as String? ?? '',
    );
    _documentTypeController = TextEditingController(
      text: metadata?['documentType'] as String? ?? '',
    );

    _tagsController = TextEditingController(
      text: _joinTags(metadata?['tags'], receipt?.tags),
    );

    _purchaseDate = _parseDate(
      metadata?['purchaseDate'] as String? ??
          receipt?.purchaseDate?.toIso8601String(),
      fallback: receipt?.purchaseDate,
    );
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _totalController.dispose();
    _paymentController.dispose();
    _last4Controller.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _documentTypeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit receipt metadata',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _vendorController,
                    decoration: const InputDecoration(
                      labelText: 'Vendor / Merchant',
                      hintText: 'Acme Hardware',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DatePickerField(
                    label: 'Purchase date',
                    selected: _purchaseDate,
                    onChanged: (value) => setState(() => _purchaseDate = value),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _totalController,
                    decoration: const InputDecoration(
                      labelText: 'Total amount',
                      hintText: '42.75',
                      prefixText: '\$',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return null;
                      final normalized = value.replaceAll(',', '.');
                      return double.tryParse(normalized) == null
                          ? 'Enter a valid number'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _paymentController,
                    decoration: const InputDecoration(
                      labelText: 'Payment method',
                      hintText: 'Visa',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _last4Controller,
                    decoration: const InputDecoration(
                      labelText: 'Card last 4',
                      hintText: '1234',
                    ),
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      labelText: 'Tags',
                      hintText: 'groceries, taxes, reimbursable',
                      helperText: 'Comma separated',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _documentTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Document type',
                      hintText: 'receipt, id, invoice',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'Additional context or reminders',
                    ),
                    minLines: 2,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context,
                                const EditMetadataResult(updated: false)),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final normalizedTags = _tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList();

      final totalText = _totalController.text.trim();
      final totalValue = totalText.isEmpty
          ? null
          : double.tryParse(totalText.replaceAll(',', '.'));

      final map = Map<String, dynamic>.from(widget.existingMetadata ?? {});
      void setOrRemove(String key, dynamic value) {
        if (value == null || (value is String && value.trim().isEmpty)) {
          map.remove(key);
        } else {
          map[key] = value;
        }
      }

      setOrRemove('vendor', _vendorController.text);
      setOrRemove('purchaseDate', _purchaseDate);
      setOrRemove('total', totalValue);
      setOrRemove('paymentMethod', _paymentController.text);
      setOrRemove('last4', _last4Controller.text);
      setOrRemove('notes', _notesController.text);
      setOrRemove('documentType', _documentTypeController.text);
      if (normalizedTags.isEmpty) {
        map.remove('tags');
      } else {
        map['tags'] = normalizedTags;
      }

      await LibraryRepository.instance.saveMetadataMap(widget.pdfPath, map);
      if (!mounted) return;
      Navigator.pop(context, const EditMetadataResult(updated: true));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  static String _joinTags(dynamic metadataTags, List<String>? receiptTags) {
    final tags = <String>{};
    void addTag(String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        tags.add(trimmed);
      }
    }

    if (metadataTags is List) {
      for (final value in metadataTags) {
        if (value is String) addTag(value);
      }
    } else if (metadataTags is String) {
      for (final value in metadataTags.split(',')) {
        addTag(value);
      }
    }

    if (receiptTags != null) {
      for (final value in receiptTags) {
        addTag(value);
      }
    }

    return tags.join(', ');
  }

  static String _formatTotal(dynamic metadataTotal, double? receiptTotal) {
    if (metadataTotal is num) {
      return metadataTotal.toStringAsFixed(2);
    }
    if (receiptTotal != null) {
      return receiptTotal.toStringAsFixed(2);
    }
    return '';
  }

  static DateTime? _parseDate(String? value, {DateTime? fallback}) {
    if (value == null || value.isEmpty) return fallback;
    return DateTime.tryParse(value) ?? fallback;
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final DateTime? selected;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = selected == null
        ? 'Select date'
        : DateFormat.yMMMMd().format(selected!.toLocal());
    return OutlinedButton.icon(
      icon: const Icon(Icons.event_outlined),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: selected == null ? theme.hintColor : null,
      ),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: selected ?? now,
          firstDate: DateTime(now.year - 10),
          lastDate: DateTime(now.year + 10),
        );
        onChanged(picked);
      },
    );
  }
}
