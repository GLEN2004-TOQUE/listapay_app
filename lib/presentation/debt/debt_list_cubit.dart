import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/domain/entities/debt_record.dart';
import 'package:listapay/domain/entities/debt_status.dart';
import 'package:listapay/domain/repositories/debt_repository.dart';

part 'debt_list_state.dart';

class DebtListCubit extends Cubit<DebtListState> {
  DebtListCubit(this._repository) : super(const DebtListState());

  final DebtRepository _repository;
  StreamSubscription<List<DebtRecord>>? _subscription;

  void start() {
    _repository.refreshOverdueStatuses();
    setFilter(state.filter);
  }

  void setFilter(DebtFilter filter) {
    emit(state.copyWith(filter: filter));
    DebtStatus? statusFilter;
    switch (filter) {
      case DebtFilter.all:
        statusFilter = null;
      case DebtFilter.pending:
        statusFilter = DebtStatus.pending;
      case DebtFilter.overdue:
        statusFilter = DebtStatus.overdue;
      case DebtFilter.paid:
        statusFilter = DebtStatus.paid;
    }
    _listen(_repository.watchDebts(filter: statusFilter));
  }

  void _listen(Stream<List<DebtRecord>> stream) {
    _subscription?.cancel();
    emit(state.copyWith(isLoading: true, errorMessage: null));
    _subscription = stream.listen(
      (debts) => emit(state.copyWith(isLoading: false, debts: debts)),
      onError: (_) => emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load debts.',
      )),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
