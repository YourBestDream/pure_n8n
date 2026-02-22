-- Required extension for vector similarity search (PostgreSQL + pgvector)
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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

CREATE TABLE IF NOT EXISTS n8n_vectors (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  text text,
  metadata jsonb,
  embedding VECTOR(1536)
);

-- Use ivfflat for fast ANN search. Run ANALYZE after bulk loads.
CREATE INDEX IF NOT EXISTS idx_n8n_vectors_embedding
  ON n8n_vectors
  USING ivfflat (embedding vector_cosine_ops)
  WITH (lists = 100);

CREATE INDEX IF NOT EXISTS idx_n8n_vectors_article_id ON n8n_vectors ((metadata->>'article_id'));
CREATE INDEX IF NOT EXISTS idx_n8n_vectors_published_at ON n8n_vectors ((metadata->>'published_at'));
