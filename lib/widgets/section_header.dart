import 'package:flutter/material.dart';
import 'package:prasowka/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentFor(context), letterSpacing: 1.2, fontSize: 12),
      ),
    );
  }
}
