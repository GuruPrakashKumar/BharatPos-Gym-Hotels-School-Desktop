import 'dart:async';

import 'package:flutter/material.dart';

class KeyboardListenerWidget extends StatefulWidget {
  final Function(String) onKeyPressed;
  final Duration bufferDuration;
  final Widget child;
  const KeyboardListenerWidget({
    Key? key,
    required this.onKeyPressed,
    this.bufferDuration = const Duration(milliseconds: 200),
    required this.child
  }) : super(key: key);

  @override
  State<KeyboardListenerWidget> createState() => _KeyboardListenerWidgetState();
}

class _KeyboardListenerWidgetState extends State<KeyboardListenerWidget> {
  String _keyPressed = '';
  Timer? _bufferTimer;

  @override
  void initState() {
    super.initState();
    FocusNode().unfocus(); // Release any existing focus to ensure proper event capturing
  }

  @override
  void dispose() {
    _bufferTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(), // No need for explicit focusNode creation
      onKey: (RawKeyEvent event) {
        _keyPressed = event.logicalKey.keyLabel.toUpperCase();
        _bufferTimer?.cancel(); // Clear previous timer
        _bufferTimer = Timer(widget.bufferDuration, () {
          if (_keyPressed.isNotEmpty) {
            widget.onKeyPressed(_keyPressed);
            _keyPressed = ''; // Reset buffer after action
          }
        });
      },
      child: Container(
        child: widget.child,
      ),
    );
  }
}
