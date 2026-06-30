// serializers.dart - Export all serializers
export 'stock_unit_type_serializer.dart';
export 'packaging_level_serializer.dart';
export 'batch_unit_serializer.dart';
export 'product_batch_serializer.dart';
export 'batch_sell_unit_serializer.dart';
export 'project_item_price_serializer.dart';

// Helper function (shared)
double _toDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
