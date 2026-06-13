import 'package:flutter/material.dart';

class FormSectionCard extends StatelessWidget {
  const FormSectionCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: child);
  }
}
