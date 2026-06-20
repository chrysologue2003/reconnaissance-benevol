import 'package:flutter/material.dart';

class BadgeWidget extends StatelessWidget {
  final String label;

  const BadgeWidget({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.emoji_events, size: 18, color: Colors.amber),
      label: Text(label),
      backgroundColor: Colors.green.shade50,
    );
  }
}
