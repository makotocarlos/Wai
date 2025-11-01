-- =====================================================
-- HABILITAR REALTIME EN TABLAS DE LIBROS
-- =====================================================
-- Ejecuta este script en el SQL Editor de Supabase
-- para habilitar actualizaciones en tiempo real
-- =====================================================

-- Habilitar Realtime en la tabla de libros
ALTER PUBLICATION supabase_realtime ADD TABLE books;

-- Habilitar Realtime en la tabla de capítulos
ALTER PUBLICATION supabase_realtime ADD TABLE book_chapters;

-- Habilitar Realtime en la tabla de comentarios
ALTER PUBLICATION supabase_realtime ADD TABLE book_comments;

-- Habilitar Realtime en la tabla de reacciones
ALTER PUBLICATION supabase_realtime ADD TABLE book_reactions;

-- Habilitar Realtime en la tabla de vistas
ALTER PUBLICATION supabase_realtime ADD TABLE book_views;

-- =====================================================
-- NOTA: Después de ejecutar este script:
-- 1. Los cambios en las tablas se propagarán automáticamente
-- 2. No necesitarás recargar la aplicación
-- 3. Los nuevos libros aparecerán inmediatamente en Home
-- =====================================================
