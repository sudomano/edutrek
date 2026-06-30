import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A reusable keyboard navigation handler for Windows desktop applications
/// Provides Tab, Shift+Tab, and Enter key navigation between form fields
class KeyboardNavigationHandler {
  final BuildContext context;
  final List<FocusNode> focusNodes;
  final VoidCallback? onSubmit;
  final Map<FocusNode, VoidCallback>? customEnterActions;
  final bool autoFocusFirst;
  final bool enableTabNavigation;
  final bool enableEnterNavigation;

  KeyboardNavigationHandler({
    required this.context,
    required this.focusNodes,
    this.onSubmit,
    this.customEnterActions,
    this.autoFocusFirst = true,
    this.enableTabNavigation = true,
    this.enableEnterNavigation = true,
  });

  /// Set up keyboard handling for Windows platform
  void setup() {
    if (Theme.of(context).platform == TargetPlatform.windows) {
      if (autoFocusFirst && focusNodes.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (focusNodes.first.hasFocus == false &&
              focusNodes.every((node) => !node.hasFocus)) {
            FocusScope.of(context).requestFocus(focusNodes.first);
          }
        });
      }
    }
  }

  /// Get the next focusable node in the tab order
  FocusNode? _getNextFocusNode(FocusNode current) {
    final index = focusNodes.indexOf(current);
    if (index != -1 && index < focusNodes.length - 1) {
      return focusNodes[index + 1];
    }
    // Wrap around to first
    return focusNodes.isNotEmpty ? focusNodes.first : null;
  }

  /// Get the previous focusable node in the tab order (for Shift+Tab)
  FocusNode? _getPreviousFocusNode(FocusNode current) {
    final index = focusNodes.indexOf(current);
    if (index > 0) {
      return focusNodes[index - 1];
    }
    // Wrap around to last
    return focusNodes.isNotEmpty ? focusNodes.last : null;
  }

  /// Handle keyboard events
  void handleKeyEvent(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      // Handle Tab and Shift+Tab
      if (enableTabNavigation && event.logicalKey == LogicalKeyboardKey.tab) {
        final focusedNode = FocusScope.of(context).focusedChild;
        if (focusedNode != null && focusNodes.contains(focusedNode)) {
          final isShiftPressed = event.isShiftPressed;
          if (isShiftPressed) {
            final previousNode = _getPreviousFocusNode(focusedNode);
            if (previousNode != null) {
              FocusScope.of(context).requestFocus(previousNode);
            }
          } else {
            final nextNode = _getNextFocusNode(focusedNode);
            if (nextNode != null) {
              FocusScope.of(context).requestFocus(nextNode);
            }
          }
        }
      }

      // Handle Enter key
      if (enableEnterNavigation &&
          event.logicalKey == LogicalKeyboardKey.enter) {
        final focusedNode = FocusScope.of(context).focusedChild;

        if (focusedNode != null && focusNodes.contains(focusedNode)) {
          final index = focusNodes.indexOf(focusedNode);

          // Check if there's a custom action for this focus node
          if (customEnterActions != null &&
              customEnterActions!.containsKey(focusedNode)) {
            customEnterActions![focusedNode]!();
          }
          // If it's the last field, trigger submit
          else if (index == focusNodes.length - 1 && onSubmit != null) {
            onSubmit!();
          }
          // Otherwise move to next field
          else {
            final nextNode = _getNextFocusNode(focusedNode);
            if (nextNode != null) {
              FocusScope.of(context).requestFocus(nextNode);
            }
          }
        }
      }
    }
  }

  /// Create a RawKeyboardListener widget with the keyboard handler
  Widget wrapWithKeyboardListener(Widget child) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: Theme.of(context).platform == TargetPlatform.windows
          ? handleKeyEvent
          : null,
      child: child,
    );
  }

  /// Dispose all focus nodes
  void dispose() {
    for (var node in focusNodes) {
      node.dispose();
    }
  }
}

/// Extension to easily add keyboard navigation to any Form
extension KeyboardNavigation on Widget {
  /// Wrap any widget with keyboard navigation support
  Widget withKeyboardNavigation({
    required BuildContext context,
    required List<FocusNode> focusNodes,
    VoidCallback? onSubmit,
    Map<FocusNode, VoidCallback>? customEnterActions,
    bool autoFocusFirst = true,
    bool enableTabNavigation = true,
    bool enableEnterNavigation = true,
  }) {
    final handler = KeyboardNavigationHandler(
      context: context,
      focusNodes: focusNodes,
      onSubmit: onSubmit,
      customEnterActions: customEnterActions,
      autoFocusFirst: autoFocusFirst,
      enableTabNavigation: enableTabNavigation,
      enableEnterNavigation: enableEnterNavigation,
    );

    // Schedule setup after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handler.setup();
    });

    return handler.wrapWithKeyboardListener(this);
  }
}

/// A helper class to manage form focus nodes and keyboard navigation
class FormFocusManager {
  final List<FocusNode> focusNodes = [];

  /// Create a new focus node and add to the list
  FocusNode createFocusNode() {
    final node = FocusNode();
    focusNodes.add(node);
    return node;
  }

  /// Create multiple focus nodes
  List<FocusNode> createFocusNodes(int count) {
    return List.generate(count, (_) => createFocusNode());
  }

  /// Set custom enter action for a specific focus node
  Map<FocusNode, VoidCallback> createCustomActions(
      Map<FocusNode, VoidCallback> actions) {
    return actions;
  }

  /// Dispose all focus nodes
  void dispose() {
    for (var node in focusNodes) {
      node.dispose();
    }
    focusNodes.clear();
  }
}
