import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/domain/entities/product_item.dart';
import 'package:listapay/domain/repositories/inventory_repository.dart';

part 'product_list_state.dart';

class ProductListCubit extends Cubit<ProductListState> {
  ProductListCubit(this._repository) : super(const ProductListState());

  final InventoryRepository _repository;
  StreamSubscription<List<ProductItem>>? _subscription;

  void start() {
    _listen(_repository.watchProducts(search: state.searchQuery));
  }

  void setSearch(String query) {
    emit(state.copyWith(searchQuery: query));
    _listen(_repository.watchProducts(
      search: query.trim().isEmpty ? null : query.trim(),
    ));
  }

  Future<void> deleteProduct(int id) async {
    emit(state.copyWith(isDeleting: true, errorMessage: null));
    try {
      await _repository.deleteProduct(id);
      emit(state.copyWith(isDeleting: false));
    } on InventoryException catch (e) {
      emit(state.copyWith(isDeleting: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isDeleting: false,
        errorMessage: 'Could not delete product.',
      ));
    }
  }

  void _listen(Stream<List<ProductItem>> stream) {
    _subscription?.cancel();
    emit(state.copyWith(isLoading: true, errorMessage: null));
    _subscription = stream.listen(
      (products) => emit(state.copyWith(
        isLoading: false,
        products: products,
      )),
      onError: (_) => emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load products.',
      )),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
