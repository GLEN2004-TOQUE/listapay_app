import 'package:flutter/material.dart';
import 'package:listapay/presentation/modules/module_scaffold.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModuleScaffold(
      title: 'Reports',
      icon: Icons.bar_chart,
      emptyTitle: 'No sales data yet',
      emptySubtitle: 'Dashboard charts load from local SQLite cache.',
    );
  }
}
