import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/projects/stock_unit_type.dart';

import 'package:zitf_system/database/student.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';

class ProjectPaymentScreen extends StatefulWidget {
  final ProjectSaleTransaction? transaction;

  const ProjectPaymentScreen({
    Key? key,
    this.transaction,
  }) : super(key: key);

  @override
  State<ProjectPaymentScreen> createState() => _ProjectPaymentScreenState();
}

enum SellMode {
  unit, // default
  pack, // batch / box / packet
}

class _ProjectPaymentScreenState extends State<ProjectPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final TextEditingController _amountPaidCtrl = TextEditingController();
  final TextEditingController _quantityCtrl = TextEditingController(text: '1');

  Student? _student;
  Project? _project;
  ProjectItem? _item;

  ProductBatch? _selectedBatch;
  BatchSellUnit? _selectedSellUnit;
  int _quantity = 1;

  late List<Student> _students;
  late List<Project> _projects;
  late List<ProjectItem> _items;
  SellMode _sellMode = SellMode.unit; // DEFAULT

  double _expectedAmount = 0;
  double _arrears = 0;
  double derivedExpected = 0;
  double _amountPaid = 0;

  final TextEditingController _pmAmountCtrl = TextEditingController();
  final TextEditingController _pmReferenceCtrl = TextEditingController();
  final TextEditingController _pmPhoneCtrl = TextEditingController();
  final TextEditingController _pmAccountNumberCtrl = TextEditingController();
  final TextEditingController _pmAccountNameCtrl = TextEditingController();
  DateTime _paymentDate = DateTime.now();
  final TextEditingController _paymentDateCtrl = TextEditingController();

  String _paymentMethodType =
      'cash'; // cash | mobile_money | bank_transfer | card | other
  final String _currency = 'USD';
  String? _provider;

  final List<ProjectSaleTransaction> _cart = [];

  double get _cartUserPaying => _cart.fold(0.0, (sum, t) => sum + t.amountPaid);

  final TextEditingController _studentSearchCtrl = TextEditingController();
  List<Student> _filteredStudents = [];

  List<ProjectSaleTransaction> _studentArrears = [];
  double _studentTotalArrears = 0;

  bool _isArrearsPayment = false;
  String? _linkedSaleCode;

  bool get _cartHasArrearsSettlements =>
      _cart.any((t) => t.settlesObligation == true);

  @override
  void initState() {
    super.initState();

    _students = Hive.box<Student>('students').values.toList();
    _projects = Hive.box<Project>('projects').values.toList();
    _items = Hive.box<ProjectItem>('projectItems').values.toList();

    final tx = widget.transaction;

    if (tx != null) {
      _student = Hive.box<Student>('students')
          .values
          .firstWhereOrNull((s) => s.studentIdNumber == tx.studentId);

      _project = Hive.box<Project>('projects')
          .values
          .firstWhereOrNull((p) => p.projectCode == tx.projectCode);

      _item = Hive.box<ProjectItem>('projectItems')
          .values
          .firstWhereOrNull((i) => i.projectItemCode == tx.projectItemCode);

      _selectedBatch = Hive.box<ProductBatch>('product_batches')
          .values
          .firstWhereOrNull((b) => b.batchCode == tx.batchCode);

      _selectedSellUnit = Hive.box<BatchSellUnit>('batch_sell_units')
          .values
          .firstWhereOrNull((u) => u.sellUnitCode == tx.sellUnitCode);

      _quantity = tx.quantitySold;
      _amountPaid = tx.amountPaid;

      _quantityCtrl.text = _quantity.toString();
      _pmAmountCtrl.text = tx.amountPaid.toStringAsFixed(2);

      _paymentMethodType = tx.paymentMethod;
      _paymentDate = tx.paymentDatetransacted ?? DateTime.now();
    }

    _paymentDateCtrl.text = _formatDate(_paymentDate);
  }

  String _formatDate(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  // ---------------- HELPERS ----------------

  List<ProjectItem> get _filteredItems => _items
      .where((i) => i.projectCode == _project?.projectCode && i.active == true)
      .toList();

  ProjectItemPrice? get _activeServicePrice {
    if (_item == null) return null;

    final prices = Hive.box<ProjectItemPrice>('project_item_prices')
        .values
        .where((p) =>
            p.projectItemCode == _item!.projectItemCode &&
            p.effectiveFrom.isBefore(DateTime.now()) &&
            (p.effectiveTo == null || p.effectiveTo!.isAfter(DateTime.now())))
        .toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));

    return prices.isEmpty ? null : prices.first;
  }

  List<ProductBatch> get _availableBatches {
    if (_item == null) return [];

    return Hive.box<ProductBatch>('product_batches')
        .values
        .where((b) =>
            b.productCode == _item!.projectItemCode &&
            (b.remainingBaseUnits ?? 0) > 0)
        .toList();
  }

  List<BatchSellUnit> get _sellUnits {
    if (_selectedBatch == null) return [];

    return Hive.box<BatchSellUnit>('batch_sell_units')
        .values
        .where((u) => u.batchCode == _selectedBatch!.batchCode)
        .toList();
  }

  int get _maxSellableQuantity {
    if (_selectedBatch == null) return 0;

    final batchCode = _selectedBatch!.batchCode;

    final alreadyReserved = _cart
        .where((t) => t.batchCode == batchCode)
        .fold<double>(0, (sum, t) => sum + t.totalBaseUnitsSold);

    final remaining =
        (_selectedBatch!.remainingBaseUnits ?? 0) - alreadyReserved;

    return remaining.floor();
  }

  bool get _canSellPacks {
    if (_selectedBatch == null) return false;

    final remaining = _selectedBatch!.remainingBaseUnits ?? 0;

    final packUnits = _packSellUnits
        .map((u) => u.baseUnitsPerSellUnit ?? 0)
        .where((v) => v > 1)
        .toList()
      ..sort();

    if (packUnits.isEmpty) return false;

    final smallestPack = packUnits.first;

    return remaining >= smallestPack;
  }

  // ---------------- SELL MODE LOGIC ----------------
  bool _isUnitSell(BatchSellUnit u) => (u.baseUnitsPerSellUnit ?? 1) <= 1;
  bool _isPackSell(BatchSellUnit u) => (u.baseUnitsPerSellUnit ?? 0) > 1;

  List<BatchSellUnit> get _unitSellUnits =>
      _sellUnits.where(_isUnitSell).toList();

  List<BatchSellUnit> get _packSellUnits =>
      _sellUnits.where(_isPackSell).toList();

  List<BatchSellUnit> get _visibleSellUnits {
    if (_sellMode == SellMode.pack && !_canSellPacks) {
      return [];
    }
    return _sellMode == SellMode.unit ? _unitSellUnits : _packSellUnits;
  }

  // ---------------- STOCK & TOTALS ----------------

  void _recalculateTotals() {
    if (_item == null) return;

    if (_item!.itemType == 'service') {
      _expectedAmount = _activeServicePrice?.amount ?? 0;
    } else if (_selectedSellUnit != null) {
      // ✅ pricing uses sell-unit price directly
      _expectedAmount = _quantity * _selectedSellUnit!.sellingPrice;
    }

    final paid = double.tryParse(_amountPaidCtrl.text) ?? 0;

    final clamped = paid.clamp(0, _expectedAmount);
    _amountPaidCtrl.text = clamped.toStringAsFixed(2);
    _arrears = (_expectedAmount - clamped).clamp(0, double.infinity);
  }

  // ---------------- PAYMENT ----------------
  ProjectSaleTransaction _buildTransaction() {
    final isGoods = _item!.itemType == 'goods';
    final sellUnit = isGoods ? _selectedSellUnit! : null;
    final batch = isGoods ? _selectedBatch! : null;

    final totalBaseUnitsSold = _quantity.toDouble();

    if (_isArrearsPayment) {
      return ProjectSaleTransaction(
        transactionCode: _uuid.v4(),
        studentId: _student!.studentIdNumber.toString(),
        projectCode: _project!.projectCode,
        projectItemCode: _item!.projectItemCode!,
        batchCode: '',
        sellUnitCode: '',
        sellUnitNameSnapshot: 'ARREARS PAYMENT',
        quantitySold: 0,
        unitSellingPrice: 0,
        totalAmount: _expectedAmount,
        amountPaid: _amountPaid,
        arrears: 0, // legacy only
        baseUnit: '',
        baseUnitType: StockUnitType.piece,
        baseUnitsPerSellUnit: 0,
        totalBaseUnitsSold: 0,
        transactionDate: DateTime.now(),
        paymentMethod: _paymentMethodType,
        paymentMethodCode: _paymentMethodType,
        methodType: _paymentMethodType,
        amountPaidInPaymentMethod: _amountPaid,
        currency: _currency,
        referenceNumber: _pmReferenceCtrl.text.trim(),
        paymentDatetransacted: _paymentDate,
        provider: _provider,

        // 🔥 NEW ENGINE FIELDS
        financialType: 'payment',
        createsObligation: false,
        settlesObligation: true,
        affectsStock: false,
        parentTransactionCode: _linkedSaleCode,

        isDeleted: false,
        lastModified: DateTime.now(),
        reference: '',
      );
    }

    return ProjectSaleTransaction(
      transactionCode: _uuid.v4(),
      studentId: _student?.studentIdNumber ?? '',
      projectCode: _project!.projectCode,
      projectItemCode: _item!.projectItemCode!,
      batchCode: isGoods ? batch!.batchCode ?? '' : '',
      sellUnitCode: isGoods ? sellUnit!.sellUnitCode : '',
      sellUnitNameSnapshot: isGoods ? sellUnit!.unitName : 'SERVICE',
      quantitySold: isGoods ? _quantity : 1,
      unitSellingPrice:
          isGoods ? sellUnit!.sellingPrice : _activeServicePrice!.amount,
      totalAmount: derivedExpected,
      amountPaid: _amountPaid,
      arrears: 0, // 🔴 no longer stored truth
      baseUnit: isGoods ? batch!.baseUnit ?? '' : 'SERVICE',
      baseUnitType: isGoods
          ? (batch!.baseUnitType ?? StockUnitType.piece)
          : StockUnitType.piece,
      baseUnitsPerSellUnit: totalBaseUnitsSold,
      totalBaseUnitsSold: totalBaseUnitsSold,
      transactionDate: DateTime.now(),
      reference: '',
      paymentMethod: _paymentMethodType,
      paymentMethodCode: _paymentMethodType,
      methodType: _paymentMethodType,
      amountPaidInPaymentMethod: _amountPaid,
      currency: _currency,
      referenceNumber: _pmReferenceCtrl.text.trim(),
      phoneNumber:
          _pmPhoneCtrl.text.trim().isEmpty ? null : _pmPhoneCtrl.text.trim(),
      accountNumber: _pmAccountNumberCtrl.text.trim().isEmpty
          ? null
          : _pmAccountNumberCtrl.text.trim(),
      accountName: _pmAccountNameCtrl.text.trim().isEmpty
          ? null
          : _pmAccountNameCtrl.text.trim(),
      paymentDatetransacted: _paymentDate,
      provider: _provider,

      // 🔥 NEW ENGINE FIELDS
      financialType: 'sale',
      createsObligation: true,
      settlesObligation: false,
      affectsStock: isGoods,
      parentTransactionCode: null,

      isDeleted: false,
      lastModified: DateTime.now(),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Center(child: Text('Project Payment Screen'))),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _studentTile(),
                  const Divider(),
                  if (_student != null) ...[
                    Builder(
                      builder: (_) {
                        final detailedArrears = buildStudentArrearsDetails(
                            _student!.studentIdNumber.toString());

                        if (detailedArrears.isEmpty) return const SizedBox();

                        final totalArrears = detailedArrears.fold<double>(
                          0,
                          (s, e) => s + e.arrears,
                        );

                        return Card(
                          color: Colors.red.shade50,
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Arrears: ${totalArrears.toStringAsFixed(2)} $_currency',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...detailedArrears.map((s) {
                                  return Card(
                                    elevation: 2,
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.projectName,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          Text('Item: ${s.itemName}'),
                                          Text('Batch: ${s.batchName}'),
                                          Text(
                                              'Total Amount: ${s.totalAmount.toStringAsFixed(2)} $_currency'),
                                          Text(
                                              'Total Paid: ${s.totalPaid.toStringAsFixed(2)} $_currency'),
                                          Text(
                                            'Arrears: ${s.arrears.toStringAsFixed(2)} $_currency',
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: ElevatedButton(
                                              child: const Text('Load'),
                                              onPressed: () =>
                                                  _loadArrearedTransactionByCode(
                                                      s.transactionCode),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(),
                  _projectDropdown(),
                  const Divider(),
                  const SizedBox(height: 12),
                  _itemDropdown(),
                  if (_item?.itemType == 'service') _servicePrice(),
                  if (_item?.itemType == 'goods') ..._goodsSection(),
                  const SizedBox(height: 20),
                  Text('Total Amount Paid: ${_amountPaid.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                    onPressed: _addToCart,
                  ),
                  const SizedBox(height: 20),
                  _cartDashboard(),
                  const SizedBox(height: 20),
                  _paymentPurposeSection(),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _pmAmountCtrl,
                    builder: (_, __, ___) {
                      final received =
                          double.tryParse(_pmAmountCtrl.text) ?? 0.0;
                      final change = received - _cartUserPaying;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (change > 0)
                            Text(
                              'Change: ${change.toStringAsFixed(2)} $_currency',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          if (change < 0)
                            Text(
                              'Remaining: ${(-change).toStringAsFixed(2)} $_currency',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Confirm & Save All'),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: _cart.isEmpty ? null : _saveCart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _loadArrearedTransactionByCode(String code) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    final tx = txBox.values.firstWhere(
      (t) => t.transactionCode == code,
    );

    _loadArrearedTransaction(tx);
  }

  void _loadArrearedTransaction(ProjectSaleTransaction t) {
    final project = Hive.box<Project>('projects')
        .values
        .firstWhereOrNull((p) => p.projectCode == t.projectCode);

    final item = Hive.box<ProjectItem>('projectItems')
        .values
        .firstWhereOrNull((i) => i.projectItemCode == t.projectItemCode);

    double outstanding = calculateArrears(t.transactionCode);

// 🔥 subtract cart payments too
    final cartPayments = _cart
        .where((c) => c.parentTransactionCode == t.transactionCode)
        .fold<double>(0, (sum, c) => sum + c.amountPaid);

    outstanding = (outstanding - cartPayments).clamp(0, double.infinity);

    setState(() {
      _isArrearsPayment = true;
      _linkedSaleCode = t.transactionCode;

      _project = project;
      _item = item;

      // 🔥 Disable goods logic

      _selectedBatch = Hive.box<ProductBatch>('product_batches')
          .values
          .firstWhereOrNull((b) => b.batchCode == t.batchCode);

      _selectedSellUnit = Hive.box<BatchSellUnit>('batch_sell_units')
          .values
          .firstWhereOrNull((u) => u.sellUnitCode == t.sellUnitCode);

      _quantity = t.quantitySold;
      _quantityCtrl.text = _quantity.toString();

      // 🔥 Only outstanding matters
      _expectedAmount = outstanding;
      derivedExpected = outstanding;

      _amountPaid = outstanding;
      _arrears = 0;

      _amountPaidCtrl.text = outstanding.toStringAsFixed(2);
      _syncPaymentMethodAmount();
    });
  }

  double calculateArrears(String saleCode) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    final sale = txBox.values.firstWhere(
      (t) => t.transactionCode == saleCode && t.createsObligation,
    );

    final subsequentPayments = txBox.values
        .where(
            (t) => t.parentTransactionCode == saleCode && t.settlesObligation)
        .fold<double>(0, (sum, t) => sum + t.amountPaid);

    final totalPaid = sale.amountPaid + subsequentPayments;

    return (sale.totalAmount - totalPaid).clamp(0, double.infinity);
  }

  void _rebindCartToStudent(Student? student) {
    if (!_cartRequiresStudent) return;

    final newStudentId = student?.studentIdNumber ?? '';

    for (final tx in _cart) {
      tx.studentId = newStudentId;
    }
  }

  List<ArrearsSummary> buildStudentArrearsDetails(String studentId) {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');
    final batchBox = Hive.box<ProductBatch>('product_batches');

    final sales = txBox.values.where((t) =>
        t.studentId == studentId && t.createsObligation && t.isDeleted != true);

    return sales
        .map((sale) {
          final payments = txBox.values
              .where((t) =>
                  t.parentTransactionCode == sale.transactionCode &&
                  t.settlesObligation &&
                  t.isDeleted != true)
              .fold<double>(0, (sum, t) => sum + t.amountPaid);

          final totalPaid = sale.amountPaid + payments;
          final arrears =
              (sale.totalAmount - totalPaid).clamp(0, double.infinity);
// 🔥 subtract cart payments for same parent sale
          final cartPayments = _cart
              .where((t) => t.parentTransactionCode == sale.transactionCode)
              .fold<double>(0, (sum, t) => sum + t.amountPaid);

          final adjustedArrears =
              (arrears - cartPayments).clamp(0, double.infinity);

          final project =
              _projects.firstWhere((p) => p.projectCode == sale.projectCode);

          final item = _items
              .firstWhere((i) => i.projectItemCode == sale.projectItemCode);

          final batch =
              batchBox.values.firstWhere((b) => b.batchCode == sale.batchCode);

          return ArrearsSummary(
            transactionCode: sale.transactionCode,
            projectName: project.name,
            itemName: item.name ?? '',
            batchName: batch.reference ?? '',
            totalAmount: sale.totalAmount,
            totalPaid: totalPaid + cartPayments,
            arrears: adjustedArrears.toDouble(),
          );
        })
        .where((s) => s.arrears > 0)
        .toList();
  }

  bool get _cartRequiresStudent => _cart.any((t) {
        final project =
            _projects.firstWhereOrNull((p) => p.projectCode == t.projectCode);
        return project?.studentPayable == true;
      });
  List<ProjectSaleTransaction> get _activeCartItems {
    final projectBox = Hive.box<Project>('projects');
    final itemBox = Hive.box<ProjectItem>('projectItems');
    final batchBox = Hive.box<ProductBatch>('product_batches');

    return _cart.where((t) {
      final project = projectBox.values
          .firstWhereOrNull((p) => p.projectCode == t.projectCode);

      final item = itemBox.values
          .firstWhereOrNull((i) => i.projectItemCode == t.projectItemCode);

      final batch =
          batchBox.values.firstWhereOrNull((b) => b.batchCode == t.batchCode);

      // 🔥 Only allow active + not deleted projects
      if (project == null) return false;
      if (project.status.toLowerCase() == 'deleted') return false;

      // Optional safety (recommended)

      return true;
    }).toList();
  }

  Widget _cartDashboard() {
    final activeCart = _activeCartItems;
    if (activeCart.isEmpty) return const SizedBox();

    final totalExpected = activeCart.fold(0.0, (sum, t) => sum + t.totalAmount);

    final totalPaid = activeCart.fold(0.0, (sum, t) => sum + t.amountPaid);

    final totalArrears = (totalExpected - totalPaid).clamp(0, double.infinity);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_cartRequiresStudent && _student != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Cart bound to: ${_student!.name} ${_student!.surname}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            const Text(
              'Cart',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            ...activeCart.map((t) {
              final project = Hive.box<Project>('projects')
                  .values
                  .firstWhereOrNull((p) => p.projectCode == t.projectCode);

              final item = Hive.box<ProjectItem>('projectItems')
                  .values
                  .firstWhereOrNull(
                      (i) => i.projectItemCode == t.projectItemCode);

              final batch = Hive.box<ProductBatch>('product_batches')
                  .values
                  .firstWhereOrNull((b) => b.batchCode == t.batchCode);

              final lineArrears =
                  (t.totalAmount - t.amountPaid).clamp(0, double.infinity);

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(8),
                  title: Text(
                    '${item?.name ?? 'Item'} '
                    ' × ${t.quantitySold} @ \$${t.totalAmount / t.quantitySold} $_currency each',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (project != null) Text('Project: ${project.name}'),
                      if (batch != null) Text('Batch Ref: ${batch.reference}'),
                      Text(
                          'Total Price: ${((t.totalAmount)).toStringAsFixed(2)}'),
                      Text(
                          'Amount Entered: ${t.amountPaid.toStringAsFixed(2)}'),
                      if (lineArrears > 0)
                        Text(
                          'Arrears: ${lineArrears.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.amountPaid.toStringAsFixed(2),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.delete,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _removeFromCart(t),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const Divider(),
            _kv(
              'Cart Expected Total',
              totalExpected.toStringAsFixed(2),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(),
            _kv(
              'Cart Total Paid',
              totalPaid.toStringAsFixed(2),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Divider(),
            _kv(
              'Cart Total Arrears',
              totalArrears.toStringAsFixed(2),
              valueStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart() {
    final projectRequiresStudent = _project?.studentPayable == true;

    // If project requires student OR cart already requires student
    if ((projectRequiresStudent || _cartRequiresStudent) && _student == null) {
      _snack('Select student');
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (!_isArrearsPayment) {
      if (_selectedBatch == null || _selectedSellUnit == null) {
        _snack('Select batch and unit');
        return;
      }
    }

    final maxAllowed = _maxSellableQuantity;

    if (_quantity > maxAllowed) {
      _snack('Only $maxAllowed available');
      return;
    }

    final tx = _buildTransaction();

    setState(() {
      _cart.add(tx);
      _updatePaymentMethodFromCart();

      // 🔥 Apply inheritance logic after add
      _applyCartStudentInheritance();
      _updatePaymentMethodFromCart();
      if (_isArrearsPayment) {
        _unloadArrears();
      } else {
        _resetItemFormAll();
      }

      _scanStudentArrears(); // 🔥 immediately refresh arrears list
    });
  }

  void _updatePaymentMethodFromCart() {
    _pmAmountCtrl.text = _cartUserPaying.toStringAsFixed(2);
  }

  void _applyCartStudentInheritance() {
    final requiresStudent = _cartRequiresStudent;

    if (!requiresStudent) {
      for (final t in _cart) {
        t.studentId = '';
      }
      return;
    }

    // If student required but none selected → block silently
    if (_student == null) return;

    _rebindCartToStudent(_student);
  }

  void _removeFromCart(ProjectSaleTransaction tx) {
    setState(() {
      _cart.remove(tx);

      // 🔥 Re-evaluate inheritance after removal
      _applyCartStudentInheritance();
      _updatePaymentMethodFromCart();
    });
  }

  Future<void> _saveCart() async {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');
    final batchBox = Hive.box<ProductBatch>('product_batches');

    if (_cart.isEmpty) {
      _snack('Cart is empty');
      return;
    }
    final received = double.tryParse(_pmAmountCtrl.text) ?? 0;

    if (received < _cartUserPaying) {
      _snack('Amount received cannot be less than total to pay');
      return;
    }

    try {
      for (final tx in _cart) {
        // 1️⃣ Deduct stock first
        if (tx.affectsStock) {
          if (tx.batchCode.isNotEmpty) {
            final batch =
                batchBox.values.firstWhere((b) => b.batchCode == tx.batchCode);

            batch.remainingBaseUnits =
                (batch.remainingBaseUnits ?? 0) - tx.totalBaseUnitsSold;

            await batch.save();
          }
        }

        // 2️⃣ Save transaction
        await txBox.add(tx);

        debugPrint('Saved ${tx.projectItemCode}');
      }

      setState(() {
        _cart.clear();
      });

      _resetTransactions();

      _snack('All items saved successfully');
    } catch (e) {
      debugPrint('SAVE ERROR: $e');
      _snack('Error saving cart');
    }
  }

  Widget _paymentPurposeSection() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 24),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            /// PAYMENT METHOD
            DropdownButtonFormField<String>(
              value: _paymentMethodType,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(
                    value: 'mobile_money', child: Text('Mobile Money')),
                DropdownMenuItem(
                    value: 'bank_transfer', child: Text('Bank Transfer')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _paymentMethodType = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _pmAmountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount Received ($_currency)',
                hintText: _amountPaid.toStringAsFixed(2),
              ),
              onTap: () => _pmAmountCtrl.clear(),
              validator: (v) {
                final val = double.tryParse(v ?? '') ?? 0;
                if (val < _cartUserPaying) {
                  return 'Cannot be less than total (${_cartUserPaying.toStringAsFixed(2)})';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),

            /// ADDITIONAL DETAILS PER PAYMENT METHOD
            if (_paymentMethodType != 'cash') ...[
              TextFormField(
                controller: _pmReferenceCtrl,
                decoration: const InputDecoration(labelText: 'Reference'),
              ),
            ],

            if (_paymentMethodType == 'mobile_money') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _pmPhoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Provider'),
                onChanged: (v) => _provider = v.trim(),
              ),
            ],

            if (_paymentMethodType == 'bank_transfer') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _pmAccountNumberCtrl,
                decoration: const InputDecoration(labelText: 'Account Number'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _pmAccountNameCtrl,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
            ],

            const SizedBox(height: 16),

            /// DYNAMIC CHANGE / ARREARS DISPLAY
          ],
        ),
      ),
    );
  }

  Widget _studentTile() {
    return ListTile(
      title: Text(
        _student == null
            ? 'Select Student'
            : '${_student!.name} ${_student!.surname}',
      ),
      subtitle: _student == null ? null : Text(_student!.class_ ?? ''),
      trailing: const Icon(Icons.search),
      onTap: _project?.studentPayable == true
          ? _pickStudentDialog
          : _pickStudentDialog,
    );
  }

  Widget _projectDropdown() {
    return DropdownButtonFormField<Project>(
      value: _project,
      decoration: const InputDecoration(labelText: 'Project'),
      items: _projects
          .map((p) => DropdownMenuItem(
                value: p,
                child: Text(p.name),
              ))
          .toList(),
      onChanged: _isArrearsPayment
          ? null
          : (v) => setState(() {
                _project = v;
                if (!_cartRequiresStudent) {
                  // _student = null;
                }
                _item = null;
                _selectedBatch = null;
                _selectedSellUnit = null;
                _recalculateSellMode();
                _resetPricing(); // 🔥 REQUIRED
              }),
    );
  }

  Widget _itemDropdown() {
    return DropdownButtonFormField<ProjectItem>(
      value: _item,
      decoration: const InputDecoration(labelText: 'Item / Service'),
      items: _filteredItems
          .map((i) => DropdownMenuItem(
                value: i,
                child: Text(i.name ?? ''),
              ))
          .toList(),
      onChanged: _isArrearsPayment
          ? null
          : (v) => setState(() {
                _item = v;
                _selectedBatch = null;
                _selectedSellUnit = null;
                _recalculateSellMode();
                _resetPricing(); // 🔥 REQUIRED
              }),
    );
  }

  Widget _servicePrice() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _activeServicePrice != null
            ? 'Price: ${_activeServicePrice!.amount}'
            : 'No active price',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  void _recalculateSellMode() {
    _sellMode = SellMode.unit;
  }

  List<Widget> _goodsSection() => [
        DropdownButtonFormField<ProductBatch>(
          value: _selectedBatch,
          decoration: const InputDecoration(labelText: 'Batch'),
          items: _availableBatches
              .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(
                        '${b.reference} (${b.remainingBaseUnits?.toStringAsFixed(2)} ${b.baseUnit})'),
                  ))
              .toList(),
          onChanged: _isArrearsPayment
              ? null
              : (v) {
                  setState(() {
                    _selectedBatch = v;
                    _sellMode = SellMode.unit;

                    // Reset selections
                    _selectedSellUnit = null;

                    // Auto-select first sell unit
                    final units = _sellUnits;
                    _selectedSellUnit = units.isNotEmpty ? units.first : null;

                    // Now we can safely compute max
                    final maxQty = _maxSellableQuantity;

                    if (maxQty >= 1) {
                      _quantity = 1;
                      _quantityCtrl.text = '1';
                    } else {
                      _quantity = 0;
                      _quantityCtrl.clear();
                    }

                    // Recalculate expected amount
                    _recalculateTotals();

                    // 🔥 Default pricing to expected amount
                    if ((_expectedAmount / _maxSellableQuantity) > 0) {
                      _amountPaid = _expectedAmount / _maxSellableQuantity;
                      _amountPaidCtrl.text =
                          (_expectedAmount / _maxSellableQuantity)
                              .toStringAsFixed(2);
                      _pmAmountCtrl.text =
                          (_expectedAmount / _maxSellableQuantity)
                              .toStringAsFixed(2);
                      _arrears = 0;
                    } else {
                      _amountPaid = 0;
                      _amountPaidCtrl.clear();
                      _pmAmountCtrl.clear();
                      _arrears = 0;
                    }
                  });
                },
        ),
        const SizedBox(height: 12),
        if (_selectedSellUnit != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Available: $_maxSellableQuantity ${_selectedSellUnit!.unitName}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        const SizedBox(height: 12),
        TextFormField(
          enabled: !_isArrearsPayment,
          controller: _quantityCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Quantity (max $_maxSellableQuantity)',
          ),
          validator: (v) {
            final q = int.tryParse(v ?? '') ?? 0;
            if (q <= 0) return 'Invalid quantity';
            if (q > _maxSellableQuantity) {
              return 'Only $_maxSellableQuantity available';
            }
            return null;
          },
          onChanged: (v) {
            final parsed = int.tryParse(v) ?? 1;

            final clamped = parsed.clamp(1, _maxSellableQuantity);

            if (parsed != clamped) {
              _quantityCtrl.text = clamped.toString();
              _quantityCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _quantityCtrl.text.length),
              );
            }

            setState(() {
              _quantity = clamped;
              _recalculateTotals();
              _amountPaid = _expectedAmount / _maxSellableQuantity;
              _amountPaidCtrl.text =
                  (_expectedAmount / _maxSellableQuantity).toStringAsFixed(2);
              _amountPaidCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _amountPaidCtrl.text.length),
              );

              // 3️⃣ Reset arrears
              _arrears = 0;

              // 4️⃣ Sync payment method amount
              _pmAmountCtrl.text =
                  (_expectedAmount / _maxSellableQuantity).toStringAsFixed(2);
            });
          },
        ),
        _pricingDashboard(),
      ];

  // ---------------- STUDENT PICKER ----------------
  Widget _pricingDashboard() {
    if (_isArrearsPayment) {
      final outstanding = _expectedAmount;

      return Card(
        elevation: 2,
        margin: const EdgeInsets.only(top: 16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Arrears Settlement',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _kv(
                'Outstanding Amount',
                outstanding.toStringAsFixed(2),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountPaidCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount Paying'),
                validator: (v) {
                  final val = double.tryParse(v ?? '') ?? 0;
                  if (val < 0) return 'Invalid';
                  if (val > outstanding) {
                    return 'Cannot exceed ${outstanding.toStringAsFixed(2)}';
                  }
                  return null;
                },
                onChanged: (v) {
                  final parsed = double.tryParse(v) ?? 0;
                  final clamped = parsed.clamp(0, outstanding);

                  if (parsed != clamped) {
                    _amountPaidCtrl.text = clamped.toStringAsFixed(2);
                    _amountPaidCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _amountPaidCtrl.text.length),
                    );
                  }

                  setState(() {
                    _amountPaid = clamped.toDouble();
                    _arrears =
                        (outstanding - clamped).clamp(0, double.infinity);

                    _syncPaymentMethodAmount();
                  });
                },
              ),
              const SizedBox(height: 6),
              _kv(
                'Remaining',
                _arrears.toStringAsFixed(2),
                valueStyle: TextStyle(
                  color: _arrears > 0 ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Unload'),
                  onPressed: _unloadArrears,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_selectedSellUnit == null || _selectedBatch == null) {
      return const SizedBox();
    }

    final double pricePerUnit =
        (_selectedBatch!.totalBaseUnits != null && _expectedAmount != 0)
            ? ((_expectedAmount / _quantity) / _selectedBatch!.totalBaseUnits!)
            : 0;

    derivedExpected = pricePerUnit * _quantity;

    final double derivedOutstanding = (derivedExpected - _amountPaid);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing Breakdown',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _kv(
              'Sellable Units',
              '$_maxSellableQuantity ${_selectedBatch!.baseUnit}',
            ),
            _kv(
              'Price per Unit',
              pricePerUnit.toStringAsFixed(2),
            ),
            const Divider(height: 24),
            _kv(
              'Expected Amount',
              derivedExpected.toStringAsFixed(2),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountPaidCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount Paid'),
              validator: (v) {
                final paid = double.tryParse(v ?? '') ?? 0;
                if (paid < 0) return 'Invalid amount';
                if (paid > derivedExpected) {
                  return 'Cannot exceed ${derivedExpected.toStringAsFixed(2)}';
                }
                return null;
              },
              onTap: () {
                // Optional: clear only if you want
                _amountPaidCtrl.clear();
              },
              onChanged: (v) {
                final parsed = double.tryParse(v) ?? 0;
                final clamped =
                    parsed > derivedExpected ? derivedExpected : parsed;

                // ✅ Do NOT overwrite text here; just update state
                setState(() {
                  _amountPaid = clamped;
                  _arrears =
                      (derivedExpected - _amountPaid).clamp(0, double.infinity);

                  // 🔥 Sync payment method amount dynamically if desired
                  // _pmAmountCtrl.text = _amountPaid.toString();
                });
              },
              onEditingComplete: () {
                // ✅ Only format when user is done typing
                final parsed = double.tryParse(_amountPaidCtrl.text) ?? 0;
                final clamped =
                    parsed > derivedExpected ? derivedExpected : parsed;
                _amountPaidCtrl.text = clamped.toStringAsFixed(2);
                _amountPaidCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: _amountPaidCtrl.text.length),
                );
              },
            ),
            const SizedBox(height: 6),
            _kv(
              'Outstanding',
              derivedOutstanding.toStringAsFixed(2),
              valueStyle: TextStyle(
                color: _arrears > 0 ? Colors.red : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _syncPaymentMethodAmount() {
    final total = _cartUserPaying + _amountPaid;
    _pmAmountCtrl.text = total.toStringAsFixed(2);
  }

  Widget _kv(String k, String v, {TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k, style: const TextStyle(color: Colors.grey)),
          Text(v, style: valueStyle),
        ],
      ),
    );
  }

  void _pickStudentDialog() {
    _studentSearchCtrl.clear();

    _filteredStudents = List.from(_students);

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, dialogSetState) {
            return AlertDialog(
              title: const Text('Search Student'),
              content: SizedBox(
                width: 500,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      controller: _studentSearchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Search by name, surname, reg, class',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        final q = value.toLowerCase();

                        dialogSetState(() {
                          _filteredStudents = _students.where((s) {
                            return (s.name ?? '').toLowerCase().contains(q) ||
                                (s.surname ?? '').toLowerCase().contains(q) ||
                                (s.studentIdNumber ?? '')
                                    .toLowerCase()
                                    .contains(q) ||
                                (s.class_ ?? '').toLowerCase().contains(q);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: _filteredStudents.map((s) {
                          return ListTile(
                            title: Text('${s.name} ${s.surname}'),
                            subtitle:
                                Text('${s.studentIdNumber} • ${s.class_}'),
                            onTap: () {
                              Navigator.pop(context);
                              _onStudentSelected(s);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onStudentSelected(Student s) {
    // No cart → safe
    if (_cart.isEmpty) {
      setState(() {
        _student = s;
      });
      _scanStudentArrears();
      return;
    }

    // Same student → nothing to do
    if (_student?.studentIdNumber == s.studentIdNumber) {
      return;
    }

    // If cart has arrears settlement → require approval
    if (_cartHasArrearsSettlements) {
      _confirmStudentChangeWithClear(s);
      return;
    }

    // If cart has no arrears settlements → rebind safely
    setState(() {
      _student = s;
      _rebindCartToStudent(s);
    });

    _scanStudentArrears();
  }

  void _confirmStudentChangeWithClear(Student newStudent) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Student?'),
        content: const Text(
          'Cart contains arrears settlements.\n'
          'Changing student will clear all items in the cart.\n\n'
          'Do you want to continue?',
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear & Continue'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (approved != true) return;

    setState(() {
      _cart.clear();
      _student = newStudent;
    });

    _scanStudentArrears();
  }

  void _scanStudentArrears() {
    final txBox = Hive.box<ProjectSaleTransaction>('project_sale_transactions');

    _studentArrears = txBox.values
        .where((t) =>
            t.studentId == _student!.studentIdNumber &&
            t.createsObligation == true)
        .where((sale) {
      final arrears = calculateArrears(sale.transactionCode);
      return arrears > 0;
    }).toList();

    _studentTotalArrears = _studentArrears.fold(
      0.0,
      (sum, t) => sum + calculateArrears(t.transactionCode),
    );

    setState(() {});
  }

  void _resetPricing({bool keepSellMode = false}) {
    debugPrint('🔄 Resetting pricing state');

    _selectedBatch = null;
    _selectedSellUnit = null;

    if (!keepSellMode) {
      _sellMode = SellMode.unit;
    }

    _quantity = 1;
    _expectedAmount = 0;
    _amountPaid = 0;
    _arrears = 0;

    _quantityCtrl.text = '1';
    _amountPaidCtrl.clear();
  }

  void _resetTransactionOnly() {
    _quantity = 1;
    _amountPaid = 0;
    _expectedAmount = 0;
    _arrears = 0;
  }

  void _resetTransactions() {
    setState(() {
      // 🔹 Keep student & project

      // 🔹 Reset item selections
      _item = null;
      _selectedBatch = null;
      _selectedSellUnit = null;

      // 🔹 Reset pricing values
      _quantity = 1;
      _expectedAmount = 0;
      _amountPaid = 0;
      _arrears = 0;
      derivedExpected = 0;

      // 🔹 Reset controllers
      _quantityCtrl.text = '1';
      _amountPaidCtrl.clear();
      _pmAmountCtrl.clear();
      _pmReferenceCtrl.clear();
      _pmPhoneCtrl.clear();
      _pmAccountNumberCtrl.clear();
      _pmAccountNameCtrl.clear();

      // 🔹 Reset payment state
      _paymentMethodType = 'cash';
      _provider = null;
    });
  }

  void _resetItemForm() {
    _item = null;
    _selectedBatch = null;
    _selectedSellUnit = null;
    _quantity = 1;
    _quantityCtrl.clear();
  }

  void _resetItemFormAll() {
    _item = null;
    _selectedBatch = null;
    _selectedSellUnit = null;

    _quantity = 1;
    _expectedAmount = 0;
    derivedExpected = 0;
    _amountPaid = 0;
    _arrears = 0;

    _quantityCtrl.text = '1';
    _amountPaidCtrl.clear();
  }

  void _unloadArrears() {
    setState(() {
      _isArrearsPayment = false;
      _linkedSaleCode = null;

      _item = null;
      _selectedBatch = null;
      _selectedSellUnit = null;

      _quantity = 1;
      _expectedAmount = 0;
      _amountPaid = 0;
      _arrears = 0;

      _quantityCtrl.text = '1';
      _amountPaidCtrl.clear();
      _updatePaymentMethodFromCart();
    });
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _quantityCtrl.dispose();
    super.dispose();
  }
}

class BatchStockBreakdown {
  final int fullBatches;
  final double looseUnits;

  const BatchStockBreakdown({
    required this.fullBatches,
    required this.looseUnits,
  });
}

class ArrearsSummary {
  final String transactionCode;
  final String projectName;
  final String itemName;
  final String batchName;
  final double totalAmount;
  final double totalPaid;
  final double arrears;

  ArrearsSummary({
    required this.transactionCode,
    required this.projectName,
    required this.itemName,
    required this.batchName,
    required this.totalAmount,
    required this.totalPaid,
    required this.arrears,
  });
}
