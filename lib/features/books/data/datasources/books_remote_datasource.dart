import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

import '../models/book_model.dart';
import '../models/comment_model.dart';
import '../../domain/entities/book_reaction.dart';
import '../../domain/entities/chapter_entity.dart';

class BooksRemoteDataSource {
  BooksRemoteDataSource({
    required FirebaseFirestore firestore,
    required FirebaseStorage storage,
    required fb.FirebaseAuth auth,
  })  : _firestore = firestore,
        _storage = storage,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final fb.FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _booksCol =>
      _firestore.collection('books');

  Future<void> createBook({
    required String title,
    required String category,
    required List<ChapterEntity> chapters,
    required int publishedChapterOrder,
    String? description,
    File? coverFile,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para crear un libro.');
    }

    final docRef = _booksCol.doc();
    String? coverUrl;
    String? coverBase64;
    if (coverFile != null) {
      try {
        final storageRef = _storage.ref().child(
            'book_covers/${docRef.id}/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(coverFile);
        coverUrl = await storageRef.getDownloadURL();
      } on FirebaseException {
        coverBase64 = await _encodeCover(coverFile);
      } catch (_) {
        coverBase64 = await _encodeCover(coverFile);
      }
    }

    final now = DateTime.now();
    final model = BookModel(
      id: docRef.id,
      title: title,
      category: category,
      description: description,
      coverUrl: coverUrl,
      coverBase64: coverBase64,
      authorId: user.uid,
      authorName: user.displayName ?? user.email ?? 'Autor',
      chapters: chapters,
      createdAt: now,
      updatedAt: now,
      publishedChapterOrder: publishedChapterOrder,
      likes: 0,
      dislikes: 0,
      views: 0,
    );

    await docRef.set(model.toMap());

    for (final chapter in chapters) {
      await docRef
          .collection('chapters')
          .doc(chapter.order.toString())
          .set(
        {
          'title': chapter.title,
          'order': chapter.order,
          'isPublished': chapter.isPublished,
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<String> _encodeCover(File file) async {
    const maxBytes = 900000; // 0.9 MB to stay below Firestore limits.
    var bytes = await file.readAsBytes();

    if (bytes.length <= maxBytes) {
      return base64Encode(bytes);
    }

    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('No se pudo procesar la portada seleccionada.');
    }

    var candidate = decoded;
    var quality = 90;
    List<int> encoded = img.encodeJpg(candidate, quality: quality);

    while (encoded.length > maxBytes) {
      if (quality > 40) {
        quality -= 10;
      } else if (candidate.width > 600 || candidate.height > 600) {
        final nextWidth = math.max(320, (candidate.width * 0.85).round());
        candidate = img.copyResize(candidate, width: nextWidth);
      } else {
        // Last attempt with lower quality.
        if (quality > 20) {
          quality = 20;
          encoded = img.encodeJpg(candidate, quality: quality);
        }
        break;
      }
      encoded = img.encodeJpg(candidate, quality: quality);
    }

    if (encoded.length > maxBytes) {
      throw Exception(
        'La imagen de portada supera el tamaño permitido. Elige una imagen más ligera.',
      );
    }

    return base64Encode(encoded);
  }

  Stream<List<BookModel>> watchBooks() {
    return _booksCol.orderBy('createdAt', descending: true).snapshots().map(
        (snapshot) =>
            snapshot.docs.map((doc) => BookModel.fromDocument(doc)).toList());
  }

  Stream<List<BookModel>> watchUserBooks() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const <BookModel>[]);
    }

    return _booksCol
        .where('authorId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) {
          final books =
              snapshot.docs.map((doc) => BookModel.fromDocument(doc)).toList();
          books.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return books;
        });
  }

  Stream<BookModel> watchBook(String bookId) {
    return _booksCol.doc(bookId).snapshots().map(BookModel.fromDocument);
  }

