-- =====================================================
-- VERIFICAR ESQUEMA DE book_comments
-- =====================================================
-- Ejecuta esto en Supabase SQL Editor para ver las columnas

SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'book_comments'
ORDER BY ordinal_position;

-- =====================================================
-- SI LA COLUMNA SE LLAMA 'username' EN VEZ DE 'user_name'
-- EJECUTA ESTE ALTER:
-- =====================================================

-- ALTER TABLE book_comments RENAME COLUMN username TO user_name;

-- =====================================================
-- O SI NO EXISTE, CRÉALA:
-- =====================================================

-- ALTER TABLE book_comments 
-- ADD COLUMN IF NOT EXISTS user_name TEXT;

+