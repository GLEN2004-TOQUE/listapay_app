import 'package:equatable/equatable.dart';

class CustomerSummary extends Equatable {
  const CustomerSummary({
    required this.id,
    required this.name,
    this.phone,
  });

  final int id;
  final String name;
  final String? phone;

  @override
  List<Object?> get props => [id, name, phone];
}
