import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';

class CreateOrEditSellUnitScreen extends StatefulWidget {
  final ProductBatch batch;
  final BatchSellUnit? sellUnit;

  const CreateOrEditSellUnitScreen({
    super.key,
    required this.batch,
    this.sellUnit,
  });

  @override
  State<CreateOrEditSellUnitScreen> createState() =>
      _CreateOrEditSellUnitScreenState();
}

class _CreateOrEditSellUnitScreenState
    extends State<CreateOrEditSellUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final unitNameCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  late final bool isEdit;

  @override
  void initState() {
    super.initState();
    isEdit = widget.sellUnit != null;

    if (isEdit) {
      final su = widget.sellUnit!;
      unitNameCtrl.text = su.unitName;
      quantityCtrl.text = su.quantityMultiplier.toString();
      priceCtrl.text = su.sellingPrice.toStringAsFixed(2);
    }
  }

  int? _parseQuantity(String v) {
    final q = int.tryParse(v);
    if (q == null || q <= 0) return null;
    return q;
  }

  double? _parsePrice(String v) {
    final p = double.tryParse(v);
    if (p == null || p <= 0) return null;
    return p;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final quantity = _parseQuantity(quantityCtrl.text.trim())!;
    final price = _parsePrice(priceCtrl.text.trim())!;
    final unitName = unitNameCtrl.text.trim();

    final box = Hive.box<BatchSellUnit>('batch_sell_units');

    if (isEdit) {
      widget.sellUnit!
        ..unitName = unitName
        ..quantityMultiplier = quantity
        ..sellingPrice = price
        ..operationType = 'update'
        ..lastModified = DateTime.now();

      await widget.sellUnit!.save();
    } else {
      await box.add(
        BatchSellUnit(
          sellUnitCode: _uuid.v4(),
          batchCode: widget.batch.batchCode ?? '',
          unitName: unitName,
          quantityMultiplier: quantity,
          sellingPrice: price,
          active: true,
          operationType: 'create',
          lastModified: DateTime.now(),
        ),
      );
    }

    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final su = widget.sellUnit;
    if (su == null) return;

    su
      ..active = false
      ..operationType = 'delete'
      ..lastModified = DateTime.now();

    await su.save();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Sell Unit' : 'Create Sell Unit'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text(
                'Batch Ref: ${widget.batch.reference}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // ---------- UNIT NAME ----------
              TextFormField(
                controller: unitNameCtrl,
                decoration: const InputDecoration(labelText: 'Unit Name'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Unit name is required'
                    : null,
              ),

              // ---------- QUANTITY MULTIPLIER ----------
              TextFormField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity Multiplier',
                  hintText: 'Must be greater than 0',
                ),
                validator: (v) => _parseQuantity(v?.trim() ?? '') == null
                    ? 'Enter a valid quantity greater than 0'
                    : null,
              ),

              // ---------- SELLING PRICE ----------
              TextFormField(
                controller: priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Selling Price',
                  hintText: 'Must be greater than 0',
                ),
                validator: (v) => _parsePrice(v?.trim() ?? '') == null
                    ? 'Enter a valid price greater than 0'
                    : null,
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEdit ? 'Update' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
