import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/result.dart';
import '../data/repositories/supabase_operation_repository.dart';
import '../domain/entities/operation.dart';
import '../domain/repositories/operation_repository.dart';

final operationRepositoryProvider = Provider<OperationRepository>((ref) {
  return SupabaseOperationRepository(Supabase.instance.client);
});

final operationsProvider = FutureProvider<Result<List<Operation>>>((ref) {
  final repository = ref.watch(operationRepositoryProvider);
  return repository.getOperations();
});
