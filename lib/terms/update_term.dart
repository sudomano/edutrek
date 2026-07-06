import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class UpdateTermScreen extends StatefulWidget {
  final int index; // Index of the term to update

  const UpdateTermScreen({Key? key, required this.index}) : super(key: key);

  @override
  _UpdateTermScreenState createState() => _UpdateTermScreenState();
}

class _UpdateTermScreenState extends State<UpdateTermScreen> {
  final _formKey = GlobalKey<FormState>();
  final _termNameController = TextEditingController();
  final _termIdController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _statusController = TextEditingController();
  bool _isActive = false;
  bool _isSubmitting = false;
  Terms? _currentTerm;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadTerm();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = stringToDeviceRole(prefs.getString('device_role') ?? '');
      _hostIp = prefs.getString('host_ip');
    });
  }

  DeviceRole? stringToDeviceRole(String role) {
    switch (role) {
      case 'client':
        return DeviceRole.client;
      case 'host':
        return DeviceRole.host;
      default:
        return null;
    }
  }

  void _loadTerm() {
    final Box<Terms> box = Hive.box<Terms>('terms');

    if (widget.index < 0 || widget.index >= box.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid term index')),
        );
      });
      return;
    }

    _currentTerm = box.getAt(widget.index);

    if (_currentTerm == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term not found')),
        );
      });
      return;
    }

    _termIdController.text = _currentTerm!.termId;
    _termNameController.text = _currentTerm!.termName;
    _startDateController.text =
        _currentTerm!.startDate.toLocal().toString().split(' ')[0];
    _endDateController.text =
        _currentTerm!.endDate?.toLocal().toString().split(' ')[0] ?? '';
    _statusController.text = _currentTerm!.status;
    _isActive = _currentTerm!.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final isDeleted = _currentTerm?.isDeleted ?? false;
    final isHost = _role == DeviceRole.host;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Term'),
        backgroundColor: const Color.fromARGB(255, 38, 140, 191),
        foregroundColor: Colors.white,
        elevation: 4.0,
        actions: [
          // ✅ Show deletion status
          if (isDeleted)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'DELETED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: CenteredFormContainer(
        title: 'Update Term',
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ✅ Status indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDeleted ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color:
                        isDeleted ? Colors.red.shade300 : Colors.green.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDeleted ? Icons.delete_outline : Icons.check_circle,
                      color: isDeleted ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isDeleted
                            ? '⚠️ This term is deleted. Update to restore it.'
                            : '✅ Term is active',
                        style: TextStyle(
                          color: isDeleted
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _buildTextField('Term ID', _termIdController, enabled: false),
              const SizedBox(height: 20),
              _buildTextField('Term Name', _termNameController),
              const SizedBox(height: 20),
              _buildDatePicker('Start Date', _startDateController),
              const SizedBox(height: 20),
              _buildDatePicker('End Date', _endDateController),
              const SizedBox(height: 20),
              _buildTextField('Status', _statusController, enabled: false),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: !isDeleted
                    ? (bool value) {
                        final box = Hive.box<Terms>('terms');

                        final hasActiveTerm = box.values.any(
                          (term) =>
                              term.isActive &&
                              term.termId != _currentTerm!.termId &&
                              !(term.isDeleted ?? false),
                        );

                        if (hasActiveTerm && value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Only one term can be active at a time')),
                          );
                          return;
                        }

                        setState(() {
                          _isActive = value;
                          _statusController.text =
                              _isActive ? 'Opened' : 'Closed';
                        });
                      }
                    : null,
              ),
              const SizedBox(height: 20),

              // ✅ Update button with loading state
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _updateTerm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 38, 140, 191),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Update Term',
                          style: TextStyle(fontSize: 16)),
                ),
              ),

              // ✅ Restore button for deleted terms
              if (isDeleted)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isSubmitting ? null : _restoreTerm,
                      icon: const Icon(Icons.restore, color: Colors.green),
                      label: const Text(
                        'Restore This Term',
                        style: TextStyle(color: Colors.green),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool enabled = true}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $label';
        }
        return null;
      },
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        suffixIcon: IconButton(
          icon: const Icon(Icons.calendar_today),
          onPressed: () => _selectDate(context, controller),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      readOnly: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select $label';
        }
        return null;
      },
    );
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: controller.text.isNotEmpty
          ? DateTime.parse(controller.text)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (selectedDate != null) {
      controller.text = selectedDate.toLocal().toString().split(' ')[0];
    }
  }

  Future<void> _updateTerm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final box = Hive.box<Terms>('terms');
      final termName = _termNameController.text.trim().toLowerCase();

      // ✅ Check for duplicate terms (excluding deleted and current)
      final existingTerm = box.values.firstWhere(
        (t) =>
            t.termName.toLowerCase() == termName &&
            t.termId != _currentTerm!.termId &&
            !(t.isDeleted ?? false),
        orElse: () => Terms(
            termId: '',
            startDate: DateTime(1970),
            endDate: DateTime(1970),
            termName: '',
            isActive: false,
            status: ''),
      );

      if (existingTerm.termName.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Term with this name already exists')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      DateTime startDate = DateTime.parse(_startDateController.text);
      DateTime endDate = DateTime.parse(_endDateController.text);

      // ✅ Track modified fields
      List<String> modifiedFields = _currentTerm?.modifiedFields ?? [];

      if (_currentTerm?.termName.toLowerCase() != termName &&
          !modifiedFields.contains('termName')) {
        modifiedFields.add('termName');
      }
      if (_currentTerm?.startDate != startDate &&
          !modifiedFields.contains('startDate')) {
        modifiedFields.add('startDate');
      }
      if (_currentTerm?.endDate != endDate &&
          !modifiedFields.contains('endDate')) {
        modifiedFields.add('endDate');
      }
      if (_currentTerm?.isActive != _isActive &&
          !modifiedFields.contains('isActive')) {
        modifiedFields.add('isActive');
      }
      if (_currentTerm?.status != _statusController.text &&
          !modifiedFields.contains('status')) {
        modifiedFields.add('status');
      }

      // ✅ If term was deleted, restore it on update
      final isDeleted = _currentTerm?.isDeleted ?? false;

      final updatedTerm = Terms(
        id: _currentTerm!.id,
        termId: _currentTerm!.termId,
        termName: _termNameController.text.trim(),
        startDate: startDate,
        endDate: endDate,
        isActive: _isActive,
        status: _statusController.text,
        operationType: 'update',
        syncStatus: false,
        lastModified: DateTime.now(),
        modifiedFields: modifiedFields,
        // ✅ If was deleted, restore on update
        isDeleted: false,
        deletedSyncStatus: false,
      );

      box.putAt(widget.index, updatedTerm);

      // ✅ Send update to server if client
      if (_role == DeviceRole.client && _hostIp != null) {
        await _sendUpdateToServer(updatedTerm);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isDeleted
              ? '✅ Term restored and updated successfully'
              : '✅ Term Updated Successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating term: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendUpdateToServer(Terms term) async {
    if (_hostIp == null) return;

    try {
      final termJson = {
        'termId': term.termId,
        'termName': term.termName,
        'startDate': term.startDate.toIso8601String(),
        'endDate': term.endDate?.toIso8601String(),
        'isActive': term.isActive,
        'status': term.status,
        'operationType': 'update',
        'syncStatus': 0,
        'lastModified': DateTime.now().toIso8601String(),
        'isDeleted': term.isDeleted ?? false,
        'deletedSyncStatus': term.deletedSyncStatus ?? false,
        'modifiedFields': term.modifiedFields,
      };

      final response = await http.put(
        Uri.parse('http://$_hostIp:8080/api/terms'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(termJson),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        term.syncStatus = true;
        term.operationType = 'none';
        await term.save();
      }
    } catch (e) {
      print('Error sending update to server: $e');
    }
  }

  // ✅ Restore term
  Future<void> _restoreTerm() async {
    setState(() => _isSubmitting = true);

    try {
      _currentTerm!.restoreDeleted();
      await _currentTerm!.save();

      if (_role == DeviceRole.client && _hostIp != null) {
        final response = await http.post(
          Uri.parse('http://$_hostIp:8080/api/terms'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'action': 'restore',
            'termId': _currentTerm!.termId,
          }),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          _currentTerm!.syncStatus = true;
          _currentTerm!.deletedSyncStatus = true;
          await _currentTerm!.save();
        }
      }

      // Reload the term
      _loadTerm();
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Term restored successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring term: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _termNameController.dispose();
    _termIdController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _statusController.dispose();
    super.dispose();
  }
}
