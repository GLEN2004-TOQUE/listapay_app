part of 'debt_list_cubit.dart';

enum DebtFilter { all, pending, overdue, paid }

class DebtListState extends Equatable {
  const DebtListState({
    this.debts = const [],
    this.filter = DebtFilter.all,
    this.isLoading = true,
    this.errorMessage,
  });

  final List<DebtRecord> debts;
  final DebtFilter filter;
  final bool isLoading;
  final String? errorMessage;

  DebtListState copyWith({
    List<DebtRecord>? debts,
    DebtFilter? filter,
    bool? isLoading,
    String? errorMessage,
  }) {
    return DebtListState(
      debts: debts ?? this.debts,
      filter: filter ?? this.filter,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [debts, filter, isLoading, errorMessage];
}
