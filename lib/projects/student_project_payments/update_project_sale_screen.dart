import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:zitf_system/database/projects/project_sale_transaction_model.dart';
import 'package:zitf_system/database/projects/project_model.dart';
import 'package:zitf_system/database/projects/project_item_model.dart';
import 'package:zitf_system/database/projects/project_item_price_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_model.dart';
import 'package:zitf_system/database/projects/project_item_batch_sell_model.dart';
import 'package:zitf_system/database/student.dart';

class ProjectSaleTransactionUpdateScreen extends StatefulWidget {
  final ProjectSaleTransaction transaction;

  const ProjectSaleTransactionUpdateScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<ProjectSaleTransactionUpdateScreen> createState() =>
      _ProjectSaleTransactionUpdateScreenState();
}

class _ProjectSaleTransactionUpdateScreenState
    extends State<ProjectSaleTransactionUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  // Controllers
  late TextEditingController _amountPaidCtrl;
  late TextEditingController _quantityCtrl;
  late TextEditingController _pmAmountCtrl;
  late TextEditingController _pmReferenceCtrl;
  late TextEditingController _pmPhoneCtrl;
  late TextEditingController _pmAccountNumberCtrl;
  late TextEditingController _pmAccountNameCtrl;
  late TextEditingController _paymentDateCtrl;

  // Selections
  Student? _student;
  Project? _project;
  ProjectItem? _item;
  ProductBatch? _selectedBatch;
  BatchSellUnit? _selectedSellUnit;
  int _quantity = 1;
  String _paymentMethodType = 'cash';
  String _currency = 'USD';
  String? _provider;
  DateTime _paymentDate = DateTime.now();

  // Data
  late List<Student> _students;
  late List<Project> _projects;
  late List<ProjectItem> _items;

  // Calculated
  double _expectedAmount = 0;
  double _amountPaid = 0;
  double _arrears = 0;
  double derivedExpected = 0;

  @override
  void initState() {
    super.initState();

    final studentsBox = Hive.box<Student>('students');
    final projectsBox = Hive.box<Project>('projects');
    final itemsBox = Hive.box<ProjectItem>('projectItems');

    _students = studentsBox.values.toList();
    _projects = projectsBox.values.toList();
    _items = itemsBox.values.toList();

    /// 1️⃣ Snapshot-first loading
    _student = _students.firstWhereOrNull(
      (s) => s.studentIdNumber == widget.transaction.studentId,
    );

    _project = _projects.firstWhereOrNull(
      (p) => p.projectCode == widget.transaction.projectCode,
    );

    _item = _items.firstWhereOrNull(
      (i) => i.projectItemCode == widget.transaction.projectItemCode,
    );

    /// 2️⃣ Batch selection (from snapshot)
    _selectedBatch = _availableBatches.firstWhereOrNull(
      (b) => b.batchCode == widget.transaction.batchCode,
    );

    /// 3️⃣ Sell unit selection (from snapshot)
    _selectedSellUnit = _sellUnits.firstWhereOrNull(
      (u) => u.sellUnitCode == widget.transaction.sellUnitCode,
    );

    /// 4️⃣ Numeric snapshot values
    _quantity = widget.transaction.quantitySold;
    _amountPaid = widget.transaction.amountPaid;

    _quantityCtrl = TextEditingController(text: _quantity.toString());
    _amountPaidCtrl =
        TextEditingController(text: _amountPaid.toStringAsFixed(2));

    _pmAmountCtrl = TextEditingController(
      text: widget.transaction.amountPaidInPaymentMethod?.toStringAsFixed(2) ??
          '0.00',
    );

    _pmReferenceCtrl =
        TextEditingController(text: widget.transaction.referenceNumber ?? '');
    _pmPhoneCtrl =
        TextEditingController(text: widget.transaction.phoneNumber ?? '');
    _pmAccountNumberCtrl =
        TextEditingController(text: widget.transaction.accountNumber ?? '');
    _pmAccountNameCtrl =
        TextEditingController(text: widget.transaction.accountName ?? '');

    _paymentMethodType = widget.transaction.paymentMethod;
    _paymentDate = widget.transaction.paymentDatetransacted ?? DateTime.now();

    _paymentDateCtrl =
        TextEditingController(text: DateFormat.yMd().format(_paymentDate));

    _recalculateTotals();
  }

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

    return prices.isNotEmpty ? prices.first : null;
  }

  List<ProductBatch> get _availableBatches {
    if (_item == null) return [];
    return Hive.box<ProductBatch>('product_batches')
        .values
        .where((b) => b.productCode == _item!.projectItemCode)
        .toList();
  }

  List<BatchSellUnit> get _sellUnits {
    if (_selectedBatch == null) return [];
    return Hive.box<BatchSellUnit>('batch_sell_units')
        .values
        .where((u) => u.batchCode == _selectedBatch!.batchCode && u.active)
        .toList();
  }

  int get _maxSellableQuantity {
    if (_selectedBatch == null || _selectedSellUnit == null) return 0;
    final remaining = _selectedBatch!.remainingBaseUnits ?? 0;
    final perSellUnit = _selectedSellUnit!.baseUnitsPerSellUnit ?? 1;
    return (remaining / perSellUnit).floor();
  }

  void _recalculateTotals() {
    if (_item == null) return;

    if (_item!.itemType == 'service') {
      _expectedAmount = _activeServicePrice?.amount ?? 0;
    } else if (_selectedSellUnit != null) {
      _expectedAmount = _quantity * _selectedSellUnit!.sellingPrice;
    }

    _arrears = (_expectedAmount - _amountPaid).clamp(0, double.infinity);
    derivedExpected = _expectedAmount;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
        _paymentDateCtrl.text = DateFormat.yMd().format(picked);
      });
    }
  }

  Future<void> _saveUpdatedTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final paidAmount = double.tryParse(_amountPaidCtrl.text) ?? 0;
    final quantity = int.tryParse(_quantityCtrl.text) ?? 1;
    final arrears = (_expectedAmount - paidAmount).clamp(0, double.infinity);

    // Adjust stock if goods
    if (_item?.itemType == 'goods' && _selectedBatch != null) {
      final batch = _selectedBatch!;
      final oldQuantity = widget.transaction.quantitySold;
      final changeInUnits = quantity - oldQuantity;
      final remaining = batch.remainingBaseUnits ?? 0;

      if (remaining - changeInUnits < 0) {
        _snack('Not enough stock. Available: $remaining ${batch.baseUnit}');
        return;
      }

      batch.remainingBaseUnits = remaining - changeInUnits;
      batch.operationType = 'update';
      batch.lastModified = DateTime.now();
      await batch.save();
    }

    // Update transaction fields
    widget.transaction
      ..studentId = _student?.studentIdNumber ?? ''
      ..projectCode = _project?.projectCode ?? ''
      ..projectItemCode = _item?.projectItemCode ?? ''
      ..batchCode = _selectedBatch?.batchCode ?? ''
      ..sellUnitCode = _selectedSellUnit?.sellUnitCode ?? ''
      ..sellUnitNameSnapshot = _selectedSellUnit?.unitName ?? 'SERVICE'
      ..quantitySold = quantity
      ..unitSellingPrice =
          _selectedSellUnit?.sellingPrice ?? _activeServicePrice?.amount ?? 0
      ..totalAmount = derivedExpected
      ..amountPaid = paidAmount
      ..arrears = arrears.toDouble()
      ..paymentMethod = _paymentMethodType
      ..paymentMethodCode = _paymentMethodType
      ..referenceNumber = _pmReferenceCtrl.text.trim().isEmpty
          ? null
          : _pmReferenceCtrl.text.trim()
      ..provider = _provider
      ..phoneNumber =
          _pmPhoneCtrl.text.trim().isEmpty ? null : _pmPhoneCtrl.text.trim()
      ..accountNumber = _pmAccountNumberCtrl.text.trim().isEmpty
          ? null
          : _pmAccountNumberCtrl.text.trim()
      ..accountName = _pmAccountNameCtrl.text.trim().isEmpty
          ? null
          : _pmAccountNameCtrl.text.trim()
      ..paymentDatetransacted = _paymentDate
      ..operationType = 'update'
      ..lastModified = DateTime.now();

    await widget.transaction.save();

    _snack('Transaction updated successfully');
    Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Update Transaction')),
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
                  _projectDropdown(),
                  const SizedBox(height: 12),
                  _itemDropdown(),
                  if (_item?.itemType == 'service') _servicePrice(),
                  if (_item?.itemType == 'goods') ..._goodsSection(),
                  const SizedBox(height: 20),
                  Text(
                      'Total Amount Paid: ${_amountPaid.toStringAsFixed(2)} $_currency',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _paymentDetailsSection(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _saveUpdatedTransaction,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _studentTile() {
    return ListTile(
      title: Text(_student == null
          ? 'Select Student'
          : '${_student!.name} ${_student!.surname}'),
      subtitle: _student == null ? null : Text(_student!.class_ ?? ''),
      trailing: const Icon(Icons.search),
      onTap: _pickStudentDialog,
    );
  }

  Widget _projectDropdown() {
    return DropdownButtonFormField<Project>(
      value: _project,
      decoration: const InputDecoration(labelText: 'Project'),
      items: _projects
          .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
          .toList(),
      onChanged: (v) => setState(() {
        _project = v;
        _item = null;
        _selectedBatch = null;
        _selectedSellUnit = null;
        _quantity = 1;
        _recalculateTotals();
      }),
    );
  }

  Widget _itemDropdown() {
    final filteredItems = _items
        .where((i) =>
            i.projectCode == _project?.projectCode && (i.active ?? false))
        .toList();

    return DropdownButtonFormField<ProjectItem>(
      value: _item,
      decoration: const InputDecoration(labelText: 'Item / Service'),
      items: filteredItems
          .map((i) => DropdownMenuItem(value: i, child: Text(i.name ?? '')))
          .toList(),
      onChanged: (v) => setState(() {
        _item = v;
        _selectedBatch = null;
        _selectedSellUnit = null;
        _quantity = 1;
        _recalculateTotals();
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

  List<Widget> _goodsSection() {
    return [
      DropdownButtonFormField<ProductBatch>(
        value: _selectedBatch,
        decoration: const InputDecoration(labelText: 'Batch'),
        items: _availableBatches
            .map((b) => DropdownMenuItem(
                  value: b,
                  child: Text(
                      '${b.reference} (${b.remainingBaseUnits} ${b.baseUnit})'),
                ))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedBatch = v;
          _selectedSellUnit = null;
          _quantity = 1;
          _recalculateTotals();
        }),
      ),
      DropdownButtonFormField<BatchSellUnit>(
        value: _selectedSellUnit,
        decoration: const InputDecoration(labelText: 'Sell Unit'),
        items: _sellUnits
            .map((u) => DropdownMenuItem(
                value: u, child: Text('${u.unitName} — ${u.sellingPrice}')))
            .toList(),
        onChanged: (v) => setState(() {
          _selectedSellUnit = v;
          _quantity = 1;
          _recalculateTotals();
        }),
      ),
      TextFormField(
        controller: _quantityCtrl,
        keyboardType: TextInputType.number,
        decoration:
            InputDecoration(labelText: 'Quantity (max $_maxSellableQuantity)'),
        validator: (v) {
          final q = int.tryParse(v ?? '') ?? 0;
          if (q <= 0) return 'Invalid quantity';
          if (q > _maxSellableQuantity)
            return 'Only $_maxSellableQuantity available';
          return null;
        },
        onChanged: (v) {
          final parsed = int.tryParse(v) ?? 1;
          final clamped = parsed.clamp(1, _maxSellableQuantity);
          if (parsed != clamped) _quantityCtrl.text = clamped.toString();
          setState(() {
            _quantity = clamped;
            _recalculateTotals();
          });
        },
      ),
    ];
  }

  Widget _paymentDetailsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Details',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
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
              decoration:
                  InputDecoration(labelText: 'Amount Received ($_currency)'),
              validator: (v) {
                final val = double.tryParse(v ?? '') ?? 0;
                if (val < _amountPaid)
                  return 'Cannot be less than total entered ($_amountPaid)';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (_paymentMethodType != 'cash')
              TextFormField(
                  controller: _pmReferenceCtrl,
                  decoration: const InputDecoration(labelText: 'Reference')),
            if (_paymentMethodType == 'mobile_money') ...[
              const SizedBox(height: 8),
              TextFormField(
                  controller: _pmPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number')),
              const SizedBox(height: 8),
              TextFormField(
                  decoration: const InputDecoration(labelText: 'Provider'),
                  onChanged: (v) => _provider = v),
            ],
            if (_paymentMethodType == 'bank_transfer') ...[
              const SizedBox(height: 8),
              TextFormField(
                  controller: _pmAccountNumberCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Account Number')),
              const SizedBox(height: 8),
              TextFormField(
                  controller: _pmAccountNameCtrl,
                  decoration: const InputDecoration(labelText: 'Account Name')),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _paymentDateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                  labelText: 'Payment Date',
                  suffixIcon: Icon(Icons.calendar_today)),
              onTap: _pickDate,
            ),
          ],
        ),
      ),
    );
  }

  void _pickStudentDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Student'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView(
            children: _students
                .map((s) => ListTile(
                      title: Text('${s.name} ${s.surname}'),
                      subtitle: Text(s.class_ ?? ''),
                      onTap: () {
                        setState(() => _student = s);
                        Navigator.pop(context);
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountPaidCtrl.dispose();
    _quantityCtrl.dispose();
    _pmAmountCtrl.dispose();
    _pmReferenceCtrl.dispose();
    _pmPhoneCtrl.dispose();
    _pmAccountNumberCtrl.dispose();
    _pmAccountNameCtrl.dispose();
    _paymentDateCtrl.dispose();
    super.dispose();
  }
}
