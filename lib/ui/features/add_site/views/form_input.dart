import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

/// The box around one of `2a`'s inputs (restyle v2 §4): the group tone, a
/// 1.5 dp edge border, 2 dp text-1 while the field inside holds focus,
/// radius 14.
class FormInput extends StatefulWidget {
  const FormInput({
    super.key,
    required this.child,
    this.minHeight = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 14),
  });

  final Widget child;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  State<FormInput> createState() => _FormInputState();
}

class _FormInputState extends State<FormInput> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Container(
        constraints: BoxConstraints(minHeight: widget.minHeight),
        padding: widget.padding,
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(R.input),
          border: Border.all(
            color: _focused ? C.textPrimary : C.edge,
            width: _focused ? 2 : 1.5,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
