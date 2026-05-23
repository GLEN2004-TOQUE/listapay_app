part of 'category_list_cubit.dart';

class CategoryListState extends Equatable {
  const CategoryListState({
    this.categories = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<ProductCategory> categories;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;

  CategoryListState copyWith({
    List<ProductCategory>? categories,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
  }) {
    return CategoryListState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [categories, isLoading, isSaving, errorMessage];
}
