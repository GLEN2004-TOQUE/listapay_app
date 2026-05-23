import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:listapay/domain/entities/customer.dart';
import 'package:listapay/domain/repositories/customer_repository.dart';

part 'customer_list_state.dart';

class CustomerListCubit extends Cubit<CustomerListState> {
  CustomerListCubit(this._repository) : super(const CustomerListState());

  final CustomerRepository _repository;
  StreamSubscription<List<Customer>>? _subscription;

  void start() => _listen(_repository.watchCustomers(search: state.searchQuery));

  void setSearch(String query) {
    emit(state.copyWith(searchQuery: query));
    _listen(
      _repository.watchCustomers(
        search: query.trim().isEmpty ? null : query.trim(),
      ),
    );
  }

  Future<void> deleteCustomer(int id) async {
    emit(state.copyWith(isDeleting: true, errorMessage: null));
    try {
      await _repository.deleteCustomer(id);
      emit(state.copyWith(isDeleting: false));
    } on CustomerException catch (e) {
      emit(state.copyWith(isDeleting: false, errorMessage: e.message));
    } catch (_) {
      emit(state.copyWith(
        isDeleting: false,
        errorMessage: 'Could not delete customer.',
      ));
    }
  }

  void _listen(Stream<List<Customer>> stream) {
    _subscription?.cancel();
    emit(state.copyWith(isLoading: true, errorMessage: null));
    _subscription = stream.listen(
      (customers) => emit(state.copyWith(isLoading: false, customers: customers)),
      onError: (_) => emit(state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load customers.',
      )),
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
