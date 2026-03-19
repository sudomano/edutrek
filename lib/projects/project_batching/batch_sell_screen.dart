import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/projects/project_batching/create_or_edit_sell_unit_screen.dart';

class BatchSellUnitsScreen extends StatelessWidget {
  final ProductBatch batch;

  const BatchSellUnitsScreen({super.key, required this.batch});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<BatchSellUnit>('batch_sell_units');

    return Scaffold(
      appBar: AppBar(
        title: Text('Sell Units: ${batch.reference}'),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateOrEditSellUnitScreen(batch: batch),
            ),
          );
        },
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<BatchSellUnit> sellBox, _) {
          final units = sellBox.values
              .where((u) => u.batchCode == batch.batchCode && u.active == true)
              .toList();

          if (units.isEmpty) {
            return const Center(child: Text('No selling units yet'));
          }

          return ListView.separated(
            itemCount: units.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, index) {
              final unit = units[index];
              return ListTile(
                title: Text(unit.unitName),
                subtitle: Text(
                    'x${unit.quantityMultiplier} • Sell @ ${unit.sellingPrice}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreateOrEditSellUnitScreen(
                          batch: batch, sellUnit: unit),
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
