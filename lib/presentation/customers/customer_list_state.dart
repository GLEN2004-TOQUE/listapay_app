part of 'customer_list_cubit.dart';

class CustomerListState extends Equatable {
  const CustomerListState({
    this.customers = const [],
    this.searchQuery = '',
    this.isLoading = true,
    this.isDeleting = false,
    this.errorMessage,
  });

  final List<Customer> customers;
  final String searchQuery;
  final bool isLoading;
  final bool isDeleting;
  final String? errorMessage;

  CustomerListState copyWith({
    List<Customer>? customers,
    String? searchQuery,
    bool? isLoading,
    bool? isDeleting,
    String? errorMessage,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [customers, searchQuery, isLoading, isDeleting, errorMessage];
}
