import '../../domain/entities/user_entity.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserModel extends UserEntity {
  UserModel({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl, // 👈 agrega aquí
  }) : super(
          uid: uid,
          email: email,
          displayName: displayName,
          photoUrl: photoUrl, // 👈 pasa al padre
        );

  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? '',
      photoUrl: user.photoURL, // 👈 mapea la foto de Google
    );
  }
}
