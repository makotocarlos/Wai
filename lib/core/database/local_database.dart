import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Base de datos local para guardar borradores de libros offline
class LocalDatabase {
	static final LocalDatabase instance = LocalDatabase._internal();
	static Database? _database;

	LocalDatabase._internal();

	Future<Database> get database async {
		if (_database != null) return _database!;
		_database = await _initDatabase();
		return _database!;
	}

	Future<Database> _initDatabase() async {
		final dbPath = await getDatabasesPath();
		final path = join(dbPath, 'wai_drafts.db');

		return openDatabase(
			path,
			version: 1,
			onCreate: _onCreate,
		);
	}

	Future<void> _onCreate(Database db, int version) async {
		// Tabla de borradores de libros
		await db.execute('''
			CREATE TABLE book_drafts (
				id TEXT PRIMARY KEY,
				author_id TEXT NOT NULL,
				author_name TEXT NOT NULL,
				title TEXT NOT NULL,
				category TEXT NOT NULL,
				description TEXT,
				cover_path TEXT,
				published_chapter_index INTEGER DEFAULT 0,
				created_at INTEGER NOT NULL,
				updated_at INTEGER NOT NULL
			)
		''');

		// Tabla de capítulos de borradores
		await db.execute('''
			CREATE TABLE chapter_drafts (
				id TEXT PRIMARY KEY,
				book_draft_id TEXT NOT NULL,
				chapter_order INTEGER NOT NULL,
				title TEXT NOT NULL,
				content TEXT NOT NULL,
				created_at INTEGER NOT NULL,
				updated_at INTEGER NOT NULL,
				FOREIGN KEY (book_draft_id) REFERENCES book_drafts (id) ON DELETE CASCADE
			)
		''');

		// Índices para mejorar búsquedas
		await db.execute(
			'CREATE INDEX idx_book_drafts_author ON book_drafts(author_id)',
		);
		await db.execute(
			'CREATE INDEX idx_chapter_drafts_book ON chapter_drafts(book_draft_id)',
		);
	}

	// ===== CRUD para Book Drafts =====

	Future<String> saveDraft({
		required String id,
		required String authorId,
		required String authorName,
		required String title,
		required String category,
		String? description,
		String? coverPath,
		int publishedChapterIndex = 0,
		List<Map<String, dynamic>>? chapters,
	}) async {
		final db = await database;
		final now = DateTime.now().millisecondsSinceEpoch;

		// Guardar libro borrador
		await db.insert(
			'book_drafts',
			{
				'id': id,
				'author_id': authorId,
				'author_name': authorName,
				'title': title,
				'category': category,
				'description': description,
				'cover_path': coverPath,
				'published_chapter_index': publishedChapterIndex,
				'created_at': now,
				'updated_at': now,
			},
			conflictAlgorithm: ConflictAlgorithm.replace,
		);

		// Eliminar capítulos antiguos
		await db.delete(
			'chapter_drafts',
			where: 'book_draft_id = ?',
			whereArgs: [id],
		);

		// Guardar capítulos
		if (chapters != null && chapters.isNotEmpty) {
			for (final chapter in chapters) {
				await db.insert(
					'chapter_drafts',
					{
						'id': chapter['id'] as String,
						'book_draft_id': id,
						'chapter_order': chapter['order'] as int,
						'title': chapter['title'] as String,
						'content': chapter['content'] as String,
						'created_at': now,
						'updated_at': now,
					},
					conflictAlgorithm: ConflictAlgorithm.replace,
				);
			}
		}

		return id;
	}

	Future<Map<String, dynamic>?> getDraft(String id) async {
		final db = await database;

		// Obtener borrador de libro
		final books = await db.query(
			'book_drafts',
			where: 'id = ?',
			whereArgs: [id],
		);

		if (books.isEmpty) return null;

		final book = books.first;

		// Obtener capítulos
		final chapters = await db.query(
			'chapter_drafts',
			where: 'book_draft_id = ?',
			whereArgs: [id],
			orderBy: 'chapter_order ASC',
		);

		return {
			...book,
			'chapters': chapters,
		};
	}

	Future<List<Map<String, dynamic>>> getAllDrafts(String authorId) async {
		final db = await database;

		final books = await db.query(
			'book_drafts',
			where: 'author_id = ?',
			whereArgs: [authorId],
			orderBy: 'updated_at DESC',
		);

		final result = <Map<String, dynamic>>[];

		for (final book in books) {
			final chapters = await db.query(
				'chapter_drafts',
				where: 'book_draft_id = ?',
				whereArgs: [book['id']],
				orderBy: 'chapter_order ASC',
			);

			result.add({
				...book,
				'chapters': chapters,
			});
		}

		return result;
	}

	Future<void> deleteDraft(String id) async {
		final db = await database;
		await db.delete(
			'book_drafts',
			where: 'id = ?',
			whereArgs: [id],
		);
		// Los capítulos se eliminan automáticamente por CASCADE
	}

	Future<void> updateDraft({
		required String id,
		String? title,
		String? category,
		String? description,
		String? coverPath,
		int? publishedChapterIndex,
	}) async {
		final db = await database;
		final now = DateTime.now().millisecondsSinceEpoch;

		final updateData = <String, dynamic>{
			'updated_at': now,
		};

		if (title != null) updateData['title'] = title;
		if (category != null) updateData['category'] = category;
		if (description != null) updateData['description'] = description;
		if (coverPath != null) updateData['cover_path'] = coverPath;
		if (publishedChapterIndex != null) {
			updateData['published_chapter_index'] = publishedChapterIndex;
		}

		await db.update(
			'book_drafts',
			updateData,
			where: 'id = ?',
			whereArgs: [id],
		);
	}

	Future<void> clearAllDrafts() async {
		final db = await database;
		await db.delete('book_drafts');
		await db.delete('chapter_drafts');
	}
}
