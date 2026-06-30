import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/unitbatching.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';
import 'package:zitf_system/database/projects/packaging_level.dart';

class CreateProductBatchScreen extends StatefulWidget {
  final ProjectItem projectItem;
  final ProductBatch? batch; // 👈 null = create, not null = edit

  const CreateProductBatchScreen({
    super.key,
    required this.projectItem,
    this.batch,
  });

  bool get isEdit => batch != null;

  @override
  State<CreateProductBatchScreen> createState() =>
      _CreateProductBatchScreenState();
}

class _CreateProductBatchScreenState extends State<CreateProductBatchScreen> {
  final _formKey = GlobalKey<FormState>();

  final referenceCtrl = TextEditingController();
  final baseUnitSizeCtrl = TextEditingController();

  DateTime purchaseDate = DateTime.now();
  StockUnitType selectedBaseUnitType = StockUnitType.piece;
  String selectedBaseUnit = 'pcs';
  String? pieceQuantifier;

  double baseUnitSize = 1;

  final List<_PackagingUnit> packagingUnits = [];

  Map<StockUnitType, List<String>> baseUnitsByType = {
    StockUnitType.piece: ['pcs'],
    StockUnitType.weight: ['kg', 'g', 'mg', 'tonne'],
    StockUnitType.volume: ['L', 'ml'],
  };

  List<String> pieceQuantifiers = [
    'standard',
    '2cm',
    '5mm',
    'size S',
    'size M',
    'size L',
    'size XL',
    'size XXL',
    '32',
    '60',
  ];
  void _recalculateSummary() {
    setState(() {});
  }

  PackagingLevel _mapLevel(String level) {
    switch (level) {
      case 'single':
        return PackagingLevel.single;
      case 'pack':
        return PackagingLevel.pack;
      case 'carton':
        return PackagingLevel.carton;
      case 'batch':
        return PackagingLevel.batch; // or drum if you prefer
      default:
        return PackagingLevel.single;
    }
  }

  bool get _baseUnitLocked =>
      widget.isEdit &&
      (widget.batch!.remainingBaseUnits! < widget.batch!.totalBaseUnits!);

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      final b = widget.batch!;

      referenceCtrl.text = b.reference!;
      purchaseDate = b.purchaseDate!;
      selectedBaseUnitType = b.baseUnitType!;
      selectedBaseUnit = b.baseUnit!;
      baseUnitSize = b.baseUnitSize!;
      baseUnitSizeCtrl.text = baseUnitSize.toString();

      packagingUnits.clear();

