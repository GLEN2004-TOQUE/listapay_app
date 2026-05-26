import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ListaPay/domain/entities/product_category.dart';
import 'package:ListaPay/domain/repositories/inventory_repository.dart';

part 'category_list_state.dart';

class CategoryListCubit extends Cubit<CategoryListState> {
  CategoryListCubit(this._repository) : super(const CategoryListState());

  final InventoryRepository _repository;
  StreamSubscription<List<ProductCategory>>? _subscription;

  void start() {
    _subscription?.cancel();
    emit(state.copyWith(isLoading: true, errorMessage: null));
    _subscription = _repository.watchCategories().listen(
      (categories) => emit(state.copyWith(
        isLoading: false,
        categories: categories,
      )),
      onError: (_) => emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load categories.',
      )),
    );
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    required String color,
  }) async {
    emit(state.copyWith(isSaving: true, errorMessage: null));
    try {
      await _repository.saveCategory(id: id, name: name, color: color);
      emit(state.copyWith(isSaving: false));
    } on InventoryException catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: 'Could not save category.',
      ));
    }
  }

  Future<void> deleteCategory(int id) async {
    emit(state.copyWith(isSaving: true, errorMessage: null));
    try {
      await _repository.deleteCategory(id);
      emit(state.copyWith(isSaving: false));
    } on InventoryException catch (e) {
      emit(state.copyWith(isSaving: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isSaving: false,
        errorMessage: 'Could not delete category.',
      ));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
