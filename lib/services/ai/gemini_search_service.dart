import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../features/books/domain/entities/book_entity.dart';

/// Valores de respaldo solo para demostraciones locales. Rellena `kGeminiFallbackKey`
/// con tu API key y elimínalo antes de compartir el proyecto.
const String kGeminiFallbackKey = 'AIzaSyBRLTzVVMHNKS2pAzBG4uISNZ4DELFTzQU';
const String kGeminiFallbackModel = 'gemini-2.5-flash';

class GeminiSearchResult {
  const GeminiSearchResult({
    required this.message,
    required this.bookIds,
  });

  final String message;
  final List<String> bookIds;
}

class ChapterProofreadingResult {
  const ChapterProofreadingResult({
    required this.correctedText,
    required this.notes,
    this.summary,
  });

  final String correctedText;
  final List<String> notes;
  final String? summary;
}

class ChapterStoryContext {
  const ChapterStoryContext({
    required this.bookTitle,
    required this.chapterTitle,
    required this.chapterContent,
    this.synopsis,
    this.previousChapters = const [],
    this.readerComments = const [],
  });

  final String bookTitle;
  final String chapterTitle;
  final String chapterContent;
  final String? synopsis;
  final List<String> previousChapters;
  final List<String> readerComments;
}

class ChapterChatTurn {
  const ChapterChatTurn({
    required this.role,
    required this.message,
  });

  const ChapterChatTurn.user(String message)
      : this(role: ChapterChatRole.user, message: message);

  const ChapterChatTurn.assistant(String message)
      : this(role: ChapterChatRole.assistant, message: message);

  final ChapterChatRole role;
  final String message;
}

enum ChapterChatRole { user, assistant }

class ChapterChatReply {
  const ChapterChatReply({
    required this.reply,
    this.ideas = const [],
    this.suggestedNextSteps = const [],
  });

  final String reply;
  final List<String> ideas;
  final List<String> suggestedNextSteps;
}

class GeminiNotConfiguredException implements Exception {}

class GeminiSearchFailure implements Exception {
  GeminiSearchFailure(this.message);

  final String message;

  @override
  String toString() => 'GeminiSearchFailure: $message';
}

class GeminiSearchService {
  factory GeminiSearchService({
    GenerativeModel? model,
    String? apiKey,
    String? modelName,
  }) {
    final resolvedKey = _resolveKey(apiKey);
    final resolvedModelName = _resolveModelName(modelName);
    return GeminiSearchService._(
      model: model,
      apiKey: resolvedKey,
      modelName: resolvedModelName,
    );
  }

  GeminiSearchService._({
    GenerativeModel? model,
    required String apiKey,
    required String modelName,
  })  : _apiKey = apiKey,
        _modelName = modelName,
        _model = model ?? _buildModel(apiKey, modelName);

  static const String _defaultModel = 'gemini-2.5-flash';

  final String _apiKey;
  final String _modelName;
  final GenerativeModel? _model;

  bool get isConfigured => _model != null && _apiKey.isNotEmpty;

