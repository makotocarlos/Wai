import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirebaseAuthDatasource {
  final FirebaseAuth firebaseAuth;
  final GoogleSignIn googleSignIn;
  final FirebaseFirestore firestore;

  FirebaseAuthDatasource({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
    FirebaseFirestore? firestore,
  })  : firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email', 'https://www.googleapis.com/auth/userinfo.profile']),
        firestore = firestore ?? FirebaseFirestore.instance;

  Stream<UserModel?> authStateChanges() =>
      firebaseAuth.authStateChanges().map((u) => u == null ? null : UserModel.fromFirebaseUser(u));

  UserModel? currentUser() =>
      firebaseAuth.currentUser == null ? null : UserModel.fromFirebaseUser(firebaseAuth.currentUser!);

  Future<UserModel> signInWithEmail(String email, String password) async {
    final cred = await firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    return UserModel.fromFirebaseUser(cred.user!);
  }

  Future<UserModel> signUpWithEmail(String email, String password, {required String username}) async {
    // Validar que el username no exista
    final exists = await isUsernameTaken(username);
    if (exists) {
      throw FirebaseAuthException(code: 'username-already-in-use', message: 'El nombre de usuario ya está en uso');
    }

    // Crear usuario en Firebase
    final cred = await firebaseAuth.createUserWithEmailAndPassword(email: email, password: password);

    // Guardar username en Firestore
    await firestore.collection('users').doc(cred.user!.uid).set({
      'username': username,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Actualizar displayName en FirebaseAuth
    await cred.user!.updateDisplayName(username);

    // Enviar correo de verificación
    await cred.user!.sendEmailVerification();

    return UserModel.fromFirebaseUser(cred.user!);
  }

  Future<UserModel> signInWithGoogle() async {
    final gUser = await googleSignIn.signIn();
    if (gUser == null) throw Exception('Login cancelado por el usuario');
    final gAuth = await gUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: gAuth.accessToken,
      idToken: gAuth.idToken,
    );
    final result = await firebaseAuth.signInWithCredential(credential);

    // Opcional: guardar usuario en Firestore si es nuevo
    final doc = await firestore.collection('users').doc(result.user!.uid).get();
    if (!doc.exists) {
      await firestore.collection('users').doc(result.user!.uid).set({
        'username': result.user!.displayName ?? 'Usuario',
        'email': result.user!.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return UserModel.fromFirebaseUser(result.user!);
  }

  Future<void> signOut() async {
    await googleSignIn.signOut();
    await firebaseAuth.signOut();
  }

  Future<bool> isUsernameTaken(String username) async {
    final snapshot = await firestore.collection('users').where('username', isEqualTo: username).get();
    return snapshot.docs.isNotEmpty;
  }
}
