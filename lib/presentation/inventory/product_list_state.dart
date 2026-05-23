part of 'product_list_cubit.dart';

class ProductListState extends Equatable {
  const ProductListState({
    this.products = const [],
    this.searchQuery = '',
    this.isLoading = true,
    this.isDeleting = false,
    this.errorMessage,
  });

  final List<ProductItem> products;
  final String searchQuery;
  final bool isLoading;
  final bool isDeleting;
  final String? errorMessage;

  ProductListState copyWith({
    List<ProductItem>? products,
    String? searchQuery,
    bool? isLoading,
    bool? isDeleting,
    String? errorMessage,
  }) {
    return ProductListState(
      products: products ?? this.products,
      searchQuery: searchQuery ?? this.searchQuery,
      isLoading: isLoading ?? this.isLoading,
      isDeleting: isDeleting ?? this.isDeleting,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        products,
        searchQuery,
        isLoading,
        isDeleting,
        errorMessage,
      ];
}
