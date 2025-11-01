-- =====================================================
-- SISTEMA DE RESPUESTAS A COMENTARIOS (Threading)
-- =====================================================
-- Ejecuta este script en el SQL Editor de Supabase
-- para habilitar respuestas anidadas en comentarios
-- =====================================================

-- 1. Agregar columna parent_comment_id para threading
ALTER TABLE book_comments 
ADD COLUMN IF NOT EXISTS parent_comment_id UUID REFERENCES book_comments(id) ON DELETE CASCADE;

-- 2. Agregar índice para mejorar performance de búsqueda de respuestas
CREATE INDEX IF NOT EXISTS idx_book_comments_parent_id 
ON book_comments(parent_comment_id);

-- 3. Agregar columna para contar respuestas (desnormalización para performance)
ALTER TABLE book_comments 
ADD COLUMN IF NOT EXISTS reply_count INTEGER DEFAULT 0;

-- 4. Función para actualizar automáticamente el contador de respuestas
CREATE OR REPLACE FUNCTION update_comment_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Incrementar contador cuando se agrega una respuesta
    IF NEW.parent_comment_id IS NOT NULL THEN
      UPDATE book_comments 
      SET reply_count = reply_count + 1
      WHERE id = NEW.parent_comment_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Decrementar contador cuando se elimina una respuesta
    IF OLD.parent_comment_id IS NOT NULL THEN
      UPDATE book_comments 
      SET reply_count = GREATEST(reply_count - 1, 0)
      WHERE id = OLD.parent_comment_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. Trigger para mantener el contador actualizado automáticamente
DROP TRIGGER IF EXISTS trigger_update_reply_count ON book_comments;
CREATE TRIGGER trigger_update_reply_count
  AFTER INSERT OR DELETE ON book_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_comment_reply_count();

-- 6. Actualizar reply_count para comentarios existentes
UPDATE book_comments parent
SET reply_count = (
  SELECT COUNT(*)
  FROM book_comments replies
  WHERE replies.parent_comment_id = parent.id
)
WHERE parent.parent_comment_id IS NULL;

-- =====================================================
-- VERIFICACIÓN (Opcional - para testear)
-- =====================================================

-- Ver estructura de la tabla actualizada
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'book_comments'
-- ORDER BY ordinal_position;

-- =====================================================
-- NOTAS IMPORTANTES:
-- =====================================================
-- 1. parent_comment_id NULL = Comentario raíz (top-level)
-- 2. parent_comment_id NOT NULL = Respuesta a otro comentario
-- 3. reply_count se actualiza automáticamente con triggers
-- 4. ON DELETE CASCADE: Si se elimina un comentario padre,
--    todas sus respuestas también se eliminan
-- 5. Realtime debe estar habilitado para book_comments
-- =====================================================
