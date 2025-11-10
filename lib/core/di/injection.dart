import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/datasources/supabase_auth_datasource.dart';
import '../../features/auth/data/repositories_impl/supabase_auth_repository.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/check_username_exists.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/send_password_reset.dart';
import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/sign_up.dart';
import '../../features/auth/domain/usecases/watch_auth_state.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/books/data/repositories_impl/books_repository_impl.dart';
// import '../../features/books/data/repositories_impl/cached_books_repository.dart'; // TODO: Activar cuando esté completo
import '../../features/books/data/datasources/books_local_datasource.dart';
import '../../features/books/data/repositories_impl/draft_repository.dart';
import '../../features/books/domain/repositories/books_repository.dart';
import '../database/local_database.dart';
import '../database/offline_database.dart';
import '../sync/sync_manager.dart';
import '../../features/books/domain/usecases/add_comment.dart';
import '../../features/books/domain/usecases/add_view.dart';
import '../../features/books/domain/usecases/create_book.dart';
import '../../features/books/domain/usecases/increment_book_views.dart';
import '../../features/books/domain/usecases/react_to_book.dart';
import '../../features/books/domain/usecases/reply_to_comment_usecase.dart';
import '../../features/books/domain/usecases/get_book_categories.dart';
import '../../features/books/domain/usecases/search_books.dart';
import '../../features/books/domain/usecases/toggle_favorite.dart';
import '../../features/books/domain/usecases/watch_book.dart';
import '../../features/books/domain/usecases/watch_books.dart';
import '../../features/books/domain/usecases/watch_comments.dart';
import '../../features/books/domain/usecases/upload_book_cover.dart';
import '../../features/books/domain/usecases/watch_favorite_books.dart';
// Comentarios de capítulos
import '../../features/books/domain/usecases/add_chapter_comment.dart';
import '../../features/books/domain/usecases/reply_to_chapter_comment.dart';
import '../../features/books/domain/usecases/watch_chapter_comments.dart';
// Update and delete books
import '../../features/books/domain/usecases/update_book.dart';
import '../../features/books/domain/usecases/delete_book.dart';
import '../../features/books/presentation/cubit/books_event_bus.dart';
import '../../features/books/presentation/cubit/search_cubit.dart';
import '../../features/books/presentation/cubit/chapter_ai_cubit.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/create_or_fetch_thread.dart';
import '../../features/chat/domain/usecases/delete_message.dart';
import '../../features/chat/domain/usecases/get_thread_by_id.dart';
import '../../features/chat/domain/usecases/send_message.dart';
import '../../features/chat/domain/usecases/watch_messages.dart';
import '../../features/chat/domain/usecases/watch_threads.dart';
import '../../features/chat/presentation/cubit/chat_conversation_cubit.dart';
import '../../features/chat/presentation/cubit/chat_thread_list_cubit.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/datasources/supabase_profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/presentation/cubit/profile_connections_cubit.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/profile/presentation/cubit/profile_favorites_cubit.dart';
import '../../features/profile/presentation/cubit/profile_books_cubit.dart';
import '../../features/profile/domain/usecases/get_privacy_settings.dart';
import '../../features/profile/domain/usecases/update_privacy_settings.dart';
import '../../features/profile/domain/usecases/delete_account.dart';
import '../../features/profile/presentation/cubit/privacy_settings_cubit.dart';
import '../../features/notifications/data/datasources/supabase_notifications_datasource.dart';
import '../../features/notifications/data/repositories_impl/supabase_notifications_repository.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/domain/usecases/delete_all_notifications.dart';
import '../../features/notifications/domain/usecases/mark_all_notifications_as_read.dart';
import '../../features/notifications/domain/usecases/mark_notification_as_read.dart';
import '../../features/notifications/domain/usecases/mark_notifications_category_as_read.dart';
import '../../features/notifications/domain/usecases/watch_notifications.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/settings/data/datasources/theme_local_data_source.dart';
import '../../features/settings/data/repositories/theme_repository_impl.dart';
import '../../features/settings/domain/repositories/theme_repository.dart';
import '../../features/settings/domain/usecases/load_theme_mode.dart';
import '../../features/settings/domain/usecases/update_theme_mode.dart';
import '../../features/settings/presentation/cubit/theme_cubit.dart';
import '../../services/ai/gemini_search_service.dart';
import '../../services/notification/push_notifications_service.dart';

