import 'package:get_it/get_it.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../features/auth/data/datasources/firebase_auth_datasource.dart';
import '../../features/auth/data/repositories_impl/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/sign_in.dart';
import '../../features/auth/domain/usecases/sign_in_with_google.dart';
import '../../features/auth/domain/usecases/sign_up.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/check_username_exists.dart'; // 👈 importa el caso de uso
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/domain/usecases/sign_out.dart';
import '../../features/auth/domain/usecases/watch_auth_state.dart';
import '../../features/books/data/datasources/books_remote_datasource.dart';
import '../../features/books/data/repositories_impl/books_repository_impl.dart';
import '../../features/books/domain/repositories/books_repository.dart';
import '../../features/books/domain/usecases/create_book.dart';
import '../../features/books/domain/usecases/watch_books.dart';
import '../../features/books/domain/usecases/watch_user_books.dart';
import '../../features/books/domain/usecases/add_comment.dart';
import '../../features/books/domain/usecases/watch_comments.dart';
import '../../features/books/domain/usecases/watch_book.dart';
import '../../features/books/domain/usecases/increment_book_views.dart';
import '../../features/books/domain/usecases/react_to_book.dart';
import '../../features/books/domain/usecases/react_to_comment.dart';
import '../../features/books/domain/usecases/add_chapter_comment.dart';
import '../../features/books/domain/usecases/watch_chapter_comments.dart';
import '../../features/books/domain/usecases/get_book_reaction.dart';
import '../../features/books/domain/usecases/get_comment_reactions.dart';
import '../../features/books/domain/usecases/update_book.dart';
import '../../features/books/domain/usecases/delete_book.dart';
import '../../features/books/presentation/cubit/book_list_cubit.dart';
import '../../features/books/presentation/cubit/user_books_cubit.dart';
import '../../features/books/presentation/cubit/book_detail_cubit.dart';
import '../../features/books/presentation/cubit/chapter_detail_cubit.dart';


final sl = GetIt.instance;

Future<void> initDependencies() async {
  // 3rd party
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseStorage>(() => FirebaseStorage.instance);
  sl.registerLazySingleton<GoogleSignIn>(() => GoogleSignIn(
        scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
      ));

  // datasource
  sl.registerLazySingleton<FirebaseAuthDatasource>(() => FirebaseAuthDatasource(
        firebaseAuth: sl<FirebaseAuth>(),
        googleSignIn: sl<GoogleSignIn>(),
      ));
  sl.registerLazySingleton<BooksRemoteDataSource>(() => BooksRemoteDataSource(
        firestore: sl<FirebaseFirestore>(),
        storage: sl<FirebaseStorage>(),
        auth: sl<FirebaseAuth>(),
      ));

  // repository
  sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(sl<FirebaseAuthDatasource>()));
  sl.registerLazySingleton<BooksRepository>(
      () => BooksRepositoryImpl(remote: sl<BooksRemoteDataSource>()));

  // usecases
  sl.registerLazySingleton(() => SignIn(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignInWithGoogle(sl<AuthRepository>()));
  sl.registerLazySingleton(() => SignUp(sl<AuthRepository>()));
  sl.registerLazySingleton(() => GetCurrentUser(sl<AuthRepository>()));
  sl.registerLazySingleton(() => CheckUsernameExists(sl<AuthRepository>())); // 👈 registra este
  sl.registerLazySingleton(() => SignOut(sl<AuthRepository>())); // <-- agregado
  sl.registerLazySingleton(() => WatchAuthState(sl<AuthRepository>()));
  sl.registerLazySingleton(() => CreateBook(sl<BooksRepository>()));
  sl.registerLazySingleton(() => WatchBooks(sl<BooksRepository>()));
  sl.registerLazySingleton(() => WatchUserBooks(sl<BooksRepository>()));
  sl.registerLazySingleton(() => AddComment(sl<BooksRepository>()));
  sl.registerLazySingleton(() => WatchComments(sl<BooksRepository>()));
  sl.registerLazySingleton(() => WatchBook(sl<BooksRepository>()));
  sl.registerLazySingleton(() => IncrementBookViews(sl<BooksRepository>()));
  sl.registerLazySingleton(() => ReactToBook(sl<BooksRepository>()));
  sl.registerLazySingleton(() => GetBookReaction(sl<BooksRepository>()));
  sl.registerLazySingleton(() => ReactToComment(sl<BooksRepository>()));
  sl.registerLazySingleton(() => GetCommentReactions(sl<BooksRepository>()));
  sl.registerLazySingleton(() => AddChapterComment(sl<BooksRepository>()));
  sl.registerLazySingleton(() => WatchChapterComments(sl<BooksRepository>()));
  sl.registerLazySingleton(() => UpdateBook(sl<BooksRepository>()));
  sl.registerLazySingleton(() => DeleteBook(sl<BooksRepository>()));

  // bloc
  sl.registerFactory(() => AuthBloc(
        signIn: sl<SignIn>(),
        signInWithGoogle: sl<SignInWithGoogle>(),
        signUp: sl<SignUp>(),
        getCurrentUser: sl<GetCurrentUser>(),
        signOut: sl<SignOut>(), // <-- agregado
        watchAuthState: sl<WatchAuthState>(),
      ));
  sl.registerFactory(() => BookListCubit(watchBooks: sl<WatchBooks>()));
  sl.registerFactory(() => UserBooksCubit(
        watchUserBooks: sl<WatchUserBooks>(),
        deleteBook: sl<DeleteBook>(),
      ));
  sl.registerFactory(() => BookDetailCubit(
        watchBook: sl<WatchBook>(),
        watchComments: sl<WatchComments>(),
        addComment: sl<AddComment>(),
        incrementBookViews: sl<IncrementBookViews>(),
        reactToBook: sl<ReactToBook>(),
        reactToComment: sl<ReactToComment>(),
        getBookReaction: sl<GetBookReaction>(),
        getCommentReactions: sl<GetCommentReactions>(),
      ));
  sl.registerFactory(() => ChapterDetailCubit(
    watchChapterComments: sl<WatchChapterComments>(),
    addChapterComment: sl<AddChapterComment>(),
    reactToComment: sl<ReactToComment>(),
    getCommentReactions: sl<GetCommentReactions>(),
  ));
}
