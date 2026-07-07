import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/couriers.dart';
import '../../core/courier_registry.dart';
import '../../core/providers.dart';
import '../../core/strings_ko.dart';
import 'models/parcel.dart';

/// Manual parcel entry for deliveries that automatic capture misses.
class ManualInsertScreen extends ConsumerStatefulWidget {
  const ManualInsertScreen({super.key});

  @override
  ConsumerState<ManualInsertScreen> createState() => _ManualInsertScreenState();
}

class _ManualInsertScreenState extends ConsumerState<ManualInsertScreen> {
  final _formKey = GlobalKey<FormState>();
  final _trackingController = TextEditingController();
  final _productController = TextEditingController();
  final _mallController = TextEditingController();

  Courier? _courier;
  ParcelStatus _status = ParcelStatus.registered;
  DateTime? _expectedArrival;

  @override
  void dispose() {
    _trackingController.dispose();
    _productController.dispose();
    _mallController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expectedArrival ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 60)),
      locale: const Locale('ko'),
    );
    if (picked != null) setState(() => _expectedArrival = picked);
  }

  Future<void> _submit() async {
    final courier = _courier;
    if (courier == null || !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final parcel = Parcel(
      id: '',
      courierCode: courier.code,
      trackingNumber: _normalizedTrackingNumber(_trackingController.text),
      status: _status,
      productName: _productController.text.trim().isEmpty
          ? null
          : _productController.text.trim(),
      mallName: _mallController.text.trim().isEmpty
          ? null
          : _mallController.text.trim(),
      sourceChannels: const {SourceChannel.manual},
      expectedArrivalDate: _expectedArrival,
      deliveredAt: _status == ParcelStatus.delivered ? DateTime.now() : null,
      registeredAt: DateTime.now(),
    );
    await ref.read(parcelRepositoryProvider).upsert(parcel, eventNote: '수동 등록');

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(StringsKo.insertDone)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final couriersAsync = ref.watch(courierListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(StringsKo.manualInsertTitle)),
      body: couriersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (allCouriers) {
          // Coupang direct delivery has no real tracking number (it's a
          // synthesized notification key), so it's not manually enterable.
          final couriers = allCouriers.where((c) => !c.isDirect).toList();
          if (couriers.isEmpty) {
            return Center(
              child: Text(
                StringsKo.settingCourierEmpty,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          _courier ??= couriers.firstWhere(
            (c) => c.code == Couriers.cj.code,
            orElse: () => couriers.first,
          );
          if (!couriers.any((c) => c.code == _courier!.code)) {
            _courier = couriers.first;
          }
          return _buildForm(context, couriers);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, List<Courier> couriers) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom + 24;
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
              children: [
                DropdownButtonFormField<Courier>(
                  initialValue: _courier,
                  decoration: const InputDecoration(
                    labelText: StringsKo.courierLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in couriers)
                      DropdownMenuItem(value: c, child: Text(c.nameKo)),
                  ],
                  onChanged: (c) => setState(() => _courier = c!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _trackingController,
                  decoration: const InputDecoration(
                    labelText: StringsKo.trackingNumberLabel,
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateTrackingNumber,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _productController,
                  decoration: const InputDecoration(
                    labelText: StringsKo.productNameLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _mallController,
                  decoration: const InputDecoration(
                    labelText: StringsKo.mallNameLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ParcelStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: StringsKo.statusLabel,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in ParcelStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.labelKo)),
                  ],
                  onChanged: (s) => setState(() => _status = s!),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expectedArrival == null
                            ? StringsKo.expectedArrivalLabel
                            : DateFormat(
                                'yyyy년 M월 d일 (E)',
                                'ko',
                              ).format(_expectedArrival!),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickDate,
                      child: const Text(StringsKo.pickDate),
                    ),
                    if (_expectedArrival != null)
                      TextButton(
                        onPressed: () =>
                            setState(() => _expectedArrival = null),
                        child: const Text(StringsKo.clearDate),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  child: const Text(StringsKo.insertButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validateTrackingNumber(String? value) {
    final courier = _courier;
    final trackingNumber = _normalizedTrackingNumber(value);
    if (trackingNumber.isEmpty) return StringsKo.trackingNumberEmpty;
    if (courier != null &&
        !RegExp(courier.invoicePattern).hasMatch(trackingNumber)) {
      return StringsKo.trackingNumberInvalid;
    }
    return null;
  }

  String _normalizedTrackingNumber(String? value) =>
      value?.replaceAll(RegExp(r'[-\s]'), '').trim() ?? '';
}
