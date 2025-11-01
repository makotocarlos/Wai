import '../datasources/supabase_auth_datasource.dart';
import 'supabase_auth_repository.dart';

typedef AuthRepositoryImpl = SupabaseAuthRepository;

AuthRepositoryImpl createAuthRepository(SupabaseAuthDatasource datasource) {
	return SupabaseAuthRepository(datasource: datasource);
}
