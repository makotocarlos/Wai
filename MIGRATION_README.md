# Migración: Sistema de Publicación por Capítulo

## Estado Actual

El código está configurado para funcionar **ANTES y DESPUÉS** de la migración:

✅ **ANTES de migrar**: Usa `publishedChapterIndex` (sistema antiguo)
✅ **DESPUÉS de migrar**: Usa `is_published` por capítulo (sistema nuevo)

## Pasos para Migrar

### 1. Ejecutar SQL en Supabase

1. Ve a tu proyecto en Supabase: https://supabase.com/dashboard
2. Abre el **SQL Editor**
3. Copia y pega el contenido de `MIGRATION_is_published.sql`
4. Presiona **Run** (F5)
5. Verifica que la migración fue exitosa revisando la tabla de resultados

### 2. Activar el Nuevo Sistema en el Código

Una vez ejecutada la migración SQL, descomentar estas líneas:

#### En `books_repository_impl.dart`:

**Línea ~110** (createBook):
```dart
// Cambiar de:
// 'is_published': true, // Comentado temporalmente

// A:
'is_published': true, // Todos los capítulos se marcan como publicados al crear
```

**Línea ~655** (updateBook - nuevos capítulos):
```dart
// Cambiar de:
// 'is_published': false, // Comentado temporalmente

// A:
'is_published': false, // Nuevos capítulos NO publicados por defecto
```

**Línea ~673** (updateBook - actualizar existentes):
```dart
// Cambiar de:
// 'is_published': chapter.isPublished, // Comentado temporalmente

// A:
'is_published': chapter.isPublished, // Actualizar estado de publicación
```

### 3. Verificar Funcionamiento

Después de la migración:

1. Abre la app
2. Ve a "Biblioteca"
3. Edita un libro existente
4. Deberías ver badges "Publicado" en capítulos existentes
5. Agrega un nuevo capítulo → debería aparecer SIN badge
6. Presiona "Publicar" en el capítulo nuevo
7. Guarda cambios
8. Verifica que los lectores puedan ver el nuevo capítulo

## Errores Conocidos

### Error: "databaseFactory not initialized"
**Causa**: SQLite local solo funciona en móviles, no en desktop/web
**Solución**: El auto-save falla silenciosamente en desktop (no es crítico)
**Fix permanente** (opcional): Agregar `sqflite_common_ffi` para desktop

### Error: "PostgreSQL 406 - not acceptable"
**Causa**: La columna `is_published` no existe aún en Supabase
**Solución**: Ejecutar la migración SQL (paso 1)

## Rollback (si algo sale mal)

Si necesitas revertir la migración:

```sql
-- Eliminar la columna is_published
ALTER TABLE book_chapters DROP COLUMN IF EXISTS is_published;
```

Luego el código automáticamente volverá a usar `publishedChapterIndex`.

## Compatibilidad

El código actual tiene **doble compatibilidad**:

```dart
// Funciona con ambos sistemas
final publishedChapters = book.chapters.where((chapter) => 
  chapter.isPublished || // Sistema nuevo (si está disponible)
  chapter.order <= book.publishedChapterIndex + 1 // Sistema antiguo (fallback)
).toList();
```

Esto significa que la app funcionará correctamente incluso si algunos usuarios tienen la columna `is_published` y otros no.
