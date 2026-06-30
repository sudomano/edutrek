import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:zitf_system/database/network_utils/network_settings.dart';
import 'package:zitf_system/screens/network_settings/developer_auth_dialog.dart';
import 'package:zitf_system/services/network_services/network_settings_services.dart';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  late NetworkSettingsService _service;
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _ipController = TextEditingController();
  final _gatewayController = TextEditingController();
  final _deviceMacController = TextEditingController();
  final _networkMacController = TextEditingController();
  final _networkNameController = TextEditingController();

  bool _isLoading = true;
  String? _editingId;
  List<NetworkSettings> _allSettings = [];
  NetworkSettings? _activeSetting;

  @override
  void initState() {
    super.initState();
    _initService();
  }

  Future<void> _initService() async {
    _service = NetworkSettingsService();
    await _service.init();
    await _loadData();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadData() async {
    _allSettings = _service.getAllSettings();
    _activeSetting = _service.getActiveSetting();
  }

  bool get _canCreateNewSetting {
    // Can create if NO settings exist OR there is no active setting
    return _allSettings.isEmpty || _activeSetting == null;
  }

  String? get _createDisabledReason {
    if (_allSettings.isNotEmpty && _activeSetting != null) {
      return 'Cannot create new setting when an active network exists.\n\n'
          'Please deactivate the current active setting first, or delete existing settings.';
    }
    return null;
  }

  void _resetForm() {
    _idController.clear();
    _ipController.clear();
    _gatewayController.clear();
    _deviceMacController.clear();
    _networkMacController.clear();
    _networkNameController.clear();
    setState(() {
      _editingId = null;
    });
  }

  void _populateForm(NetworkSettings setting) {
    _idController.text = setting.id.toString();
    _ipController.text = setting.hostIpAddress.toString();
    _gatewayController.text = setting.gateway.toString();
    _deviceMacController.text = setting.deviceMacAddress.toString();
    _networkMacController.text = setting.networkDeviceMacAddress.toString();
    _networkNameController.text = setting.networkName.toString();
    setState(() {
      _editingId = setting.id;
    });
  }

  Future<void> _saveSetting() async {
    if (!_formKey.currentState!.validate()) return;

    final setting = NetworkSettings(
      id: _editingId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      hostIpAddress: _ipController.text.trim(),
      gateway: _gatewayController.text.trim(),
      deviceMacAddress: _deviceMacController.text.trim(),
      networkDeviceMacAddress: _networkMacController.text.trim(),
      networkName: _networkNameController.text.trim(),
      lastUpdated: DateTime.now(),
      isActive: _editingId == null
          ? false
          : (_allSettings.firstWhere((s) => s.id == _editingId).isActive),
    );

    if (_editingId != null) {
      // Update - requires authentication
      final authenticated = await DeveloperAuthDialog.authenticate(context);
      if (!authenticated) return;
      await _service.updateSetting(setting);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting updated successfully')),
      );
    } else {
      // Create - check if allowed
      if (!_canCreateNewSetting) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_createDisabledReason!),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      final authenticated = await DeveloperAuthDialog.authenticate(context);
      if (!authenticated) return;
      await _service.createSetting(setting);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting created successfully')),
      );
    }

    await _loadData();
    _resetForm();
    setState(() {});
  }

  Future<void> _deleteSetting(String id) async {
    final authenticated = await DeveloperAuthDialog.authenticate(context);
    if (!authenticated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Setting'),
        content:
            const Text('Are you sure you want to delete this network setting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.deleteSetting(id);
      await _loadData();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting deleted successfully')),
      );
    }
  }

  Future<void> _setActiveSetting(String id) async {
    final authenticated = await DeveloperAuthDialog.authenticate(context);
    if (!authenticated) return;

    await _service.setActiveSetting(id);
    await _loadData();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Active setting updated')),
    );
  }

  Future<void> _deactivateActiveSetting() async {
    if (_activeSetting == null) return;

    final authenticated = await DeveloperAuthDialog.authenticate(context);
    if (!authenticated) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Network'),
        content: const Text(
            'Deactivating this network will require you to set a new active network.\n\n'
            'Are you sure you want to proceed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Deactivate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.setActiveSetting('');
      await _loadData();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Network deactivated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Settings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadData();
              setState(() {});
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 600;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Active Network Banner
                        if (_activeSetting != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.wifi,
                                        color: Colors.green.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'ACTIVE NETWORK',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: _deactivateActiveSetting,
                                      icon: Icon(Icons.power_settings_new,
                                          size: 16, color: Colors.red.shade700),
                                      label: Text(
                                        'Deactivate',
                                        style: TextStyle(
                                            color: Colors.red.shade700),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _activeSetting!.networkName.toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'IP: ${_activeSetting!.hostIpAddress} | Gateway: ${_activeSetting!.gateway}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),

                        // Create New Setting Section (with conditional enable/disable)
                        Card(
                          elevation: 4,
                          color: _canCreateNewSetting
                              ? null
                              : Colors.grey.shade100,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _editingId != null
                                            ? 'Edit Setting'
                                            : 'Add New Setting',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (!_canCreateNewSetting &&
                                        _editingId == null)
                                      Tooltip(
                                        message: _createDisabledReason,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.lock,
                                                  size: 14,
                                                  color:
                                                      Colors.orange.shade700),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Creation Locked',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.orange.shade700,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (isSmallScreen) ...[
                                        _buildTextField(
                                            'IP Address', _ipController,
                                            icon: Icons.near_me,
                                            isRequired: true),
                                        const SizedBox(height: 12),
                                        _buildTextField(
                                            'Gateway', _gatewayController,
                                            icon: Icons.router,
                                            isRequired: true),
                                        const SizedBox(height: 12),
                                        _buildTextField('Device MAC Address',
                                            _deviceMacController,
                                            icon: Icons.computer,
                                            isRequired: true),
                                        const SizedBox(height: 12),
                                        _buildTextField('Network Device MAC',
                                            _networkMacController,
                                            icon: Icons.wifi, isRequired: true),
                                        const SizedBox(height: 12),
                                        _buildTextField('Network Name',
                                            _networkNameController,
                                            icon: Icons.network_check,
                                            isRequired: true),
                                      ] else ...[
                                        Row(
                                          children: [
                                            Expanded(
                                                child: _buildTextField(
                                                    'IP Address', _ipController,
                                                    icon: Icons.near_me,
                                                    isRequired: true)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: _buildTextField(
                                                    'Gateway',
                                                    _gatewayController,
                                                    icon: Icons.router,
                                                    isRequired: true)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                                child: _buildTextField(
                                                    'Device MAC Address',
                                                    _deviceMacController,
                                                    icon: Icons.computer,
                                                    isRequired: true)),
                                            const SizedBox(width: 12),
                                            Expanded(
                                                child: _buildTextField(
                                                    'Network Device MAC',
                                                    _networkMacController,
                                                    icon: Icons.wifi,
                                                    isRequired: true)),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildTextField('Network Name',
                                            _networkNameController,
                                            icon: Icons.network_check,
                                            isRequired: true),
                                      ],
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: (_editingId != null ||
                                                      _canCreateNewSetting)
                                                  ? _saveSetting
                                                  : null,
                                              icon: Icon(_editingId != null
                                                  ? Icons.update
                                                  : Icons.save),
                                              label: Text(_editingId != null
                                                  ? 'Update'
                                                  : 'Create'),
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                              ),
                                            ),
                                          ),
                                          if (_editingId != null) ...[
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: _resetForm,
                                                icon: const Icon(Icons.cancel),
                                                label: const Text('Cancel'),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (!_canCreateNewSetting &&
                                          _editingId == null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            _createDisabledReason!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Settings List
                        const Text(
                          'Saved Network Settings',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        ValueListenableBuilder(
                          valueListenable:
                              Hive.box<NetworkSettings>('network_settings_box')
                                  .listenable(),
                          builder: (context, box, _) {
                            final settings = _service.getAllSettings();
                            if (settings.isEmpty) {
                              return const Card(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                        'No network settings found. Add one above.'),
                                  ),
                                ),
                              );
                            }

                            return ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: settings.length,
                              itemBuilder: (context, index) {
                                final setting = settings[index];
                                final isActive = setting.isActive;

                                return Card(
                                  elevation: 2,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: isActive ? Colors.green.shade50 : null,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  if (isActive)
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Text(
                                                        'ACTIVE',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    setting.networkName
                                                        .toString(),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.edit,
                                                      size: 20),
                                                  onPressed: () =>
                                                      _populateForm(setting),
                                                  tooltip: 'Edit',
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.delete,
                                                      size: 20,
                                                      color: Colors.red),
                                                  onPressed: () =>
                                                      _deleteSetting(setting.id
                                                          .toString()),
                                                  tooltip: 'Delete',
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _buildInfoRow('IP Address',
                                            setting.hostIpAddress.toString()),
                                        _buildInfoRow('Gateway',
                                            setting.gateway.toString()),
                                        _buildInfoRow(
                                            'Device MAC',
                                            setting.deviceMacAddress
                                                .toString()),
                                        _buildInfoRow(
                                            'Network MAC',
                                            setting.networkDeviceMacAddress
                                                .toString()),
                                        _buildInfoRow(
                                            'Last Updated',
                                            _formatDateFromString(setting
                                                .lastUpdated
                                                .toString())),
                                        if (!isActive)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 8),
                                            child: Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton.icon(
                                                onPressed: () =>
                                                    _setActiveSetting(
                                                        setting.id.toString()),
                                                icon: const Icon(
                                                    Icons.check_circle,
                                                    size: 16),
                                                label:
                                                    const Text('Set as Active'),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  String _formatDateFromString(dynamic dateValue) {
    if (dateValue == null) return 'Never';

    try {
      DateTime dateTime;
      if (dateValue is DateTime) {
        dateTime = dateValue;
      } else if (dateValue is String) {
        dateTime = DateTime.parse(dateValue);
      } else {
        return 'Invalid date';
      }
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {IconData? icon, bool isRequired = false}) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
