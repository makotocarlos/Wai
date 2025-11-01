-- =====================================================
-- VERIFICAR Y CREAR TABLA chapter_comments
-- =====================================================

-- 1. Verificar si existe la tabla chapter_comments
SELECT table_name 
FROM information_schema.tables 
WHERE table_name = 'chapter_comments';

-- 2. Si NO existe, crear la tabla chapter_comments
CREATE TABLE IF NOT EXISTS chapter_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chapter_id UUID NOT NULL REFERENCES book_chapters(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    user_avatar_url TEXT,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    parent_comment_id UUID REFERENCES chapter_comments(id) ON DELETE CASCADE,
    reply_count INTEGER DEFAULT 0
);

-- 3. Crear índices para performance
CREATE INDEX IF NOT EXISTS idx_chapter_comments_chapter_id ON chapter_comments(chapter_id);
CREATE INDEX IF NOT EXISTS idx_chapter_comments_user_id ON chapter_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_chapter_comments_parent_id ON chapter_comments(parent_comment_id);
CREATE INDEX IF NOT EXISTS idx_chapter_comments_created_at ON chapter_comments(created_at);

-- 4. Habilitar Realtime para actualizaciones en tiempo real
ALTER PUBLICATION supabase_realtime ADD TABLE chapter_comments;

-- 5. Función para actualizar reply_count automáticamente
CREATE OR REPLACE FUNCTION update_chapter_comment_reply_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.parent_comment_id IS NOT NULL THEN
      UPDATE chapter_comments 
      SET reply_count = reply_count + 1
      WHERE id = NEW.parent_comment_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.parent_comment_id IS NOT NULL THEN
      UPDATE chapter_comments 
      SET reply_count = GREATEST(reply_count - 1, 0)
      WHERE id = OLD.parent_comment_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 6. Trigger para mantener reply_count actualizado
DROP TRIGGER IF EXISTS trigger_update_chapter_comment_reply_count ON chapter_comments;
CREATE TRIGGER trigger_update_chapter_comment_reply_count
  AFTER INSERT OR DELETE ON chapter_comments
  FOR EACH ROW
  EXECUTE FUNCTION update_chapter_comment_reply_count();

-- 7. Verificar estructura final
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'chapter_comments'
ORDER BY ordinal_position;
