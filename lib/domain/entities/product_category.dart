import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

class ProductCategory extends Equatable {
  const ProductCategory({
    required this.id,
    required this.name,
    required this.color,
  });

  final int id;
  final String name;
  final String color;

  Color get displayColor {
    try {
      final hex = color.replaceFirst('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF0D7C4E);
    }
  }

  @override
  List<Object?> get props => [id, name, color];
}
