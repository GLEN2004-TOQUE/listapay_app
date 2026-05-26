import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ListaPay/presentation/pos/cart_cubit.dart';

/// Provides shared [CartCubit] for all POS sub-routes.
class PosShell extends StatelessWidget {
  const PosShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CartCubit(),
      child: child,
    );
  }
}