final GetIt sl = GetIt.instance;

/// Initializes the service locator with all application level dependencies.
Future<void> initInjection(SupabaseClient client) async {
  if (sl.isRegistered<SupabaseClient>()) {
    sl.unregister<SupabaseClient>();
  }
  sl.registerSingleton<SupabaseClient>(client);

  if (!sl.isRegistered<BooksEventBus>()) {
    sl.registerLazySingleton<BooksEventBus>(() => BooksEventBus());
  }

  sl
    ..registerLazySingleton<SupabaseAuthDatasource>(
      () => SupabaseAuthDatasource(client: sl()),
    )
    ..registerLazySingleton<AuthRepository>(
      () => SupabaseAuthRepository(datasource: sl()),
    )
    // Offline Database y Sync Manager (listos para usar)
    ..registerLazySingleton<OfflineDatabase>(
      () => OfflineDatabase.instance,
    )
    ..registerLazySingleton<SyncManager>(
      () => SyncManager.instance,
    )
    // Books Local DataSource (listo para usar)
    ..registerLazySingleton<BooksLocalDataSource>(
      () => BooksLocalDataSource(
        localDb: sl(),
        syncManager: sl(),
      ),
    )
    // Por ahora usar repositorio remoto directo
    // TODO: Cambiar a CachedBooksRepository cuando esté completamente implementado
    ..registerLazySingleton<BooksRepository>(
      () => SupabaseBooksRepository(client: sl()),
    )
    ..registerLazySingleton<LocalDatabase>(
      () => LocalDatabase.instance,
    )
    ..registerLazySingleton<DraftRepository>(
      () => DraftRepository(database: sl()),
    )
    ..registerLazySingleton(() => SignInUseCase(sl()))
    ..registerLazySingleton(() => SignUpUseCase(sl()))
    ..registerLazySingleton(() => SignOutUseCase(sl()))
    ..registerLazySingleton(() => WatchAuthStateUseCase(sl()))
    ..registerLazySingleton(() => GetCurrentUserUseCase(sl()))
    ..registerLazySingleton(() => CheckUsernameExistsUseCase(sl()))
    ..registerLazySingleton(() => SendPasswordResetUseCase(sl()))
    ..registerLazySingleton(() => CreateBookUseCase(sl()))
    ..registerLazySingleton(() => WatchBooksUseCase(sl()))
    ..registerLazySingleton(() => WatchBookUseCase(sl()))
    ..registerLazySingleton(() => ReactToBookUseCase(sl()))
    ..registerLazySingleton(() => ToggleFavoriteUseCase(sl()))
    ..registerLazySingleton(() => WatchFavoriteBooksUseCase(sl()))
    ..registerLazySingleton(() => SearchBooksUseCase(sl()))
    ..registerLazySingleton(() => GetBookCategoriesUseCase(sl()))
    ..registerLazySingleton(() => UploadBookCoverUseCase(sl()))
    ..registerLazySingleton(() => IncrementBookViewsUseCase(sl()))
    ..registerLazySingleton(() => AddViewUseCase(sl()))
    ..registerLazySingleton(() => AddCommentUseCase(sl()))
    ..registerLazySingleton(() => ReplyToCommentUseCase(sl()))
    ..registerLazySingleton(() => WatchCommentsUseCase(sl()))
    // Comentarios de capítulos
    ..registerLazySingleton(() => AddChapterCommentUseCase(sl()))
    ..registerLazySingleton(() => ReplyToChapterCommentUseCase(sl()))
    ..registerLazySingleton(() => WatchChapterCommentsUseCase(sl()))
    // Update and delete books
    ..registerLazySingleton(() => UpdateBookUseCase(sl()))
    ..registerLazySingleton(() => DeleteBookUseCase(sl()))
    ..registerLazySingleton(() => GeminiSearchService())
    ..registerLazySingleton<ThemeLocalDataSource>(
      () => ThemeLocalDataSource(),
    )
    ..registerLazySingleton<ThemeRepository>(
      () => ThemeRepositoryImpl(sl()),
    )
    ..registerLazySingleton(() => LoadThemeMode(sl()))
    ..registerLazySingleton(() => UpdateThemeMode(sl()))
    ..registerFactory(
      () => ThemeCubit(
        loadThemeMode: sl(),
        updateThemeMode: sl(),
      ),
    )
    ..registerFactory(() => ChapterAiCubit(geminiSearchService: sl()))
    ..registerFactory(() => SearchCubit(
          searchBooks: sl(),
          getBookCategories: sl(),
          watchFavoriteBooks: sl(),
          watchUserBooks: sl(),
          geminiSearchService: sl(),
          booksEventBus: sl(),
        ))
    ..registerLazySingleton<ChatRepository>(
      () => SupabaseChatRepository(sl()),
    )
    ..registerLazySingleton(() => CreateOrFetchThreadUseCase(sl()))
    ..registerLazySingleton(() => GetThreadByIdUseCase(sl()))
    ..registerLazySingleton(() => WatchThreadsUseCase(sl()))
    ..registerLazySingleton(() => WatchMessagesUseCase(sl()))
    ..registerLazySingleton(() => SendMessageUseCase(sl()))
    ..registerLazySingleton(() => DeleteMessageUseCase(sl()))
    ..registerFactory(() => ChatThreadListCubit(sl()))
    ..registerFactoryParam<ChatConversationCubit, String, String>(
      (threadId, userId) => ChatConversationCubit(
        watchMessages: sl(),
        sendMessage: sl(),
        deleteMessage: sl(),
        threadId: threadId,
        currentUserId: userId,
      ),
    )
    ..registerLazySingleton<ProfileRemoteDataSource>(
      () => SupabaseProfileRemoteDataSource(sl()),
    )
    ..registerLazySingleton<ProfileRepository>(
      () => ProfileRepositoryImpl(sl()),
    )
    ..registerFactory(() => ProfileCubit(sl()))
    ..registerFactory(() => ProfileConnectionsCubit(sl()))
    ..registerFactory(() => ProfileBooksCubit(sl()))
    ..registerFactory(() => ProfileFavoritesCubit(sl()))
    ..registerLazySingleton(() => GetPrivacySettingsUseCase(sl()))
    ..registerLazySingleton(() => UpdatePrivacySettingsUseCase(sl()))
    ..registerLazySingleton(() => DeleteAccountUseCase(sl()))
    ..registerFactory(
      () => PrivacySettingsCubit(
        getPrivacySettings: sl(),
        updatePrivacySettings: sl(),
      ),
    )
    ..registerLazySingleton<SupabaseNotificationsDatasource>(
      () => SupabaseNotificationsDatasource(sl()),
    )
    ..registerLazySingleton<PushNotificationsService>(
      () => PushNotificationsService(
        messaging: FirebaseMessaging.instance,
        client: sl(),
      ),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => SupabaseNotificationsRepository(datasource: sl()),
    )
    ..registerLazySingleton(() => WatchNotificationsUseCase(sl()))
    ..registerLazySingleton(() => MarkAllNotificationsAsReadUseCase(sl()))
    ..registerLazySingleton(() => MarkNotificationsCategoryAsReadUseCase(sl()))
    ..registerLazySingleton(() => MarkNotificationAsReadUseCase(sl()))
    ..registerLazySingleton(() => DeleteAllNotificationsUseCase(sl()))
    ..registerFactory(
      () => NotificationsCubit(
        watchNotifications: sl(),
        markAllNotificationsAsRead: sl(),
        markCategoryAsRead: sl(),
        markNotificationAsRead: sl(),
        deleteAllNotifications: sl(),
      ),
    )
    ..registerFactory(
      () => AuthBloc(
        signIn: sl(),
        signUp: sl(),
        signOut: sl(),
        watchAuthState: sl(),
        getCurrentUser: sl(),
        sendPasswordReset: sl(),
      ),
    );
}
