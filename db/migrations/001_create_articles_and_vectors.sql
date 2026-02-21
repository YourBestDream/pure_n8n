-- Required extension for vector similarity search (PostgreSQL + pgvector)
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS articles (
  id BIGSERIAL PRIMARY KEY,
  title TEXT NOT NULL,
  url TEXT NOT NULL UNIQUE,
  source TEXT NOT NULL,
  published_at TIMESTAMPTZ,
  category TEXT,
  summary TEXT,
  content TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_articles_published_at ON articles (published_at DESC);
CREATE INDEX IF NOT EXISTS idx_articles_source ON articles (source);
CREATE INDEX IF NOT EXISTS idx_articles_category ON articles (category);

CREATE TABLE IF NOT EXISTS article_chunks (
  id BIGSERIAL PRIMARY KEY,
  article_id BIGINT NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
  chunk_index INT NOT NULL,
  chunk_text TEXT NOT NULL,
  embedding VECTOR(1536) NOT NULL,
  source TEXT,
  category TEXT,
  published_at TIMESTAMPTZ,
  url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (article_id, chunk_index)
);

-- Use ivfflat for fast ANN search. Run ANALYZE after bulk loads.
CREATE INDEX IF NOT EXISTS idx_article_chunks_embedding
  ON article_chunks
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_article_chunks_article_id ON article_chunks (article_id);
CREATE INDEX IF NOT EXISTS idx_article_chunks_published_at ON article_chunks (published_at DESC);