  Future<GeminiSearchResult> generateRecommendation({
    required String prompt,
    required List<BookEntity> candidates,
    List<BookEntity> favoriteBooks = const [],
    List<BookEntity> userBooks = const [],
  }) async {
    if (!isConfigured) {
      throw GeminiNotConfiguredException();
    }

    if (prompt.trim().isEmpty) {
      throw GeminiSearchFailure('El mensaje de busqueda esta vacio.');
    }

    final limitedCatalog = candidates.take(25).toList(growable: false);
    final limitedFavorites = favoriteBooks.take(10).toList(growable: false);
    final limitedUserBooks = userBooks.take(10).toList(growable: false);

    final buffer = StringBuffer()
      ..writeln(
          'Contexto de libros disponibles (usa los IDs para las respuestas):');

    if (limitedCatalog.isEmpty) {
      buffer.writeln('Sin libros en el catalogo actual.');
    } else {
      for (final book in limitedCatalog) {
        buffer
          ..writeln('ID: ${book.id}')
          ..writeln('Titulo: ${book.title}')
          ..writeln('Autor: ${book.authorName}')
          ..writeln('Categoria: ${book.category}')
          ..writeln('CapitulosPublicados: ${book.publishedChapterIndex + 1}')
          ..writeln('Likes: ${book.likeCount}')
          ..writeln('Vistas: ${book.viewCount}')
          ..writeln('Favoritos: ${book.favoritesCount}')
          ..writeln('Descripcion: ${_sanitizeDescription(book.description)}')
          ..writeln('---');
      }
    }

    if (limitedFavorites.isNotEmpty) {
      buffer.writeln('Favoritos del usuario:');
      for (final book in limitedFavorites) {
        buffer
          ..writeln(
              '- ${book.title} (ID: ${book.id}, Categoria: ${book.category})');
      }
    }

    if (limitedUserBooks.isNotEmpty) {
      buffer.writeln('Libros creados por el usuario:');
      for (final book in limitedUserBooks) {
        buffer
          ..writeln(
              '- ${book.title} (ID: ${book.id}, Categoria: ${book.category})');
      }
    }

    final instructions = Content.text(
      'Eres un asistente que recomienda libros del catalogo. '
      'El usuario dira lo que busca. Usa solo los libros listados en el contexto. '
      'Responde estrictamente en formato JSON con las claves "message" y "book_ids" (array de strings). '
      'Si no hay coincidencias deja "book_ids" vacio y explica en "message" como ajustaste la busqueda.',
    );

    final catalogContent = Content.text(buffer.toString());
    final userPrompt = Content.text('Solicitud del usuario: ${prompt.trim()}');

    try {
      final response = await _model!.generateContent([
        instructions,
        catalogContent,
        userPrompt,
      ]);

      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) {
        throw GeminiSearchFailure('La respuesta de Gemini fue vacia.');
      }

      final jsonPayload = _extractJson(raw);
      final Map<String, dynamic> map =
          json.decode(jsonPayload) as Map<String, dynamic>;
      final message = map['message']?.toString() ?? raw.trim();
      final ids = (map['book_ids'] as List<dynamic>? ?? const [])
          .map((dynamic id) => id.toString())
          .where((id) => id.isNotEmpty)
          .toList(growable: false);

      return GeminiSearchResult(
        message: message,
        bookIds: ids,
      );
    } on GenerativeAIException catch (error) {
      final message = error.message;
      if (message.contains('not found')) {
        throw GeminiSearchFailure(
          'Gemini no encontro el modelo "$_modelName". Ajusta GEMINI_MODEL (ej. gemini-1.0-pro) o revisa tu API key.',
        );
      }
      if (message.contains('not supported')) {
        throw GeminiSearchFailure(
          'Gemini indico que el modelo "$_modelName" no soporta generateContent. Prueba con gemini-1.0-pro o actualiza GEMINI_MODEL.',
        );
      }
      throw GeminiSearchFailure('Gemini rechazo la solicitud: $message');
    } on FormatException {
      throw GeminiSearchFailure(
          'No pudimos interpretar la respuesta de Gemini.');
    }
  }

  Future<ChapterProofreadingResult> proofreadChapter({
    required String bookTitle,
    required String chapterTitle,
    required String chapterContent,
    List<String> previousChapters = const [],
    String? synopsis,
  }) async {
    if (!isConfigured) {
      throw GeminiNotConfiguredException();
    }

    final instructions = Content.text(
      'Eres un editor profesional en español. Revisa ortografía, gramática, puntuación y coherencia '
      'del capítulo proporcionado. Responde únicamente en JSON con las claves "corrected_text", '
      '"notes" (lista de observaciones y sugerencias) y "summary" (máximo 3 frases). '
      'Mantén la voz y estilo del texto. No inventes contenido si no es necesario.',
    );

    final buffer = StringBuffer()
      ..writeln('Titulo del libro: $bookTitle')
      ..writeln('Titulo del capitulo: $chapterTitle');

    if (synopsis != null && synopsis.trim().isNotEmpty) {
      buffer
        ..writeln('Sinopsis breve:')
        ..writeln(_limitText(synopsis.trim(), 1200));
    }

    if (previousChapters.isNotEmpty) {
      buffer.writeln('Resumen de capitulos anteriores:');
      for (var i = 0; i < previousChapters.length; i++) {
        final content = previousChapters[i];
        if (content.trim().isEmpty) continue;
        buffer
          ..writeln('Capitulo previo ${i + 1}:')
          ..writeln(_limitText(content, 1500))
          ..writeln('---');
      }
    }

    buffer
      ..writeln('Contenido a corregir:')
      ..writeln(_limitText(chapterContent, 6000));

    try {
      final response = await _model!.generateContent([
        instructions,
        Content.text(buffer.toString()),
      ]);

      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) {
        throw GeminiSearchFailure('La respuesta de Gemini fue vacia.');
      }

      final payload = _extractJson(raw);
      final map = json.decode(payload) as Map<String, dynamic>;

      final corrected =
          map['corrected_text']?.toString().trim() ?? chapterContent;
      final notes = (map['notes'] as List<dynamic>? ?? const [])
          .map((dynamic note) => note.toString())
          .where((note) => note.isNotEmpty)
          .toList(growable: false);
      final summary = map['summary']?.toString().trim();

      return ChapterProofreadingResult(
        correctedText: corrected.isEmpty ? chapterContent : corrected,
        notes: notes,
        summary: summary?.isEmpty == true ? null : summary,
      );
    } on GenerativeAIException catch (error) {
      throw GeminiSearchFailure(
          'Gemini rechazo la solicitud: ${error.message}');
    } on FormatException {
      throw GeminiSearchFailure(
          'No pudimos interpretar la respuesta de Gemini.');
    }
  }

  Future<ChapterChatReply> chatAboutChapter({
    required String prompt,
    required ChapterStoryContext context,
    List<ChapterChatTurn> history = const [],
  }) async {
    if (!isConfigured) {
      throw GeminiNotConfiguredException();
    }

    final instructions = Content.text(
      'Actua como un escritor asistente que ayuda a mejorar capítulos de novelas en español. '
      'Analiza el contexto y ofrece sugerencias concretas, ideas y comentarios útiles. '
      'Responde estrictamente en JSON con las claves "reply" (texto principal), '
      '"ideas" (lista de posibles giros o mejoras) y "next_steps" (lista corta de acciones recomendadas). '
      'Mantén un tono motivador y enfocado en la historia proporcionada.',
    );

    final contextBuffer = StringBuffer()
      ..writeln('Titulo del libro: ${context.bookTitle}')
      ..writeln('Titulo del capitulo: ${context.chapterTitle}');

    if (context.synopsis != null && context.synopsis!.trim().isNotEmpty) {
      contextBuffer
        ..writeln('Sinopsis del libro:')
        ..writeln(_limitText(context.synopsis!.trim(), 1200))
        ..writeln('---');
    }

    if (context.previousChapters.isNotEmpty) {
      contextBuffer.writeln('Fragmentos de capitulos anteriores:');
      for (var i = 0; i < context.previousChapters.length; i++) {
        final content = context.previousChapters[i];
        if (content.trim().isEmpty) continue;
        contextBuffer
          ..writeln('Capitulo ${i + 1}:')
          ..writeln(_limitText(content, 1200))
          ..writeln('---');
      }
    }

    contextBuffer
      ..writeln('Capitulo actual:')
      ..writeln(_limitText(context.chapterContent, 6000));

    if (context.readerComments.isNotEmpty) {
      contextBuffer.writeln('Comentarios de lectores relevantes:');
      for (final comment in context.readerComments.take(10)) {
        contextBuffer..writeln('- ${_limitText(comment, 400)}');
      }
    }

    if (history.isNotEmpty) {
      contextBuffer.writeln('Historial de conversación:');
      final window =
          history.length > 8 ? history.sublist(history.length - 8) : history;
      for (final turn in window) {
        final speaker =
            turn.role == ChapterChatRole.user ? 'Usuario' : 'Asistente';
        contextBuffer..writeln('$speaker: ${_limitText(turn.message, 1000)}');
      }
    }

    contextBuffer
      ..writeln('Nueva consulta del usuario:')
      ..writeln(_limitText(prompt, 1200));

    try {
      final response = await _model!.generateContent([
        instructions,
        Content.text(contextBuffer.toString()),
      ]);

      final raw = response.text;
      if (raw == null || raw.trim().isEmpty) {
        throw GeminiSearchFailure('La respuesta de Gemini fue vacia.');
      }

      final payload = _extractJson(raw);
      final map = json.decode(payload) as Map<String, dynamic>;

      final reply = map['reply']?.toString().trim() ?? raw.trim();
      final ideas = (map['ideas'] as List<dynamic>? ?? const [])
          .map((dynamic idea) => idea.toString())
          .where((idea) => idea.isNotEmpty)
          .toList(growable: false);
      final nextSteps = (map['next_steps'] as List<dynamic>? ?? const [])
          .map((dynamic step) => step.toString())
          .where((step) => step.isNotEmpty)
          .toList(growable: false);

      return ChapterChatReply(
        reply: reply,
        ideas: ideas,
        suggestedNextSteps: nextSteps,
      );
    } on GenerativeAIException catch (error) {
      final message = error.message ?? error.toString();
      if (message.contains('not found')) {
        throw GeminiSearchFailure(
          'Gemini no encontro el modelo "$_modelName". Ajusta GEMINI_MODEL (ej. gemini-2.5-flash) o revisa tu API key.',
        );
      }
      if (message.contains('not supported')) {
        throw GeminiSearchFailure(
          'Gemini indico que el modelo "$_modelName" no soporta generateContent. Prueba con gemini-2.5-flash o actualiza GEMINI_MODEL.',
        );
      }
      throw GeminiSearchFailure('Gemini rechazo la solicitud: $message');
    } on FormatException {
      throw GeminiSearchFailure(
          'No pudimos interpretar la respuesta de Gemini.');
    }
  }

  static String _resolveKey(String? candidate) {
    if (candidate != null && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }

    final envKey =
        dotenv.isInitialized ? dotenv.maybeGet('GEMINI_API_KEY')?.trim() : null;
    if (envKey != null && envKey.isNotEmpty) {
      return envKey;
    }

    final defineKey = const String.fromEnvironment('GEMINI_API_KEY').trim();
    if (defineKey.isNotEmpty) {
      return defineKey;
    }

    final fallback = kGeminiFallbackKey.trim();
    return fallback;
  }

  static String _resolveModelName(String? candidate) {
    if (candidate != null && candidate.trim().isNotEmpty) {
      return candidate.trim();
    }

    final envModel =
        dotenv.isInitialized ? dotenv.maybeGet('GEMINI_MODEL')?.trim() : null;
    if (envModel != null && envModel.isNotEmpty) {
      return envModel;
    }

    final defineModel = const String.fromEnvironment('GEMINI_MODEL').trim();
    if (defineModel.isNotEmpty) {
      return defineModel;
    }

    final fallback = kGeminiFallbackModel.trim();
    if (fallback.isNotEmpty) {
      return fallback;
    }

    return _defaultModel;
  }

  static GenerativeModel? _buildModel(String key, String modelName) {
    if (key.isEmpty) {
      return null;
    }
    final effectiveModel =
        modelName.trim().isEmpty ? _defaultModel : modelName.trim();
    return GenerativeModel(model: effectiveModel, apiKey: key);
  }

  static String _sanitizeDescription(String value) {
    final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.length <= 180) {
      return trimmed;
    }
    return '${trimmed.substring(0, 177)}...';
  }

  static String _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException(
          'JSON no encontrado en la respuesta de Gemini');
    }
    final snippet = raw.substring(start, end + 1).trim();
    return snippet.replaceAll('```', '');
  }

  static String _limitText(String value, int maxChars) {
    final trimmed = value.trim();
    if (trimmed.length <= maxChars) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxChars - 3)}...';
  }
}
