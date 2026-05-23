import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:listapay/core/widgets/empty_state.dart';

class ModuleScaffold extends StatelessWidget {
  const ModuleScaffold({
    super.key,
    required this.title,
    required this.icon,
    required this.emptyTitle,
    this.emptySubtitle,
    this.fab,
    this.isLoading = false,
    this.child,
  });

  final String title;
  final IconData icon;
  final String emptyTitle;
  final String? emptySubtitle;
  final Widget? fab;
  final bool isLoading;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
      ),
      floatingActionButton: fab,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : child ??
              EmptyState(
                icon: icon,
                title: emptyTitle,
                subtitle: emptySubtitle,
              ),
    );
  }
}
