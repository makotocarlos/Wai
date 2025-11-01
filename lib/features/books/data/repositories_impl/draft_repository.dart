import 'package:uuid/uuid.dart';

import '../../../../core/database/local_database.dart';
import '../../domain/entities/chapter_entity.dart';

/// Repositorio para manejar borradores locales
class DraftRepository {
	DraftRepository({required LocalDatabase database}) : _database = database;

	final LocalDatabase _database;
	final _uuid = const Uuid();

	/// Guardar un borrador completo
	Future<String> saveDraft({
		String? id,
		required String authorId,
		required String authorName,
		required String title,
		required String category,
		String? description,
		String? coverPath,
		int publishedChapterIndex = 0,
		List<ChapterEntity> chapters = const [],
	}) async {
		final draftId = id ?? _uuid.v4();

		await _database.saveDraft(
			id: draftId,
			authorId: authorId,
			authorName: authorName,
			title: title,
			category: category,
			description: description,
			coverPath: coverPath,
			publishedChapterIndex: publishedChapterIndex,
			chapters: chapters
				.map((ch) => {
					'id': ch.id.isEmpty ? _uuid.v4() : ch.id,
					'order': ch.order,
					'title': ch.title,
					'content': ch.content,
				})
				.toList(),
		);

		return draftId;
	}

	/// Obtener un borrador por ID
	Future<Map<String, dynamic>?> getDraft(String id) async {
		return _database.getDraft(id);
	}

	/// Obtener todos los borradores de un autor
	Future<List<Map<String, dynamic>>> getUserDrafts(String authorId) async {
		return _database.getAllDrafts(authorId);
	}

	/// Eliminar un borrador
	Future<void> deleteDraft(String id) async {
		await _database.deleteDraft(id);
	}

	/// Actualizar información del borrador
	Future<void> updateDraft({
		required String id,
		String? title,
		String? category,
		String? description,
		String? coverPath,
		int? publishedChapterIndex,
	}) async {
		await _database.updateDraft(
			id: id,
			title: title,
			category: category,
			description: description,
			coverPath: coverPath,
			publishedChapterIndex: publishedChapterIndex,
		);
	}

	/// Limpiar todos los borradores
	Future<void> clearAll() async {
		await _database.clearAllDrafts();
	}
}
