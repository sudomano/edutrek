// screens/term_switcher.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:zitf_system/database/terms.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/lan_sync_services/sync_service.dart';
import 'package:zitf_system/reusable_codes/custom_app_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class TermSwitcher extends StatefulWidget {
  const TermSwitcher({super.key});

  @override
  _TermSwitcherState createState() => _TermSwitcherState();
}

class _TermSwitcherState extends State<TermSwitcher> {
  final TextEditingController _searchController = TextEditingController();
  late Box<Terms> termsBox;
  List<Terms> _termsList = [];
  List<Terms> _filteredTermsList = [];
  String? _selectedTermId;
  Terms? _currentTerm;
  bool _isLoading = false;
  bool _isSyncing = false;
  DeviceRole? _role;
  String? _hostIp;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);

    try {
      // Get device role and host IP
      _role = await getDeviceRole();
      final prefs = await SharedPreferences.getInstance();
      _hostIp = prefs.getString('host_ip');

      // Open Hive box
      termsBox = await Hive.openBox<Terms>('terms');

      // Auto-sync if client
      if (_role == DeviceRole.client && _hostIp != null) {
        await _autoSyncTerms();
      }

      // Load terms
      _fetchTerms();
      _loadCurrentTerm();
    } catch (e) {
      print('❌ TermSwitcher initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading terms: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // AUTO-SYNC: Called during initialization
  Future<void> _autoSyncTerms() async {
    if (_hostIp == null || _hostIp!.isEmpty) {
      print('⚠️ Host IP not configured for term sync');
      return;
    }

    setState(() => _isSyncing = true);

    try {
      print('🔄 Auto-syncing terms from host: $_hostIp');

      final syncService = SyncService();
      final success = await syncService.syncTermsOnly(_hostIp!);

      if (success && mounted) {
        print('✅ Terms auto-synced successfully');

        // FIX 1: Refresh the box data instead of using reload()
        await _refreshTermsBox();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Terms synced from host'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (!success && mounted) {
        print('⚠️ Terms auto-sync failed - using cached data');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Using cached terms (sync failed)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('❌ Auto-sync error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Sync error: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  // FIX 1: Refresh terms box (replaces reload())
  Future<void> _refreshTermsBox() async {
    try {
      // Close and reopen the box to refresh data
      await termsBox.close();
      termsBox = await Hive.openBox<Terms>('terms');
      print('✅ Terms box refreshed');
    } catch (e) {
      print('❌ Error refreshing terms box: $e');
    }
  }

  void _fetchTerms() {
    setState(() {
      _termsList = termsBox.values.toList();
      _filteredTermsList = _termsList;

      // Auto-select first term if available and no selection exists
      if (_termsList.isNotEmpty && _selectedTermId == null) {
        _autoSelectFirstTerm();
      }
    });
  }

  // AUTO-SELECT: Selects the first term or the one matching globalTermId
  void _autoSelectFirstTerm() {
    if (_termsList.isEmpty) return;

    // Try to find term matching globalTermId first
    Terms? matchingTerm;
    if (globalTermId != null) {
      matchingTerm = _termsList.firstWhere(
        (term) => term.termId == globalTermId,
        orElse: () => _termsList.first,
      );
    } else {
      // If no globalTermId, select the first term
      matchingTerm = _termsList.first;
    }

    if (matchingTerm != null) {
      print(
          '🔄 Auto-selecting term: ${matchingTerm.termName} (ID: ${matchingTerm.termId})');
      _selectTerm(matchingTerm, autoSwitch: true);
    }
  }

  void _filterTerms(String searchQuery) {
    setState(() {
      _filteredTermsList = _termsList
          .where((term) =>
              term.termName.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    });
  }

  void _loadCurrentTerm() {
    print("📋 Loading current term... Global Term ID: $globalTermId");

    if (globalTermId != null && _termsList.isNotEmpty) {
      setState(() {
        final matchingTerms =
            _termsList.where((term) => term.termId == globalTermId).toList();
        print("🔍 Matching terms found: ${matchingTerms.length}");

        if (matchingTerms.isNotEmpty) {
          _currentTerm = matchingTerms.first;
          _selectedTermId = globalTermId;
          print('✅ Current term loaded: ${_currentTerm!.termName}');
        } else {
          // If globalTermId doesn't match any term, auto-select first
          _currentTerm = _termsList.first;
          _selectedTermId = _currentTerm!.termId;
          // Update globalTermId to match
          globalTermId = _selectedTermId;
          print('🔄 Global term ID updated to: $globalTermId');
        }
      });
    } else if (_termsList.isNotEmpty) {
      // No globalTermId set, select first term
      setState(() {
        _currentTerm = _termsList.first;
        _selectedTermId = _currentTerm!.termId;
        globalTermId = _selectedTermId;
        print('🔄 Auto-set global term ID to: $globalTermId');
      });
    }
  }

  // SELECT TERM: Updates selection and optionally auto-switches
  void _selectTerm(Terms term, {bool autoSwitch = false}) {
    setState(() {
      _selectedTermId = term.termId;
      _currentTerm = term;

      // Update global term ID
      globalTermId = _selectedTermId;

      print('📌 Term selected: ${term.termName} (ID: $globalTermId)');

      if (autoSwitch) {
        print('🔄 AUTO-SWITCH activated for term: ${term.termName}');
        _autoSwitchTerm(term);
      }
    });
  }

  // AUTO-SWITCH: Automatically switches to the selected term
  void _autoSwitchTerm(Terms term) {
    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Auto-switched to: ${term.termName}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    // Save last selected term ID for next session
    _saveLastTermId(term.termId);
  }

  // FIX 2: CONFIRM SELECTION - Handles the confirm button press
  void _confirmSelection() {
    if (_selectedTermId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No term selected'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Update global term ID
    globalTermId = _selectedTermId;

    // Save for persistence
    _saveLastTermId(_selectedTermId);

    // Update current term
    _loadCurrentTerm();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ Term switched to: ${_currentTerm?.termName ?? _selectedTermId}'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );

    print('📌 Term confirmed: $globalTermId');

    // Optional: Navigate back with result
    // Navigator.pop(context, _selectedTermId);
  }

  // Save last selected term for persistence
  Future<void> _saveLastTermId(String? termId) async {
    if (termId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_term_id', termId);
      print('💾 Last term ID saved: $termId');
    } catch (e) {
      print('⚠️ Failed to save last term ID: $e');
    }
  }

  // MANUAL SYNC: User-triggered sync with refresh
  Future<void> _manualSync() async {
    if (_role != DeviceRole.client) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ℹ️ Host mode - using local data'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    if (_hostIp == null || _hostIp!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Host IP not configured'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final syncService = SyncService();
      final success = await syncService.syncTermsOnly(_hostIp!);

      if (success) {
        // FIX 1: Refresh the box data
        await _refreshTermsBox();

        // Refresh the list
        _fetchTerms();
        _loadCurrentTerm();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Terms refreshed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Sync failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Switch Terms',
        actions: [
          // Sync button for clients
          if (_role == DeviceRole.client)
            IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.sync),
              onPressed: _isSyncing ? null : _manualSync,
              tooltip: 'Sync terms from host',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE3F2FD),
                    Color.fromARGB(255, 248, 248, 248),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      _buildCurrentTermInfo(),
                      const SizedBox(height: 20),
                      _buildSearchBar(),
                      const SizedBox(height: 20),
                      Expanded(
                        child: _buildTermsList(),
                      ),
                      const SizedBox(height: 20),
                      _buildConfirmButton(),
                      if (_role == DeviceRole.client) _buildSyncStatus(),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildCurrentTermInfo() {
    if (_currentTerm == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Column(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No current term selected.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Please select a term from the list below.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              const Text(
                'Current Term:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '📚 ${_currentTerm!.termName}',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            '📅 ${_currentTerm!.startDate.toLocal().toString().split(' ')[0]} → ${_currentTerm!.endDate?.toLocal().toString().split(' ')[0] ?? 'N/A'}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            '🆔 ${_currentTerm!.termId}',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search terms...',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      onChanged: _filterTerms,
    );
  }

  Widget _buildTermsList() {
    if (_isSyncing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Syncing terms from host...'),
          ],
        ),
      );
    }

    if (_filteredTermsList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No terms found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _role == DeviceRole.client
                  ? 'Tap sync button to fetch from host'
                  : 'No terms available',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _filteredTermsList.length,
      itemBuilder: (context, index) {
        final term = _filteredTermsList[index];
        final isSelected = _selectedTermId == term.termId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isSelected
                ? BorderSide(color: Colors.green.shade400, width: 2)
                : BorderSide.none,
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected ? Colors.green : Colors.blue.shade100,
              child: Icon(
                isSelected ? Icons.check : Icons.school,
                color: isSelected ? Colors.white : Colors.blue.shade700,
                size: 20,
              ),
            ),
            title: Text(
              term.termName,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.green.shade800 : Colors.black87,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Start: ${term.startDate.toLocal().toString().split(' ')[0]}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'End: ${term.endDate?.toLocal().toString().split(' ')[0] ?? 'Active'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: isSelected
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: Text(
                      'Selected',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () => _selectTerm(term, autoSwitch: false),
          ),
        );
      },
    );
  }

  Widget _buildConfirmButton() {
    return Column(
      children: [
        if (_selectedTermId != null && _currentTerm != null)
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Switching to: ${_currentTerm!.termName}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            // FIX 2: Use _confirmSelection method
            onPressed: _selectedTermId != null ? _confirmSelection : null,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: _selectedTermId != null
                  ? const Color.fromARGB(255, 38, 140, 191)
                  : Colors.grey.shade400,
              elevation: 3,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _selectedTermId != null
                  ? 'Switch to ${_currentTerm?.termName ?? 'Selected'} Term'
                  : 'Select a Term First',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncStatus() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _isSyncing ? Icons.sync : Icons.check_circle,
            size: 16,
            color: _isSyncing ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            _isSyncing ? 'Syncing...' : 'Terms synced with host',
            style: TextStyle(
              fontSize: 12,
              color: _isSyncing ? Colors.orange : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
