-- =====================================================
-- TABLAS PARA LIKES EN COMENTARIOS
-- =====================================================

-- 1. Tabla de likes para comentarios de libros
CREATE TABLE IF NOT EXISTS book_comment_likes (
    comment_id UUID NOT NULL REFERENCES book_comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);

-- 2. Tabla de likes para comentarios de capítulos
CREATE TABLE IF NOT EXISTS chapter_comment_likes (
    comment_id UUID NOT NULL REFERENCES chapter_comments(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (comment_id, user_id)
);

-- 3. Índices para performance
CREATE INDEX IF NOT EXISTS idx_book_comment_likes_comment_id ON book_comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_book_comment_likes_user_id ON book_comment_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_chapter_comment_likes_comment_id ON chapter_comment_likes(comment_id);
CREATE INDEX IF NOT EXISTS idx_chapter_comment_likes_user_id ON chapter_comment_likes(user_id);

-- 4. Habilitar Realtime para actualizaciones en tiempo real (ignorar si ya existe)
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE book_comment_likes;
  EXCEPTION
    WHEN duplicate_object THEN
      NULL; -- Tabla ya está en la publicación, continuar
  END;
  
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE chapter_comment_likes;
  EXCEPTION
    WHEN duplicate_object THEN
      NULL; -- Tabla ya está en la publicación, continuar
  END;
END $$;

-- 5. Agregar columna like_count a book_comments
ALTER TABLE book_comments ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;

-- 6. Agregar columna like_count a chapter_comments
ALTER TABLE chapter_comments ADD COLUMN IF NOT EXISTS like_count INTEGER DEFAULT 0;

-- 7. Función para actualizar like_count en book_comments
CREATE OR REPLACE FUNCTION update_book_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE book_comments 
    SET like_count = like_count + 1
    WHERE id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE book_comments 
    SET like_count = GREATEST(like_count - 1, 0)
    WHERE id = OLD.comment_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 8. Trigger para book_comment_likes
DROP TRIGGER IF EXISTS trigger_update_book_comment_like_count ON book_comment_likes;
CREATE TRIGGER trigger_update_book_comment_like_count
  AFTER INSERT OR DELETE ON book_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION update_book_comment_like_count();

-- 9. Función para actualizar like_count en chapter_comments
CREATE OR REPLACE FUNCTION update_chapter_comment_like_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE chapter_comments 
    SET like_count = like_count + 1
    WHERE id = NEW.comment_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE chapter_comments 
    SET like_count = GREATEST(like_count - 1, 0)
    WHERE id = OLD.comment_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 10. Trigger para chapter_comment_likes
DROP TRIGGER IF EXISTS trigger_update_chapter_comment_like_count ON chapter_comment_likes;
CREATE TRIGGER trigger_update_chapter_comment_like_count
  AFTER INSERT OR DELETE ON chapter_comment_likes
  FOR EACH ROW
  EXECUTE FUNCTION update_chapter_comment_like_count();
