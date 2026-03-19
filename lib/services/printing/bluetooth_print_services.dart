import 'package:bluetooth_print/bluetooth_print.dart';
import 'package:bluetooth_print/bluetooth_print_model.dart';

class BluetoothPrintService {
  final BluetoothPrint _bluetoothPrint = BluetoothPrint.instance;

  Future<void> init() async {
    await _bluetoothPrint.startScan(timeout: const Duration(seconds: 4));
  }

  Stream<int> get stateStream => _bluetoothPrint.state;

  Future<void> printReceipt(List<LineText> lines) async {
    Map<String, dynamic> config = {};
    await _bluetoothPrint.printReceipt(config, lines);
  }
}