  Future<void> addComment({
    required String bookId,
    required String content,
    String? parentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para comentar.');
    }

    final commentRef = _booksCol.doc(bookId).collection('comments').doc();
    final comment = CommentModel(
      id: commentRef.id,
      userId: user.uid,
      userName: user.displayName ?? user.email ?? 'Usuario',
      userPhotoUrl: user.photoURL,
      content: content,
      createdAt: DateTime.now(),
      likes: 0,
      dislikes: 0,
      parentId: parentId,
    );

    await commentRef.set(comment.toMap());
  }

  Stream<List<CommentModel>> watchComments(String bookId) {
    return _booksCol
        .doc(bookId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromDocument(doc))
            .toList());
  }

  Future<void> addChapterComment({
    required String bookId,
    required int chapterOrder,
    required String content,
    String? parentId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para comentar.');
    }

    final chapterDoc = _booksCol
        .doc(bookId)
        .collection('chapters')
        .doc(chapterOrder.toString());

    await chapterDoc.set({'order': chapterOrder}, SetOptions(merge: true));

    final commentRef = chapterDoc.collection('comments').doc();
    final comment = CommentModel(
      id: commentRef.id,
      userId: user.uid,
      userName: user.displayName ?? user.email ?? 'Usuario',
      userPhotoUrl: user.photoURL,
      content: content,
      createdAt: DateTime.now(),
      likes: 0,
      dislikes: 0,
      parentId: parentId,
    );

    await commentRef.set(comment.toMap());
  }

  Stream<List<CommentModel>> watchChapterComments({
    required String bookId,
    required int chapterOrder,
  }) {
    return _booksCol
        .doc(bookId)
        .collection('chapters')
        .doc(chapterOrder.toString())
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromDocument(doc))
            .toList());
  }

  Future<void> incrementBookViews(String bookId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final bookRef = _booksCol.doc(bookId);
    final viewRef = bookRef.collection('views').doc(user.uid);

    await _firestore.runTransaction<void>((transaction) async {
      final viewSnap = await transaction.get(viewRef);
      if (viewSnap.exists) {
        return;
      }

      transaction.set(viewRef, {
        'viewedAt': FieldValue.serverTimestamp(),
      });
      transaction.update(bookRef, {'views': FieldValue.increment(1)});
    });
  }

  Future<void> updateBook({
    required String bookId,
    required String title,
    required String category,
    required List<ChapterEntity> chapters,
    required int publishedChapterOrder,
    String? description,
    File? coverFile,
    bool removeCover = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para editar un libro.');
    }

    final docRef = _booksCol.doc(bookId);
    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      throw Exception('El libro ya no está disponible.');
    }

    final current = BookModel.fromDocument(snapshot);
    if (current.authorId != user.uid) {
      throw Exception('No tienes permisos para editar este libro.');
    }

    String? coverUrl = current.coverUrl;
    String? coverBase64 = current.coverBase64;

    if (coverFile != null) {
      try {
        final storageRef = _storage.ref().child(
            'book_covers/$bookId/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(coverFile);
        coverUrl = await storageRef.getDownloadURL();
        coverBase64 = null;
      } on FirebaseException {
        coverUrl = null;
        coverBase64 = await _encodeCover(coverFile);
      } catch (_) {
        coverUrl = null;
        coverBase64 = await _encodeCover(coverFile);
      }
    } else if (removeCover) {
      coverUrl = null;
      coverBase64 = null;
    }

    final sortedChapters = List<ChapterEntity>.from(chapters)
      ..sort((a, b) => a.order.compareTo(b.order));
    final normalizedChapters = <ChapterEntity>[];
    for (var i = 0; i < sortedChapters.length; i++) {
      final chapter = sortedChapters[i];
      normalizedChapters.add(
        ChapterEntity(
          title: chapter.title,
          content: chapter.content,
          order: i,
          isPublished: false,
        ),
      );
    }

    if (normalizedChapters.isEmpty) {
      throw Exception('Debes mantener al menos un capítulo.');
    }

    final effectivePublishedOrder = publishedChapterOrder
        .clamp(0, normalizedChapters.length - 1)
        .toInt();

    final now = DateTime.now();
    final updateData = <String, dynamic>{
      'title': title,
      'category': category,
      'description': description,
      'coverUrl': coverUrl,
      'coverBase64': coverBase64,
      'chapters': normalizedChapters
          .map(
            (chapter) => {
              'title': chapter.title,
              'content': chapter.content,
              'order': chapter.order,
              'isPublished': chapter.order <= effectivePublishedOrder,
            },
          )
          .toList(),
      'publishedChapterOrder': effectivePublishedOrder,
      'updatedAt': Timestamp.fromDate(now),
    };

    await docRef.update(updateData);

    final chaptersCollection = docRef.collection('chapters');
    final existingChapters = await chaptersCollection.get();
    final newOrders =
        normalizedChapters.map((chapter) => chapter.order.toString()).toSet();

    for (final doc in existingChapters.docs) {
      if (!newOrders.contains(doc.id)) {
        await doc.reference.delete();
      }
    }

    for (final chapter in normalizedChapters) {
      await chaptersCollection.doc(chapter.order.toString()).set(
        {
          'title': chapter.title,
          'order': chapter.order,
          'isPublished': chapter.order <= effectivePublishedOrder,
          'updatedAt': now.toIso8601String(),
        },
        SetOptions(merge: true),
      );
    }
  }

  Future<BookReaction> reactToBook({
    required String bookId,
    required bool isLike,
    int delta = 1,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para reaccionar.');
    }

    final bookRef = _booksCol.doc(bookId);
    final reactionRef = bookRef.collection('reactions').doc(user.uid);
    final desired = isLike ? 'like' : 'dislike';

    final result = await _firestore.runTransaction<String?>(
      (transaction) async {
        final reactionSnap = await transaction.get(reactionRef);
    final current = reactionSnap.exists
      ? (reactionSnap.data()?['type'] as String?)
      : null;

        String? nextType;
        if (current == desired) {
          nextType = null;
        } else {
          nextType = desired;
        }

        int likeDelta = 0;
        int dislikeDelta = 0;
        if (current == 'like') likeDelta -= 1;
        if (current == 'dislike') dislikeDelta -= 1;
        if (nextType == 'like') likeDelta += 1;
        if (nextType == 'dislike') dislikeDelta += 1;

        final updates = <String, dynamic>{};
        if (likeDelta != 0) {
          updates['likes'] = FieldValue.increment(likeDelta);
        }
        if (dislikeDelta != 0) {
          updates['dislikes'] = FieldValue.increment(dislikeDelta);
        }
        if (updates.isNotEmpty) {
          transaction.update(bookRef, updates);
        }

        if (nextType == null) {
          if (reactionSnap.exists) {
            transaction.delete(reactionRef);
          }
        } else {
          transaction.set(reactionRef, {
            'type': nextType,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }

        return nextType;
      },
      maxAttempts: 3,
    );

    return BookReactionX.fromString(result);
  }

    Future<void> deleteBook(String bookId) async {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('Debes iniciar sesión para eliminar un libro.');
      }

      final docRef = _booksCol.doc(bookId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        return;
      }

      final current = BookModel.fromDocument(snapshot);
      if (current.authorId != user.uid) {
        throw Exception('No tienes permisos para eliminar este libro.');
      }

      await _deleteCollection(docRef.collection('comments'));
      await _deleteCollection(docRef.collection('reactions'));
      await _deleteCollection(docRef.collection('views'));
      await _deleteCollection(docRef.collection('userCommentReactions'));

      final chaptersSnapshot = await docRef.collection('chapters').get();
      for (final chapterDoc in chaptersSnapshot.docs) {
        await _deleteCollection(chapterDoc.reference.collection('comments'));
        await _deleteCollection(
            chapterDoc.reference.collection('userCommentReactions'));
        await chapterDoc.reference.delete();
      }

      await docRef.delete();
    }

    Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> reference,
    ) async {
      const batchSize = 20;
      while (true) {
        final snapshot = await reference.limit(batchSize).get();
        if (snapshot.docs.isEmpty) {
          break;
        }
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

  Future<BookReaction> getUserBookReaction(String bookId) async {
    final user = _auth.currentUser;
    if (user == null) {
      return BookReaction.none;
    }

    final doc = await _booksCol
        .doc(bookId)
        .collection('reactions')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      return BookReaction.none;
    }

    final type = doc.data()?['type'] as String?;
    return BookReactionX.fromString(type);
  }

  Future<BookReaction> reactToComment({
    required String bookId,
    required String commentId,
    required bool isLike,
    int? chapterOrder,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Debes iniciar sesión para reaccionar.');
    }

    final commentDoc = chapterOrder == null
        ? _booksCol.doc(bookId).collection('comments').doc(commentId)
        : _booksCol
            .doc(bookId)
            .collection('chapters')
            .doc(chapterOrder.toString())
            .collection('comments')
            .doc(commentId);

    final userReactionDoc = chapterOrder == null
        ? _booksCol
            .doc(bookId)
            .collection('userCommentReactions')
            .doc(user.uid)
        : _booksCol
            .doc(bookId)
            .collection('chapters')
            .doc(chapterOrder.toString())
            .collection('userCommentReactions')
            .doc(user.uid);

    final desired = isLike ? 'like' : 'dislike';

    final result = await _firestore.runTransaction<String?>((transaction) async {
      final commentSnap = await transaction.get(commentDoc);
      if (!commentSnap.exists) {
        throw Exception('El comentario ya no está disponible.');
      }

      final reactionSnap = await transaction.get(userReactionDoc);
      final currentMap = Map<String, dynamic>.from(
        (reactionSnap.data()?['reactions'] as Map<String, dynamic>?) ?? {},
      );

      final current = currentMap[commentId] as String?;
      final nextType = current == desired ? null : desired;

      var likeDelta = 0;
      var dislikeDelta = 0;
      if (current == 'like') likeDelta -= 1;
      if (current == 'dislike') dislikeDelta -= 1;
      if (nextType == 'like') likeDelta += 1;
      if (nextType == 'dislike') dislikeDelta += 1;

      final updates = <String, dynamic>{};
      if (likeDelta != 0) {
        updates['likes'] = FieldValue.increment(likeDelta);
      }
      if (dislikeDelta != 0) {
        updates['dislikes'] = FieldValue.increment(dislikeDelta);
      }
      if (updates.isNotEmpty) {
        transaction.update(commentDoc, updates);
      }

      if (nextType == null) {
        currentMap.remove(commentId);
      } else {
        currentMap[commentId] = nextType;
      }

      if (currentMap.isEmpty) {
        transaction.delete(userReactionDoc);
      } else {
        transaction.set(
          userReactionDoc,
          {
            'reactions': currentMap,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      return nextType;
    }, maxAttempts: 3);

    return BookReactionX.fromString(result);
  }

  Future<Map<String, BookReaction>> getUserCommentReactions({
    required String bookId,
    int? chapterOrder,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return {};
    }

    final docRef = chapterOrder == null
        ? _booksCol
            .doc(bookId)
            .collection('userCommentReactions')
            .doc(user.uid)
        : _booksCol
            .doc(bookId)
            .collection('chapters')
            .doc(chapterOrder.toString())
            .collection('userCommentReactions')
            .doc(user.uid);

    final snapshot = await docRef.get();
    if (!snapshot.exists) {
      return {};
    }

    final data = snapshot.data();
    if (data == null) {
      return {};
    }

    final reactions = (data['reactions'] as Map<String, dynamic>? ?? {});
    return reactions.map(
      (key, value) => MapEntry(key, BookReactionX.fromString(value as String?)),
    );
  }
}
