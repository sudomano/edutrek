import 'package:zitf_system/database/projects/project_item_batch_model.dart';

Future<void> softDeleteBatch(ProductBatch batch) async {
  batch
    ..operationType = 'delete'
    ..syncStatus = false
    ..lastModified = DateTime.now()
    ..modifiedFields = ['operationType'];

  await batch.save();
}

Future<void> undoDeleteBatch(ProductBatch batch) async {
  batch
    ..operationType = 'update'
    ..syncStatus = false
    ..lastModified = DateTime.now()
    ..modifiedFields = ['operationType'];

  await batch.save();
}
