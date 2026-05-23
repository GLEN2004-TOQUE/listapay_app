part of 'cart_cubit.dart';

class CartState extends Equatable {
  const CartState({
    this.lines = const [],
    this.errorMessage,
  });

  final List<CartLine> lines;
  final String? errorMessage;

  double get total => lines.fold(0, (sum, line) => sum + line.subtotal);

  int get itemCount => lines.fold(0, (sum, line) => sum + line.qty);

  bool get isEmpty => lines.isEmpty;

  CartState copyWith({
    List<CartLine>? lines,
    String? errorMessage,
  }) {
    return CartState(
      lines: lines ?? this.lines,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [lines, errorMessage];
}
