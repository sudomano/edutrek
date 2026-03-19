import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/projects/project_batching/batch_sell_unit_screen.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';
import 'package:zitf_system/database/projects/packaging_level.dart';
import 'package:zitf_system/projects/project_batching/batching_price_screen.dart';
import 'package:zitf_system/soft_delete_contract/soft_delete_product_batch.dart';

/* -------------------- SCREEN -------------------- */

class ProjectItemViewScreen extends StatelessWidget {
  final ProjectItem projectItem;

  const ProjectItemViewScreen({super.key, required this.projectItem});

  @override
  Widget build(BuildContext context) {
    final isGoods = projectItem.itemType == 'goods';

    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text(projectItem.name!.toUpperCase() ?? '')),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: isGoods
            ? _GoodsBatchesView(projectItem)
            : _ServicePricesView(projectItem),
      ),
    );
  }
}

/* -------------------- HELPERS -------------------- */

String money(double v) => NumberFormat.currency(symbol: '\$ ').format(v);

String date(DateTime? d) =>
    d == null ? '-' : DateFormat('yyyy-MM-dd').format(d);

String unitTypeLabel(StockUnitType? t) {
  switch (t) {
    case StockUnitType.piece:
      return 'pcs';
    case StockUnitType.weight:
      return 'kg';
    case StockUnitType.volume:
      return 'L';
    default:
      return '-';
  }
}

String packagingLabel(PackagingLevel level) {
  return level.name.toUpperCase();
}

/* -------------------- GOODS VIEW -------------------- */

class _GoodsBatchesView extends StatelessWidget {
  final ProjectItem projectItem;

  const _GoodsBatchesView(this.projectItem);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<ProductBatch>('product_batches').listenable(),
      builder: (context, Box<ProductBatch> box, _) {
        final allBatches = box.values
            .where((b) => b.productCode == projectItem.projectItemCode)
            .toList();

        final activeBatches =
            allBatches.where((b) => b.operationType != 'delete').toList();

        final deletedBatches =
            allBatches.where((b) => b.operationType == 'delete').toList();

        if (activeBatches.isEmpty && deletedBatches.isEmpty) {
          return const Center(child: Text('No batches recorded'));
        }

        return ListView(
          children: [
            // -------- ACTIVE BATCHES --------
            ...activeBatches.map((b) => _activeBatchCard(context, b)),

            // -------- DELETED BATCHES --------
            if (deletedBatches.isNotEmpty) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  'Deleted Batches (${deletedBatches.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                children: deletedBatches
                    .map((b) => _deletedBatchTile(context, b))
                    .toList(),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _activeBatchCard(BuildContext context, ProductBatch b) {
    final totalUnits = (b.units ?? []).fold<double>(
      0,
      (sum, u) => sum + (u.unitsPerPackage * u.quantity),
    );
    final soldUnits = _totalSoldBaseUnits(b.batchCode!);
    final remainingUnits = (totalUnits - soldUnits).clamp(0, totalUnits);
    final totalCost = b.totalBuyingCost ?? 0;

    final costPerBaseUnit = totalUnits > 0 ? totalCost / totalUnits : 0;
    final hasSales = remainingUnits < totalUnits;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BatchSellUnitsScreen(batch: b),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /* -------- HEADER -------- */

              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Batch Ref: ${b.reference}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (hasSales)
                    const Chip(
                      label: Text('IN USE'),
                      backgroundColor: Colors.orangeAccent,
                    ),

                  // ✏️ EDIT ICON
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      color: hasSales ? Colors.grey : Colors.blue,
                    ),
                    tooltip: hasSales
                        ? 'Cannot edit: stock already issued'
                        : 'Edit batch',
                    onPressed: hasSales
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CreateProductBatchScreen(
                                  projectItem: projectItem,
                                  batch: b,
                                ),
                              ),
                            );
                          },
                  ),
                  // 🗑 DELETE (SOFT)
                  IconButton(
                    icon: Icon(
                      Icons.delete,
                      color: hasSales ? Colors.grey : Colors.red,
                    ),
                    tooltip: hasSales
                        ? 'Cannot delete: stock already issued'
                        : 'Delete batch',
                    onPressed:
                        hasSales ? null : () => _confirmDelete(context, b),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Base Unit: ${b.baseUnit} (${unitTypeLabel(b.baseUnitType)})',
                style: const TextStyle(color: Colors.black54),
              ),
              const Divider(height: 20),

              /* -------- PACKAGING BREAKDOWN -------- */
              const Text(
                'Purchased As:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ...(b.units ?? []).map((u) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${packagingLabel(u.level)} '
                          '(${u.unitsPerPackage} ${b.baseUnit})',
                        ),
                      ),
                      Text(
                        '${u.quantity} × ${money(u.buyingPrice)}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 20),

              /* -------- TOTALS -------- */
              _kv('Total Base Units',
                  '${totalUnits.toStringAsFixed(2)} ${b.baseUnit}'),
              _kv('Remaining Units',
                  '${remainingUnits.toStringAsFixed(2)} ${b.baseUnit}'),
              _kv('Total Buying Price', money(totalCost)),
              _kv(
                'Unit Cost / ${b.baseUnit}',
                money(costPerBaseUnit.toDouble()),
              ),
              _kv('Purchased On', date(b.purchaseDate)),
            ],
          ),
        ),
      ),
    );
  }

  double _totalSoldBaseUnits(String batchCode) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    return txBox.values
        .where((t) => t.batchCode == batchCode && t.isDeleted == false)
        .fold<double>(
          0,
          (sum, t) => sum + t.totalBaseUnitsSold,
        );
  }

  Widget _deletedBatchTile(BuildContext context, ProductBatch b) {
    return Card(
      color: Colors.red.shade50,
      child: ListTile(
        leading: const Icon(Icons.restore, color: Colors.red),
        title: Text(
          'Batch Ref: ${b.reference}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Deleted on ${date(b.lastModified)}',
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: TextButton.icon(
          icon: const Icon(Icons.undo),
          label: const Text('UNDO'),
          onPressed: () => _confirmUndo(context, b),
        ),
      ),
    );
  }

  void _confirmUndo(BuildContext context, ProductBatch batch) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restore Batch'),
        content: const Text(
          'This batch will be restored and become active again.\n\n'
          'Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await undoDeleteBatch(batch);
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductBatch batch) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Batch'),
        content: const Text(
          'This will remove the batch from active use.\n'
          'The record will be kept for audit and sync.\n\n'
          'Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await softDeleteBatch(batch);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Batch deleted'),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () => undoDeleteBatch(batch),
                  ),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Text(
            v,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/* -------------------- SERVICES -------------------- */

class _ServicePricesView extends StatelessWidget {
  final ProjectItem projectItem;

  const _ServicePricesView(this.projectItem);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable:
          Hive.box<ProjectItemPrice>('project_item_prices').listenable(),
      builder: (context, Box<ProjectItemPrice> box, _) {
        final prices = box.values
            .where((p) =>
                p.projectItemCode == projectItem.projectItemCode &&
                p.operationType != 'delete')
            .toList();

        if (prices.isEmpty) {
          return const Center(child: Text('No prices set'));
        }

        return ListView.builder(
          itemCount: prices.length,
          itemBuilder: (_, index) {
            final p = prices[index];

            return Card(
              elevation: 2,
              child: ListTile(
                title: Text(
                  money(p.amount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pricing Type: ${p.pricingType}'),
                    if (p.appliesTo != null) Text('Applies To: ${p.appliesTo}'),
                    Text('Effective From: ${date(p.effectiveFrom)}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
