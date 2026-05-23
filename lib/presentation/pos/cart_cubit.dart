import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/domain/entities/cart_line.dart';
import 'package:listapay/domain/entities/product_item.dart';

part 'cart_state.dart';

class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void addProduct(ProductItem product, {int qty = 1}) {
    if (product.stockQty <= 0) {
      emit(state.copyWith(errorMessage: '${product.name} is out of stock.'));
      return;
    }

    final lines = List<CartLine>.from(state.lines);
    final index = lines.indexWhere((l) => l.productId == product.id);

    if (index >= 0) {
      final existing = lines[index];
      final newQty = existing.qty + qty;
      if (newQty > existing.maxStock) {
        emit(state.copyWith(
          errorMessage:
              'Only ${existing.maxStock} ${product.name} in stock.',
        ));
        return;
      }
      lines[index] = existing.copyWith(qty: newQty);
    } else {
      if (qty > product.stockQty) {
        emit(state.copyWith(
          errorMessage: 'Only ${product.stockQty} ${product.name} in stock.',
        ));
        return;
      }
      lines.add(CartLine.fromProduct(product, qty: qty));
    }

    emit(state.copyWith(lines: lines, errorMessage: null));
  }

  void setQty(int productId, int qty) {
    if (qty <= 0) {
      removeLine(productId);
      return;
    }

    final lines = List<CartLine>.from(state.lines);
    final index = lines.indexWhere((l) => l.productId == productId);
    if (index < 0) return;

    final line = lines[index];
    if (qty > line.maxStock) {
      emit(state.copyWith(
        errorMessage: 'Only ${line.maxStock} ${line.name} in stock.',
      ));
      return;
    }

    lines[index] = line.copyWith(qty: qty);
    emit(state.copyWith(lines: lines, errorMessage: null));
  }

  void removeLine(int productId) {
    final lines = state.lines.where((l) => l.productId != productId).toList();
    emit(state.copyWith(lines: lines));
  }

  void clear() {
    emit(const CartState());
  }

  void clearError() {
    emit(state.copyWith(errorMessage: null));
  }
}
