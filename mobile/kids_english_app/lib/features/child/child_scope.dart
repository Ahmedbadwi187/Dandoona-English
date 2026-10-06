import 'package:flutter/material.dart';

/// The child area is always English and left-to-right, whatever language the parent area uses.
class ChildScope extends StatelessWidget {
  const ChildScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Localizations.override(
      context: context,
      locale: const Locale('en'),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );
  }
}
