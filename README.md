## Prerequisites

- Docker + Docker Compose (recommended)
or:
- n8n (self-hosted or desktop)
- PostgreSQL with `pgvector` extension enabled
- OpenAI-compatible API key for embeddings + chat (or compatible endpoint)

## Docker Quick Start

1. Copy `.env.example` to `.env` and fill:
   - `POSTGRES_PASSWORD`
   - `N8N_ENCRYPTION_KEY` (long random string)
2. Start stack:

```bash
docker compose up -d
```

3. Open n8n at `http://localhost:5678`.
4. Import workflows from `workflows/`.

What this stack gives you:
- `postgres` service using `pgvector/pgvector:pg16`
- automatic first-run bootstrap of `db/migrations/001_create_articles_and_vectors.sql`
- `n8n` service connected to Postgres

If you already have an existing Postgres volume, bootstrap scripts will not re-run. In that case run migration manually.

## Environment Variables

Set these in n8n environment:

- `RSS_URLS`: Comma-separated RSS feed URLs
  - Example: `https://openai.com/news/rss.xml,https://blog.google/technology/ai/rss/`
- `RSS_MAX_ITEMS`: Max unique articles to ingest per run (defaults to `60`)
- `CHUNK_SIZE`: Defaults to `1200`
- `CHUNK_OVERLAP`: Defaults to `200`
- `DIGEST_OUTPUT_PATH`: Optional path for markdown file output
  - Example in Docker: `/workspace/outputs/weekly-ai-digest.md`

## Database Setup

Run:

```sql
\i db/migrations/001_create_articles_and_vectors.sql
```

Or copy/paste that migration into your SQL client.

## Workflow Import Order

1. Import `workflows/rss_ingest_and_index.json`
2. Import `workflows/weekly_digest_markdown.json`
3. Import `workflows/rag_chat_agent.json`

After import:
- Attach your PostgreSQL credential to all Postgres nodes:
  - Host: `postgres`
  - Port: `5432`
  - Database: value of `POSTGRES_DB` (default `n8n`)
  - User: value of `POSTGRES_USER` (default `n8n`)
  - Password: value of `POSTGRES_PASSWORD`
- Create one OpenAI credential in n8n:
  - Credential type: `OpenAI`
  - API key: `<YOUR_API_KEY>`
- Attach that OpenAI credential to these nodes:
  - `OpenAI Embeddings` in `AI News - RSS Ingest + PGVector Insert`
  - `OpenAI Chat Model` in `AI News - RAG Chat Agent (AI Agent + PGVector)`
  - `OpenAI Embeddings` in `AI News - RAG Chat Agent (AI Agent + PGVector)`

## How To Run

### 1) RSS Ingest + Vector Index

Workflow: `AI News - RSS Ingest + PGVector Insert`

- Run manually first to validate DB writes.
- Ingest uses all URLs from `RSS_URLS`, deduplicates by URL, sorts by publish date, and keeps up to `RSS_MAX_ITEMS`.
- Vector indexing uses upsert semantics: existing `n8n_vectors` rows for the same `article_id` are deleted, then fresh chunks are inserted.
- Output:
  - `articles` table upserted by URL
  - `n8n_vectors` table populated with chunked vectors + metadata

### 2) Weekly Digest Markdown

Workflow: `AI News - Weekly Digest Markdown`

- Run manually (or add schedule trigger).
- Output:
  - Markdown available in node output field `markdown`
  - File written to `DIGEST_OUTPUT_PATH` (Docker default is `/workspace/outputs/weekly-ai-digest.md`, mapped to local `outputs/`)

### 3) RAG Chat Agent

Workflow: `AI News - RAG Chat Agent (AI Agent + PGVector)`

- Activate workflow.
- Open the Chat panel in n8n for this workflow and ask questions.
- The AI Agent uses PGVector as a tool and is instructed to include source URLs.