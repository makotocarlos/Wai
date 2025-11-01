-- MIGRACIÓN: Agregar columna is_published a book_chapters
-- Ejecuta este script en tu proyecto de Supabase (SQL Editor)

-- 1. Agregar la columna is_published (por defecto true para compatibilidad)
ALTER TABLE book_chapters 
ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT true;

-- 2. Actualizar TODOS los capítulos existentes para que estén publicados
-- (Esto mantiene el comportamiento actual donde todos los capítulos están visibles)
UPDATE book_chapters 
SET is_published = true
WHERE is_published IS NULL;

-- 3. Crear un índice para mejor performance
CREATE INDEX IF NOT EXISTS idx_book_chapters_published 
ON book_chapters(book_id, is_published);

-- 4. Verificar la migración
SELECT 
  b.title AS libro,
  COUNT(*) AS total_capitulos,
  COUNT(CASE WHEN bc.is_published = true THEN 1 END) AS capitulos_publicados
FROM books b
LEFT JOIN book_chapters bc ON b.id = bc.book_id
GROUP BY b.id, b.title
ORDER BY b.title;
