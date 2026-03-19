import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:zitf_system/database/projects/packaging_level.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';

/// =====================================================
/// 1️⃣ CREATE / EDIT PRODUCT BATCH
/// =====================================================
/// This screen ONLY creates the batch header.
/// It does NOT handle packaging-level logic.
/// Packaging & selling are handled later.
class CreateProductsellBatchScreen extends StatefulWidget {
  final ProjectItem projectItem;
  final ProductBatch? batch;

  const CreateProductsellBatchScreen({
    super.key,
    required this.projectItem,
    this.batch,
  });

  @override
  State<CreateProductsellBatchScreen> createState() =>
      _CreateProductsellBatchScreenState();
}

class _CreateProductsellBatchScreenState
    extends State<CreateProductsellBatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  final _totalCostController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Pre-fill fields when editing
    if (widget.batch != null) {
      _referenceController.text = widget.batch!.reference ?? '';
      _totalUnitsController.text =
          (widget.batch!.totalBaseUnits ?? 0).toString();
      _totalCostController.text =
          (widget.batch!.totalBuyingCost ?? 0).toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.batch == null ? 'Create Batch' : 'Edit Batch'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'Batch Reference'),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter reference' : null,
              ),
              TextFormField(
                controller: _totalUnitsController,
                decoration:
                    const InputDecoration(labelText: 'Total Base Units'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Invalid number' : null,
              ),
              TextFormField(
                controller: _totalCostController,
                decoration:
                    const InputDecoration(labelText: 'Total Buying Cost'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Invalid cost' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveBatch,
                child: const Text('Save Batch'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBatch() async {
    if (!_formKey.currentState!.validate()) return;

    final box = await Hive.openBox<ProductBatch>('product_batches');

    final batch = widget.batch ??
        ProductBatch(
          batchCode: DateTime.now().millisecondsSinceEpoch.toString(),
          productCode: widget.projectItem.projectItemCode,
          createdAt: DateTime.now(),
        );

    batch
      ..reference = _referenceController.text
      ..totalBaseUnits = double.parse(_totalUnitsController.text)
      ..remainingBaseUnits = double.parse(_totalUnitsController.text)
      ..totalBuyingCost = double.parse(_totalCostController.text)
      ..lastModified = DateTime.now()
      ..operationType = 'create';

    await box.put(batch.batchCode, batch);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BatchSellUnitsScreen(batch: batch),
      ),
    );
  }
}

/// =====================================================
/// 2️⃣ BATCH SELL UNITS LIST (PER PACKAGING LEVEL)
/// =====================================================
/// This screen shows ONE row PER PACKAGING LEVEL.
/// Each level is isolated and priced independently.
class BatchSellUnitsScreen extends StatelessWidget {
  final ProductBatch batch;

  const BatchSellUnitsScreen({super.key, required this.batch});
  void _showRestoreSheet(
    BuildContext context,
    ProductBatch batch,
    PackagingLevel level,
  ) {
    final box = Hive.box<BatchSellUnit>('batch_sell_units');

    final deletedUnits = box.values.where((u) =>
        u.batchCode == batch.batchCode &&
        u.packagingLevel == level &&
        !u.active);

    if (deletedUnits.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No deleted units to restore')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(12),
        children: deletedUnits.map((u) {
          return ListTile(
            title: Text(u.unitName),
            subtitle: Text(
              'Deleted on ${u.deletedAt}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.restore),
            onTap: () async {
              u
                ..active = true
                ..deletedAt = null
                ..lastModified = DateTime.now();

              await box.put(u.sellUnitCode, u);
              Navigator.pop(context);
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sellBox = Hive.box<BatchSellUnit>('batch_sell_units');

    return Scaffold(
      appBar: AppBar(
        title: const Center(child: Text('Batch Selling Units')),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restore deleted sell units',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RestoreSellUnitsScreen(batch: batch),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: sellBox.listenable(),
        builder: (context, Box<BatchSellUnit> box, _) {
          final levels =
              batch.units?.map((u) => u.level).toSet().toList() ?? [];

          if (levels.isEmpty) {
            return const Center(child: Text('No packaging levels found'));
          }

          return ListView.builder(
            itemCount: levels.length,
            itemBuilder: (_, index) {
              final level = levels[index];

              final BatchSellUnit? existing = box.values
                  .where((u) =>
                      u.batchCode == batch.batchCode &&
                      u.packagingLevel == level &&
                      u.active)
                  .cast<BatchSellUnit?>()
                  .firstWhere((u) => u != null, orElse: () => null);

              return ListTile(
                title: Text(level.name.toUpperCase()),
                subtitle: existing == null
                    ? const Text('No selling price set')
                    : Text('Sell @ \$${existing.sellingPrice}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateOrEditSellUnitScreen(
                        batch: batch,
                        packagingLevel: level,
                        existing: existing,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class RestoreSellUnitsScreen extends StatelessWidget {
  final ProductBatch batch;

  const RestoreSellUnitsScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<BatchSellUnit>('batch_sell_units');

    final deletedUnits =
        box.values.where((u) => u.batchCode == batch.batchCode && !u.active);

    return Scaffold(
      appBar: AppBar(title: const Text('Restore Sell Units')),
      body: deletedUnits.isEmpty
          ? const Center(child: Text('No deleted sell units'))
          : ListView(
              children: deletedUnits.map((u) {
                return ListTile(
                  title: Text(u.unitName),
                  subtitle: Text(
                    '${u.packagingLevel!.name} • Deleted ${u.deletedAt}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.restore),
                  onTap: () async {
                    u
                      ..active = true
                      ..deletedAt = null
                      ..lastModified = DateTime.now();

                    await box.put(u.sellUnitCode, u);
                    Navigator.pop(context);
                  },
                );
              }).toList(),
            ),
    );
  }
}

/// =====================================================
/// 3️⃣ CREATE / EDIT SELL UNIT (LEVEL-ISOLATED)
/// =====================================================
/// ⚠️ IMPORTANT RULE:
/// - NO cross-level math
/// - NO implicit breakdowns
/// - Packages ARE the sell units at this level
class CreateOrEditSellUnitScreen extends StatefulWidget {
  final ProductBatch batch;
  final PackagingLevel packagingLevel;
  final BatchSellUnit? existing;

  const CreateOrEditSellUnitScreen({
    super.key,
    required this.batch,
    required this.packagingLevel,
    this.existing,
  });

  @override
  State<CreateOrEditSellUnitScreen> createState() =>
      _CreateOrEditSellUnitScreenState();
}

class _CreateOrEditSellUnitScreenState
    extends State<CreateOrEditSellUnitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _unitNameController = TextEditingController();
  final _quantityMultiplierController = TextEditingController();
  final _sellingPriceController = TextEditingController();

  late int packagesAtThisLevel;
  late double buyingCostPerPackage;
  late double baseUnitsPerPackage;
  late int fullSellUnitsAvailable;
  late String defaultUnitName;
  double _totalSoldBaseUnits(String batchCode) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    return txBox.values
        .where((t) => t.batchCode == batchCode && t.isDeleted == false)
        .fold<double>(
          0,
          (sum, t) => sum + t.totalBaseUnitsSold,
        );
  }

  @override
  void initState() {
    super.initState();

    /// Fetch THIS level's batch data only
    final levelUnit =
        widget.batch.units!.firstWhere((u) => u.level == widget.packagingLevel);

    packagesAtThisLevel = levelUnit.quantity;
    buyingCostPerPackage = levelUnit.buyingPrice;
    baseUnitsPerPackage = levelUnit.unitsPerPackage;

    /// Same-level rules
    fullSellUnitsAvailable = packagesAtThisLevel;

    defaultUnitName = '${widget.packagingLevel.name} '
        '(${baseUnitsPerPackage.toInt()} ${widget.batch.baseUnit})';

    if (widget.existing == null) {
      _unitNameController.text = defaultUnitName;
      _quantityMultiplierController.text = "1";
      sellingPrice = 0;
    } else {
      _unitNameController.text = widget.existing!.unitName;
      _quantityMultiplierController.text =
          widget.existing!.quantityMultiplier.toString();
      _sellingPriceController.text = widget.existing!.sellingPrice.toString();

      sellingPrice = widget.existing!.sellingPrice;
    }
  }

  double sellingPrice = 0;

  double get profitPerUnit => sellingPrice - buyingCostPerPackage;

  double get totalLevelProfit => profitPerUnit * fullSellUnitsAvailable;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            widget.existing == null ? 'Create Sell Unit' : 'Edit Sell Units',
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          _header(),
          const SizedBox(height: 12),
          _infoCard(),
          const SizedBox(height: 16),
          _formCard(),
          const SizedBox(height: 20),
          _profitCard(),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Form(
      key: _formKey,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT: Information
          Expanded(
            flex: 5,
            child: Column(
              children: [
                _header(),
                const SizedBox(height: 12),
                _infoCard(),
                const SizedBox(height: 16),
                _profitCard(),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // RIGHT: Actions
          Expanded(
            flex: 4,
            child: _formCard(),
          ),
        ],
      ),
    );
  }

  Widget _formCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _unitNameController,
              decoration: const InputDecoration(
                labelText: 'Unit Name',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter unit name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sellingPriceController,
              decoration: InputDecoration(
                labelText: 'Selling Price / ${widget.packagingLevel.name}',
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                setState(() {
                  sellingPrice = double.tryParse(v) ?? 0;
                });
              },
              validator: (v) =>
                  double.tryParse(v ?? '') == null ? 'Invalid price' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveUnit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Save Unit',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            if (widget.existing != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Delete Sell Unit'),
                onPressed: _confirmDelete,
              ),
            ]
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Sell Unit'),
        content: const Text(
          'This will hide the sell unit but keep its data. You can undo this later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _softDelete();
    }
  }

  Future<void> _softDelete() async {
    final box = Hive.box<BatchSellUnit>('batch_sell_units');
    final unit = widget.existing!;

    unit
      ..active = false
      ..deletedAt = DateTime.now()
      ..lastModified = DateTime.now();

    await box.put(unit.sellUnitCode, unit);

    Navigator.pop(context);
  }

  Widget _profitCard() {
    return Card(
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _kv(
              'Profit / ${widget.packagingLevel.name}',
              profitPerUnit.toStringAsFixed(2),
            ),
            _kv(
              'Max profit at this level',
              totalLevelProfit.toStringAsFixed(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Center(
      child: Column(
        children: [
          Text(
            widget.packagingLevel.name.toUpperCase(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            widget.batch.reference ?? 'Unnamed Batch',
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  double totalBaseUnits(ProductBatch batch) {
    return batch.units?.fold<double>(
          0,
          (sum, u) => sum + (u.unitsPerPackage * u.quantity),
        ) ??
        0;
  }

  double soldBaseUnits(String batchCode) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    return txBox.values
        .where((t) => t.batchCode == batchCode && (t.isDeleted == false))
        .fold<double>(0, (sum, t) => sum + t.totalBaseUnitsSold);
  }

  Widget _infoCard() {
    final batch = widget.batch;

    // Total base units in batch
    final totalBase = batch.units?.fold<double>(
          0,
          (sum, u) => sum + (u.unitsPerPackage * u.quantity),
        ) ??
        0;

    // Total base units sold
    final soldBase = soldBaseUnits(batch.batchCode!);

    // Remaining base units
    final remainingBase = (totalBase - soldBase).clamp(0, totalBase);

    // Define ONE batch size (largest package = batch)
    final batchLevel = batch.units!
        .reduce((a, b) => a.unitsPerPackage > b.unitsPerPackage ? a : b);

    final unitsPerBatch = batchLevel.unitsPerPackage;

    final fullBatches = remainingBase ~/ unitsPerBatch;
    final singles = remainingBase % unitsPerBatch;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv(
              '${widget.packagingLevel.name}s at this level',
              packagesAtThisLevel.toString(),
            ),
            _kv(
              'Units per ${widget.packagingLevel.name}',
              '${baseUnitsPerPackage.toInt()} ${batch.baseUnit}',
            ),
            _kv(
              'Buying cost / ${widget.packagingLevel.name}',
              buyingCostPerPackage.toStringAsFixed(2),
            ),
            const Divider(height: 24),
            _kv(
              'Remaining Stock',
              '$fullBatches batches + ${singles.toInt()} ${batch.baseUnit}',
            ),
            _kv(
              'Base unit type',
              batch.baseUnitType?.name ?? '-',
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(fontSize: 13)),
          Text(v,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _saveUnit() async {
    if (!_formKey.currentState!.validate()) return;

    final box = Hive.box<BatchSellUnit>('batch_sell_units');

    final sellUnit = widget.existing ??
        BatchSellUnit(
          sellUnitCode:
              '${widget.batch.batchCode}_${widget.packagingLevel.name}',
          batchCode: widget.batch.batchCode!,
          packagingLevel: widget.packagingLevel,
          baseUnitsPerSellUnit: baseUnitsPerPackage,
          baseUnit: widget.batch.baseUnit!,
          baseUnitType: widget.batch.baseUnitType!,
          unitName: _unitNameController.text,
          quantityMultiplier: int.parse(_quantityMultiplierController.text),
          sellingPrice: 0,
          active: true,
          lastModified: DateTime.now(),
        );

    sellUnit
      ..unitName = _unitNameController.text
      ..quantityMultiplier = int.parse(_quantityMultiplierController.text)
      ..sellingPrice = double.parse(_sellingPriceController.text)
      ..active = true
      ..lastModified = DateTime.now();

    await box.put(sellUnit.sellUnitCode, sellUnit);

    Navigator.pop(context);
  }
}
