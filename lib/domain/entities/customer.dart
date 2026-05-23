import 'package:equatable/equatable.dart';
import 'package:listapay/domain/entities/customer_summary.dart';

class Customer extends Equatable {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.notes,
  });

  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? notes;

  CustomerSummary get summary => CustomerSummary(id: id, name: name, phone: phone);

  @override
  List<Object?> get props => [id, name, phone, address, notes];
}