      for (final u in b.units ?? const <BatchUnit>[]) {
        packagingUnits.add(
          _PackagingUnit(_recalculateSummary)
            ..level = u.level.name
            ..unitsPerPackageCtrl.text = u.unitsPerPackage.toString()
            ..packageCountCtrl.text = u.quantity.toString()
            ..buyingPriceCtrl.text = u.buyingPrice.toString(),
        );
      }
    } else {
      packagingUnits.add(_PackagingUnit(_recalculateSummary));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
            child: Text(
                widget.isEdit ? 'Edit Product Batch' : 'Create Product Batch')),
        centerTitle: true,
        actions: [
          if (widget.isEdit)
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'Linked to existing batch',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Editing linked batch')),
                );
              },
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 720),
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                _productHeader(),
                const SizedBox(height: 20),
                _batchMetaCard(),
                const SizedBox(height: 16),
                _baseUnitCard(),
                const SizedBox(height: 16),
                _packagingUnitsCard(),
                const SizedBox(height: 16),
                _summaryCard(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recalculate Summary'),
                  onPressed: () => setState(() {}),
                ),
                const SizedBox(height: 24),
                _saveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _productHeader() {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (widget.isEdit)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'EDIT MODE',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            Text(
              widget.projectItem.name!.toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'GOODS ITEM',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _batchMetaCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Batch Information',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: referenceCtrl,
              decoration: const InputDecoration(
                labelText: 'Supplier Reference / Invoice No',
              ),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Purchase Date'),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    '${purchaseDate.year}-${purchaseDate.month}-${purchaseDate.day}',
                  ),
                  onPressed: _pickDate,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _baseUnitCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Base Unit Definition',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: baseUnitSizeCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Base Unit Size',
                helperText: selectedBaseUnitType == StockUnitType.volume
                    ? 'e.g. 2 for 2 Litres'
                    : selectedBaseUnitType == StockUnitType.weight
                        ? 'e.g. 5 for 5 Kg'
                        : 'e.g. 30 for 30 Pieces',
                suffixText: selectedBaseUnit,
              ),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null || val <= 0) return 'Invalid value';
                return null;
              },
              onChanged: (v) {
                setState(() {
                  baseUnitSize = double.tryParse(v) ?? 1;
                });
              },
            ),
            const SizedBox(height: 12),

            /// Base unit TYPE
            DropdownButtonFormField<StockUnitType>(
              value: selectedBaseUnitType,
              decoration: const InputDecoration(labelText: 'Unit Type'),
              items: StockUnitType.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(t.name.toUpperCase()),
                );
              }).toList(),
              onChanged: _baseUnitLocked
                  ? null
                  : (v) {
                      setState(() {
                        selectedBaseUnitType = v!;
                        selectedBaseUnit = baseUnitsByType[v]!
                            .first; // auto-pick sensible default
                      });
                    },
            ),

            const SizedBox(height: 12),

            /// Base unit
            DropdownButtonFormField<String>(
              value: selectedBaseUnit,
              decoration: const InputDecoration(labelText: 'Base Unit'),
              items: baseUnitsByType[selectedBaseUnitType]!
                  .map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => selectedBaseUnit = v!),
            ),

            /// Optional piece quantifier
            if (selectedBaseUnitType == StockUnitType.piece) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: pieceQuantifier,
                decoration:
                    const InputDecoration(labelText: 'Piece Definition'),
                items: pieceQuantifiers
                    .map((q) => DropdownMenuItem(
                          value: q,
                          child: Text(q),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => pieceQuantifier = v),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _packagingUnitsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Packaging Units',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...List.generate(packagingUnits.length, (index) {
              return _packagingUnitTile(index);
            }),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Packaging Level'),
              onPressed: () {
                setState(() {
                  packagingUnits.add(_PackagingUnit(_recalculateSummary));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _packagingUnitTile(int index) {
    final unit = packagingUnits[index];

    return Card(
      color: Colors.grey.shade50,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Text('Level ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                if (packagingUnits.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() => packagingUnits.removeAt(index));
                    },
                  ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: unit.level,
              decoration: const InputDecoration(labelText: 'Packaging Type'),
              items: const [
                DropdownMenuItem(value: 'single', child: Text('Single')),
                DropdownMenuItem(value: 'pack', child: Text('Pack')),
                DropdownMenuItem(value: 'carton', child: Text('Carton')),
                DropdownMenuItem(value: 'batch', child: Text('Batch')),
              ],
              onChanged: (v) {
                final exists = packagingUnits.any(
                  (e) => e != unit && e.level == v,
                );

                if (exists) {
                  _showError('Packaging level already exists');
                  return;
                }

                setState(() => unit.level = v!);
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: unit.unitsPerPackageCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: 'Units per ${unit.level}'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: unit.packageCountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Number of Packages',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: unit.buyingPriceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Buying Price'),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _summaryCard() {
    double totalUnits = 0;
    double totalCost = 0;

    for (final u in packagingUnits) {
      final unitsPerPkg = double.tryParse(u.unitsPerPackageCtrl.text) ?? 0;
      final qty = int.tryParse(u.packageCountCtrl.text) ?? 0;
      final price = double.tryParse(u.buyingPriceCtrl.text) ?? 0;

      totalUnits += unitsPerPkg * qty;
      totalCost += price * qty;
    }

    final costPerUnit = totalUnits == 0 ? 0 : (totalCost / totalUnits);

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Batch Summary',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Total Quantity: $totalUnits $selectedBaseUnit'),
            Text('Total Buying Cost: ${totalCost.toStringAsFixed(2)}'),
            Text(
              'Cost per Unit: ${costPerUnit.toStringAsFixed(4)} / $selectedBaseUnit',
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saveBatch,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontSize: 16),
        ),
        child: const Text('SAVE BATCH'),
      ),
    );
  }

  // ------------------------------------------------------------
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => purchaseDate = picked);
    }
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    if (packagingUnits.isEmpty) {
      _showError('Add at least one packaging unit');
      return;
    }

    final List<BatchUnit> units = [];
    double totalBaseUnits = 0;
    double totalBuyingCost = 0;

    // ✅ Track which fields are being modified
    List<String> modifiedFields = [];

    for (final u in packagingUnits) {
      final unitsPerPkg = double.tryParse(u.unitsPerPackageCtrl.text);
      final qty = int.tryParse(u.packageCountCtrl.text);
      final price = double.tryParse(u.buyingPriceCtrl.text);

      if (unitsPerPkg == null || unitsPerPkg <= 0) {
        _showError('Invalid units per package');
        return;
      }

      if (qty == null || qty <= 0) {
        _showError('Invalid package quantity');
        return;
      }

      if (price == null || price < 0) {
        _showError('Invalid buying price');
        return;
      }

      // ✅ Create BatchUnit with sync fields set
      final batchUnit = BatchUnit(
        level: _mapLevel(u.level),
        unitsPerPackage: unitsPerPkg,
        quantity: qty,
        buyingPrice: price,
        // ✅ Set sync fields for child objects
        syncStatus: false,
        lastModified: DateTime.now(),
        operationType: 'create',
        modifiedFields: ['level', 'unitsPerPackage', 'quantity', 'buyingPrice'],
      );

      units.add(batchUnit);

      totalBaseUnits += batchUnit.totalUnits;
      totalBuyingCost += batchUnit.totalCost;
    }

    /// Normalize by base unit size
    final normalizedBaseUnits = totalBaseUnits;

    // ✅ Track modified fields
    modifiedFields.add('reference');
    modifiedFields.add('units');
    modifiedFields.add('baseUnit');
    modifiedFields.add('baseUnitSize');
    modifiedFields.add('totalBaseUnits');
    modifiedFields.add('totalBuyingCost');
    modifiedFields.add('purchaseDate');

    final box = Hive.box<ProductBatch>('product_batches');

    if (widget.isEdit) {
      final existing = widget.batch!;

      // ✅ Track changed fields for edit
      List<String> editModifiedFields = [];

      if (existing.reference != referenceCtrl.text.trim()) {
        editModifiedFields.add('reference');
      }
      if (existing.baseUnitType != selectedBaseUnitType) {
        editModifiedFields.add('baseUnitType');
      }
      if (existing.baseUnit != selectedBaseUnit) {
        editModifiedFields.add('baseUnit');
      }
      if (existing.baseUnitSize != baseUnitSize) {
        editModifiedFields.add('baseUnitSize');
      }
      if (existing.purchaseDate != purchaseDate) {
        editModifiedFields.add('purchaseDate');
      }
      if (existing.totalBaseUnits != normalizedBaseUnits) {
        editModifiedFields.add('totalBaseUnits');
      }
      if (existing.totalBuyingCost != totalBuyingCost) {
        editModifiedFields.add('totalBuyingCost');
      }

      // ✅ Check if units have changed
      if (existing.units!.length != units.length) {
        editModifiedFields.add('units');
      } else {
        for (int i = 0; i < units.length; i++) {
          if (existing.units![i].unitsPerPackage != units[i].unitsPerPackage ||
              existing.units![i].quantity != units[i].quantity ||
              existing.units![i].buyingPrice != units[i].buyingPrice) {
            editModifiedFields.add('units');
            break;
          }
        }
      }

      // ✅ If no fields changed, show message and return
      if (editModifiedFields.isEmpty) {
        _showError('No changes detected');
        return;
      }

      // ✅ Update existing ProductBatch with sync fields
      existing
        ..reference = referenceCtrl.text.trim()
        ..baseUnitType = selectedBaseUnitType
        ..baseUnit = selectedBaseUnit
        ..baseUnitSize = baseUnitSize
        ..units = units
        ..totalBaseUnits = normalizedBaseUnits
        ..remainingBaseUnits = normalizedBaseUnits
        ..totalBuyingCost = totalBuyingCost
        ..purchaseDate = purchaseDate
        ..lastModified = DateTime.now()
        ..syncStatus = false
        ..operationType = 'update'
        ..modifiedFields = editModifiedFields;

      await existing.save();

      // ✅ Also save each BatchUnit to its own box if needed
      final batchUnitBox = Hive.box<BatchUnit>('batch_units');
      for (var unit in units) {
        // Check if unit already exists
        var existingUnit = batchUnitBox.values
            .where((u) => u.unitBatchCode == unit.unitBatchCode)
            .firstOrNull;

        if (existingUnit != null) {
          // Update existing unit
          existingUnit
            ..level = unit.level
            ..unitsPerPackage = unit.unitsPerPackage
            ..quantity = unit.quantity
            ..buyingPrice = unit.buyingPrice
            ..syncStatus = false
            ..lastModified = DateTime.now()
            ..operationType = 'update'
            ..modifiedFields = [
              'level',
              'unitsPerPackage',
              'quantity',
              'buyingPrice'
            ];
          await existingUnit.save();
        } else {
          // Add new unit
          await batchUnitBox.add(unit);
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Batch updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, existing);
    } else {
      // ✅ CREATE NEW
      final batch = ProductBatch(
        batchCode: DateTime.now().millisecondsSinceEpoch.toString(),
        productCode: widget.projectItem.projectItemCode,
        reference: referenceCtrl.text.trim(),
        baseUnitType: selectedBaseUnitType,
        baseUnit: selectedBaseUnit,
        baseUnitSize: baseUnitSize,
        units: units,
        totalBaseUnits: normalizedBaseUnits,
        remainingBaseUnits: normalizedBaseUnits,
        totalBuyingCost: totalBuyingCost,
        purchaseDate: purchaseDate,
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
        // ✅ Set sync fields for ProductBatch
        syncStatus: false,
        operationType: 'create',
        modifiedFields: [
          'reference',
          'units',
          'baseUnitType',
          'baseUnit',
          'baseUnitSize',
          'totalBaseUnits',
          'totalBuyingCost',
          'purchaseDate',
        ],
      );

      await box.add(batch);

      // ✅ Also save each BatchUnit to its own box
      final batchUnitBox = Hive.box<BatchUnit>('batch_units');
      for (var unit in units) {
        await batchUnitBox.add(unit);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Batch created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, batch);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    referenceCtrl.dispose();
    for (final u in packagingUnits) {
      u.unitsPerPackageCtrl.dispose();
      u.packageCountCtrl.dispose();
      u.buyingPriceCtrl.dispose();
    }
    super.dispose();
  }
}

// ------------------------------------------------------------
// Helper model for UI only
class _PackagingUnit {
  String level = 'single';

  final TextEditingController unitsPerPackageCtrl;
  final TextEditingController packageCountCtrl;
  final TextEditingController buyingPriceCtrl;

  _PackagingUnit(VoidCallback onChange)
      : unitsPerPackageCtrl = TextEditingController()..addListener(onChange),
        packageCountCtrl = TextEditingController()..addListener(onChange),
        buyingPriceCtrl = TextEditingController()..addListener(onChange);
}
