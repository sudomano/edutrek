import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zitf_system/auth/auth_cp/platform_auth_services.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:zitf_system/global%20files/global_term_id.dart';
import 'package:zitf_system/lan_sync_services/sync_service.dart';
import 'package:zitf_system/main.dart';

import 'package:zitf_system/reusable_codes/centered_forms/centered_form.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Track focus nodes as nullable, initialized in initState
  FocusNode? _usernameFocusNode;
  FocusNode? _passwordFocusNode;
  FocusNode? _loginButtonFocusNode;
  FocusNode? _refreshButtonFocusNode;
  FocusNode? _forgotButtonFocusNode;

  // Track if we've already set up keyboard handling
  bool _keyboardHandlingSetup = false;

  late final PlatformAuthService _authService;
  DeviceRole? _role;

  @override
  void initState() {
    super.initState();
    _authService = PlatformAuthService();

    // Initialize focus nodes immediately
    _usernameFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
    _loginButtonFocusNode = FocusNode();
    _refreshButtonFocusNode = FocusNode();
    _forgotButtonFocusNode = FocusNode();

    // Optional background sync (safe on web – no-op)
    _authService.syncUsersFromHostIfClient();
    _initializeRole();
  }

  Future<void> _initializeRole() async {
    final role = await getDeviceRole();
    setState(() {
      _role = role;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Setup keyboard handling after dependencies are available
    if (!_keyboardHandlingSetup && mounted) {
      _setupKeyboardHandling();
      _keyboardHandlingSetup = true;
    }
  }

  void _setupKeyboardHandling() {
    // Check if running on Windows
    if (Theme.of(context).platform == TargetPlatform.windows) {
      // Add a delay to ensure the widget tree is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _usernameFocusNode != null) {
          // Auto-focus the username field initially if no field is focused
          if (!_usernameFocusNode!.hasFocus &&
              !(_passwordFocusNode?.hasFocus ?? false) &&
              !(_loginButtonFocusNode?.hasFocus ?? false) &&
              !(_refreshButtonFocusNode?.hasFocus ?? false) &&
              !(_forgotButtonFocusNode?.hasFocus ?? false)) {
            FocusScope.of(context).requestFocus(_usernameFocusNode);
          }
        }
      });
    }
  }

  // Get the next focusable node in the tab order
  FocusNode? _getNextFocusNode(FocusNode current) {
    if (current == _usernameFocusNode) return _passwordFocusNode;
    if (current == _passwordFocusNode) return _loginButtonFocusNode;
    if (current == _loginButtonFocusNode) return _refreshButtonFocusNode;
    if (current == _refreshButtonFocusNode) return _forgotButtonFocusNode;
    if (current == _forgotButtonFocusNode) return _usernameFocusNode;
    return _usernameFocusNode;
  }

  // Get the previous focusable node in the tab order (for Shift+Tab)
  FocusNode? _getPreviousFocusNode(FocusNode current) {
    if (current == _usernameFocusNode) return _forgotButtonFocusNode;
    if (current == _passwordFocusNode) return _usernameFocusNode;
    if (current == _loginButtonFocusNode) return _passwordFocusNode;
    if (current == _refreshButtonFocusNode) return _loginButtonFocusNode;
    if (current == _forgotButtonFocusNode) return _refreshButtonFocusNode;
    return _usernameFocusNode;
  }

  // Handle keyboard navigation (Tab, Shift+Tab, Enter)
  void _handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Handle Tab and Shift+Tab
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        final focusedNode = FocusScope.of(context).focusedChild;

        if (focusedNode != null && _usernameFocusNode != null) {
          // Check if Shift is pressed for reverse tabbing
          final isShiftPressed = event.isShiftPressed;

          if (isShiftPressed) {
            // Move to previous field (Shift+Tab)
            final previousNode = _getPreviousFocusNode(focusedNode);
            if (previousNode != null) {
              FocusScope.of(context).requestFocus(previousNode);
            }
          } else {
            // Move to next field (Tab)
            final nextNode = _getNextFocusNode(focusedNode);
            if (nextNode != null) {
              FocusScope.of(context).requestFocus(nextNode);
            }
          }
        }
      }

      // Handle Enter key
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final focusedNode = FocusScope.of(context).focusedChild;

        if (focusedNode == _usernameFocusNode) {
          // Move to password field
          if (_passwordFocusNode != null) {
            FocusScope.of(context).requestFocus(_passwordFocusNode);
          }
        } else if (focusedNode == _passwordFocusNode) {
          // Trigger login from password field
          _handleLogin();
        } else if (focusedNode == _loginButtonFocusNode) {
          // Trigger login from button
          _handleLogin();
        } else if (focusedNode == _refreshButtonFocusNode) {
          // Trigger refresh
          _forceSyncUsers();
        } else if (focusedNode == _forgotButtonFocusNode) {
          // Navigate to forgot password
          Navigator.pushNamed(context, '/forgot');
        }
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      print('\n');
      print('================ LOGIN DEBUG START ================');

      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      print('👤 Username Entered : $username');
      print('🔑 Password Length  : ${password.length}');

      /// DEVICE ROLE
      final role = await getDeviceRole();
      print('🖥 Device Role      : $role');

      /// HOST IP
      final prefs = await SharedPreferences.getInstance();
      final hostIp = prefs.getString('host_ip');
      print('🌐 Saved Host IP    : $hostIp');

      /// INTERNET CHECK
      try {
        final result = await InternetAddress.lookup(hostIp ?? '');
        if (result.isNotEmpty) {
          print('✅ Host reachable via DNS lookup');
        } else {
          print('❌ Host lookup returned empty');
        }
      } catch (e) {
        print('❌ Host unreachable: $e');
      }

      /// ⭐ PRIORITY SYNC: Sync users, terms, and classes
      if (role == DeviceRole.client) {
        print('🔄 CLIENT MODE -> performing full sync...');

        // Use the unified sync service
        final syncService = SyncService();
        final syncResult = await syncService.performFullSync();

        print('📊 Sync Results:');
        print('  - Success: ${syncResult.success}');
        print('  - Message: ${syncResult.message}');
        print('  - Details: ${syncResult.details}');

        // Check if critical sync (users) failed
        if (syncResult.details['users'] == false) {
          print('❌ User sync failed - aborting login');

          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ User sync failed. Please check connection to host.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          }
          return;
        }

        // ✅ NEW: Check if classes were synced
        if (syncResult.details['classes'] == true) {
          print('✅ Classes synced successfully');
        } else {
          print('⚠️ Classes sync failed or not needed');
        }

        // Terms sync result is informational
        if (syncResult.details['terms'] == false) {
          print('⚠️ Terms sync failed but continuing login');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '⚠️ Terms sync failed. Please refresh manually later.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }

        // ⭐ Check if term was auto-assigned
        if (syncResult.details['term_assigned'] == true) {
          print('✅ Global term ID auto-assigned: $globalTermId');
          if (mounted) {
            final activeTerm = await syncService.getActiveTerm();
            if (activeTerm != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Active term: ${activeTerm.termName}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          print('⚠️ No active term found - will auto-select in TermSwitcher');
          await loadLastTermId();
          if (globalTermId == null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('ℹ️ No active term - please select one later'),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // HOST MODE: Load existing term from preferences
        print('🖥 HOST MODE -> loading existing term...');
        await loadLastTermId();
        if (globalTermId != null) {
          print('📌 Loaded last term ID: $globalTermId');
        } else {
          // Try to auto-assign from local data
          final syncService = SyncService();
          final activeTerm = await syncService.getActiveTerm();
          if (activeTerm != null) {
            globalTermId = activeTerm.termId;
            await saveCurrentTermId(globalTermId!);
            print(
                '✅ Auto-assigned host term: $globalTermId (${activeTerm.termName})');
          }
        }
      }

      print('🔐 Attempting login...');

      final success = await _authService.login(
        username: username,
        password: password,
      );

      print('🎯 Login Result     : $success');

      print('================ LOGIN DEBUG END =================');
      print('\n');

      if (!mounted) return;

      setState(() => _isLoading = false);

      if (success) {
        print('✅ LOGIN SUCCESS');

        // ⭐ Final check: Ensure globalTermId is set
        if (globalTermId == null) {
          print('⚠️ No global term ID after login - setting default');
          final syncService = SyncService();
          final activeTerm = await syncService.getActiveTerm();
          if (activeTerm != null) {
            globalTermId = activeTerm.termId;
            await saveCurrentTermId(globalTermId!);
            print('✅ Default term assigned: $globalTermId');
          }
        }

        // ✅ NEW: Store user info with new fields in SharedPreferences for quick access
        final loggedInUser = await _authService.getLoggedInUser();
        if (loggedInUser != null) {
          await prefs.setString('logged_in_username', loggedInUser.username);
          await prefs.setString('logged_in_role', loggedInUser.role);
          await prefs.setStringList(
              'logged_in_assigned_classes', loggedInUser.assignedClasses ?? []);
          await prefs.setBool(
              'logged_in_is_active', loggedInUser.isActive ?? true);
          await prefs.setString('logged_in_phone', loggedInUser.phone);
          await prefs.setString('logged_in_email', loggedInUser.email ?? '');

          print('✅ User info stored in preferences');
          if (loggedInUser.isTeacher) {
            print(
                '📚 Teacher assigned classes: ${loggedInUser.assignedClasses}');
          }
        }

        Navigator.pushReplacementNamed(
          context,
          '/home',
        );
      } else {
        print('❌ LOGIN FAILED');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid login credentials',
            ),
          ),
        );
      }
    } catch (e, stack) {
      print('❌ LOGIN CRASH: $e');
      print(stack);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Login Error: $e',
            ),
          ),
        );
      }
    }
  }

  Future<void> _forceSyncUsers() async {
    final ok = await _authService.syncUsersFromHostIfClient(force: true);

    if (!mounted) return;

    // ✅ NEW: After sync, refresh the assigned classes in preferences
    if (ok) {
      final loggedInUser = await _authService.getLoggedInUser();
      if (loggedInUser != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(
            'logged_in_assigned_classes', loggedInUser.assignedClasses ?? []);
        await prefs.setBool(
            'logged_in_is_active', loggedInUser.isActive ?? true);

        print(
            '📚 Updated assigned classes after sync: ${loggedInUser.assignedClasses}');
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Users refreshed from host' : 'User sync failed',
        ),
        backgroundColor: ok ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode?.dispose();
    _passwordFocusNode?.dispose();
    _loginButtonFocusNode?.dispose();
    _refreshButtonFocusNode?.dispose();
    _forgotButtonFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Ensure focus nodes are initialized before building
    if (_role == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_usernameFocusNode == null ||
        _passwordFocusNode == null ||
        _loginButtonFocusNode == null ||
        _refreshButtonFocusNode == null ||
        _forgotButtonFocusNode == null) {
      // Return a loading indicator while initializing
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Check platform in build method
    final isWindows = Theme.of(context).platform == TargetPlatform.windows;

    // Wrap with RawKeyboardListener for Windows keyboard handling
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: isWindows ? _handleKeyEvent : null,
      child: CenteredFormContainer(
        title: 'User Login',
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(
                label: 'Username',
                controller: _usernameController,
                icon: Icons.person,
                focusNode: _usernameFocusNode!,
                textInputAction: TextInputAction.next,
                onFieldSubmitted: (_) {
                  // Move to password field when "Next" is pressed
                  if (_passwordFocusNode != null) {
                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                  }
                },
              ),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 24),
              _isLoading
                  ? const LinearProgressIndicator(minHeight: 6)
                  : Focus(
                      focusNode: _loginButtonFocusNode!,
                      child: ElevatedButton(
                        onPressed: _handleLogin,
                        child: const Text('Login'),
                      ),
                    ),
              Focus(
                focusNode: _refreshButtonFocusNode!,
                child: TextButton(
                  onPressed: _forceSyncUsers,
                  child: const Text('Refresh users from host'),
                ),
              ),
              if (_role == DeviceRole.host)
                Focus(
                  focusNode: _forgotButtonFocusNode!,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/forgot');
                    },
                    child: const Text('Forgot Password?'),
                  ),
                ),
              if (_role == DeviceRole.client)
                Focus(
                  focusNode: _forgotButtonFocusNode!,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/device_few_settings');
                    },
                    child: const Text('Device Setting'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required FocusNode focusNode,
    TextInputAction textInputAction = TextInputAction.next,
    Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Enter $label' : null,
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      focusNode: _passwordFocusNode,
      obscureText: !_isPasswordVisible,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) {
        // Trigger login when "Enter" is pressed on password field
        _handleLogin();
      },
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() => _isPasswordVisible = !_isPasswordVisible);
          },
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'Enter password' : null,
    );
  }
}
