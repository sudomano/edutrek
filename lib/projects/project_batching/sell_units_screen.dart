import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';

class CreateOrEditSellUnitScreen extends StatefulWidget {
  final ProductBatch batch;
  final BatchSellUnit? sellUnit;

  const CreateOrEditSellUnitScreen(
      {super.key, required this.batch, this.sellUnit});

  @override
  State<CreateOrEditSellUnitScreen> createState() =>
      _CreateOrEditSellUnitScreenState();
}

class _CreateOrEditSellUnitScreenState
    extends State<CreateOrEditSellUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _multiplierController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.sellUnit != null) {
      _nameController.text = widget.sellUnit!.unitName;
      _multiplierController.text =
          widget.sellUnit!.quantityMultiplier.toString();
      _priceController.text = widget.sellUnit!.sellingPrice.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.sellUnit == null ? 'Add Selling Unit' : 'Edit Selling Unit'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Unit Name'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter a unit name' : null,
              ),
              TextFormField(
                controller: _multiplierController,
                decoration:
                    const InputDecoration(labelText: 'Quantity Multiplier'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'Enter valid number'
                    : null,
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Selling Price'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'Enter valid price'
                    : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                child: const Text('Save Selling Unit'),
                onPressed: _saveSellUnit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveSellUnit() async {
    if (!_formKey.currentState!.validate()) return;

    final sellBox = await Hive.openBox<BatchSellUnit>('batch_sell_units');

    final unit = widget.sellUnit ??
        BatchSellUnit(
          sellUnitCode: DateTime.now().millisecondsSinceEpoch.toString(),
          batchCode: widget.batch.batchCode ?? '',
          unitName: _nameController.text,
          quantityMultiplier: int.parse(_multiplierController.text),
          sellingPrice: double.parse(_priceController.text),
          active: true,
        );

    unit
      ..unitName = _nameController.text
      ..quantityMultiplier = int.parse(_multiplierController.text)
      ..sellingPrice = double.parse(_priceController.text)
      ..active = true
      ..lastModified = DateTime.now()
      ..operationType = 'create';

    await sellBox.put(unit.sellUnitCode, unit);

    Navigator.pop(context);
  }
}
