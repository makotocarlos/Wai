-- =====================================================
-- AGREGAR COLUMNA DE AVATAR A COMENTARIOS
-- =====================================================
-- Ejecuta este script en el SQL Editor de Supabase
-- =====================================================

-- Agregar columna user_avatar_url a book_comments
ALTER TABLE book_comments 
ADD COLUMN IF NOT EXISTS user_avatar_url TEXT;

-- =====================================================
-- NOTA: Después de ejecutar este script:
-- 1. Los comentarios nuevos guardarán la foto de perfil
-- 2. Los comentarios antiguos tendrán NULL (se mostrará inicial)
-- 3. La UI mostrará automáticamente la foto de perfil real
-- =====================================================
