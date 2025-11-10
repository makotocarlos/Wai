import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OfflineDatabase {
  static final OfflineDatabase instance = OfflineDatabase._internal();
  static Database? _database;

  OfflineDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wai_offline.db');

    return await openDatabase(
      path,
      version: 2, // 🔥 INCREMENTAR versión para agregar nuevas tablas
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de libros
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        author_id TEXT NOT NULL,
        author_name TEXT NOT NULL,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        cover_path TEXT,
        published_chapter_index INTEGER DEFAULT -1,
        views_count INTEGER DEFAULT 0,
        likes_count INTEGER DEFAULT 0,
        dislikes_count INTEGER DEFAULT 0,
        favorites_count INTEGER DEFAULT 0,
        comments_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        user_reaction TEXT,
        is_favorite INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0,
        last_modified INTEGER
      )
    ''');

    // Tabla de capítulos
    await db.execute('''
      CREATE TABLE chapters (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        chapter_order INTEGER NOT NULL,
        is_published INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        last_modified INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de favoritos
    await db.execute('''
      CREATE TABLE favorites (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        book_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Tabla de perfiles
    await db.execute('''
      CREATE TABLE profiles (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT,
        avatar_url TEXT,
        followers_count INTEGER DEFAULT 0,
        following_count INTEGER DEFAULT 0,
        favorites_count INTEGER DEFAULT 0,
        books_count INTEGER DEFAULT 0,
        is_current_user INTEGER DEFAULT 0,
        favorites_private INTEGER DEFAULT 0,
        books_private INTEGER DEFAULT 0,
        followers_private INTEGER DEFAULT 0,
        following_private INTEGER DEFAULT 0,
        cached_at INTEGER NOT NULL
      )
    ''');

    // Tabla de hilos de chat
    await db.execute('''
      CREATE TABLE chat_threads (
        id TEXT PRIMARY KEY,
        participant_id TEXT NOT NULL,
        participant_username TEXT NOT NULL,
        participant_avatar_url TEXT,
        last_message_content TEXT,
        last_message_at INTEGER,
        unread_count INTEGER DEFAULT 0,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Tabla de mensajes de chat
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        thread_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (thread_id) REFERENCES chat_threads (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de cola de sincronización
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        retry_count INTEGER DEFAULT 0
      )
    ''');

    // 🔥 Tabla de comentarios
    await db.execute('''
      CREATE TABLE comments (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        chapter_id TEXT,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        avatar_url TEXT,
        content TEXT NOT NULL,
        parent_id TEXT,
        likes_count INTEGER DEFAULT 0,
        replies_count INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        last_modified INTEGER,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 🔥 Tabla de likes en comentarios
    await db.execute('''
      CREATE TABLE comment_likes (
        id TEXT PRIMARY KEY,
        comment_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (comment_id) REFERENCES comments (id) ON DELETE CASCADE
      )
    ''');

    // 🔥 Tabla de reacciones a libros (likes/dislikes)
    await db.execute('''
      CREATE TABLE book_reactions (
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        reaction_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // 🔥 Tabla de seguidores
    await db.execute('''
      CREATE TABLE followers (
        id TEXT PRIMARY KEY,
        follower_id TEXT NOT NULL,
        following_id TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        is_synced INTEGER DEFAULT 0
      )
    ''');

    // Índices para mejorar performance
    await db.execute('CREATE INDEX idx_books_author ON books(author_id)');
    await db.execute('CREATE INDEX idx_chapters_book ON chapters(book_id)');
    await db.execute('CREATE INDEX idx_favorites_user ON favorites(user_id)');
    await db.execute('CREATE INDEX idx_favorites_book ON favorites(book_id)');
    await db.execute('CREATE INDEX idx_chat_messages_thread ON chat_messages(thread_id)');
    await db.execute('CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id)');
    await db.execute('CREATE INDEX idx_comments_book ON comments(book_id)');
    await db.execute('CREATE INDEX idx_comments_chapter ON comments(chapter_id)');
    await db.execute('CREATE INDEX idx_comments_parent ON comments(parent_id)');
    await db.execute('CREATE INDEX idx_comment_likes_comment ON comment_likes(comment_id)');
    await db.execute('CREATE INDEX idx_comment_likes_user ON comment_likes(user_id)');
    await db.execute('CREATE INDEX idx_book_reactions_book ON book_reactions(book_id)');
    await db.execute('CREATE INDEX idx_book_reactions_user ON book_reactions(user_id)');
    await db.execute('CREATE INDEX idx_followers_follower ON followers(follower_id)');
    await db.execute('CREATE INDEX idx_followers_following ON followers(following_id)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Aquí manejaremos migraciones futuras
    if (oldVersion < 2) {
      // 🔥 Migración de versión 1 a 2: Agregar tablas de comentarios, likes, etc.
      
      // Tabla de comentarios
      await db.execute('''
        CREATE TABLE IF NOT EXISTS comments (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          chapter_id TEXT,
          user_id TEXT NOT NULL,
          username TEXT NOT NULL,
          avatar_url TEXT,
          content TEXT NOT NULL,
          parent_id TEXT,
          likes_count INTEGER DEFAULT 0,
          replies_count INTEGER DEFAULT 0,
          created_at INTEGER NOT NULL,
          is_synced INTEGER DEFAULT 0,
          last_modified INTEGER,
          FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
        )
      ''');

      // Tabla de likes en comentarios
      await db.execute('''
        CREATE TABLE IF NOT EXISTS comment_likes (
          id TEXT PRIMARY KEY,
          comment_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (comment_id) REFERENCES comments (id) ON DELETE CASCADE
        )
      ''');

      // Tabla de reacciones a libros
      await db.execute('''
        CREATE TABLE IF NOT EXISTS book_reactions (
          id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          reaction_type TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_synced INTEGER DEFAULT 0,
          FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
        )
      ''');

      // Tabla de seguidores
      await db.execute('''
        CREATE TABLE IF NOT EXISTS followers (
          id TEXT PRIMARY KEY,
          follower_id TEXT NOT NULL,
          following_id TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          is_synced INTEGER DEFAULT 0
        )
      ''');

      // Índices
      await db.execute('CREATE INDEX IF NOT EXISTS idx_comments_book ON comments(book_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_comments_chapter ON comments(chapter_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_comments_parent ON comments(parent_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_comment_likes_comment ON comment_likes(comment_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_comment_likes_user ON comment_likes(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_book_reactions_book ON book_reactions(book_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_book_reactions_user ON book_reactions(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_followers_follower ON followers(follower_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_followers_following ON followers(following_id)');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('books');
    await db.delete('chapters');
    await db.delete('favorites');
    await db.delete('profiles');
    await db.delete('chat_threads');
    await db.delete('chat_messages');
    await db.delete('comments');
    await db.delete('comment_likes');
    await db.delete('book_reactions');
    await db.delete('followers');
    await db.delete('sync_queue');
  }
}
