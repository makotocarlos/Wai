-- =====================================================
-- AGREGAR COLUMNA username A book_comments
-- =====================================================

ALTER TABLE book_comments 
ADD COLUMN IF NOT EXISTS username TEXT;

-- Verificar que se creó correctamente
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'book_comments'
ORDER BY ordinal_position;
