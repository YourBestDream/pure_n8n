# AI News Digest + RAG Agent Runbook (n8n)

This runbook is the operational guide for setup, execution, validation, and recovery of:
- RSS ingest to database
- Weekly markdown digest generation
- RAG chat over indexed news

## 1. Scope and Current Flow

Implemented workflows:
1. `workflows/rss_ingest_and_index.json`
2. `workflows/weekly_digest_markdown.json`
3. `workflows/rag_chat_agent.json`

Data flow:
1. RSS items are read from `RSS_URLS`, normalized, and upserted into `articles`.
2. Article text is chunked and embedded, then stored in `n8n_vectors` with metadata.
3. Weekly digest reads last 7 days from `articles` and writes markdown output.
4. Chat agent retrieves from `n8n_vectors` and answers with source URLs.

Note on schema:
- `db/migrations/001_create_articles_and_vectors.sql` creates `articles` and `n8n_vectors`.
- Ingest workflow still runs `CREATE TABLE IF NOT EXISTS n8n_vectors` as a safety check.

## 2. Prerequisites

- Docker + Docker Compose (recommended), or equivalent self-hosted n8n + PostgreSQL
- PostgreSQL with `pgvector` extension support
- OpenAI-compatible API key for embeddings and chat

## 3. Configuration Matrix

Set in `.env` (or equivalent n8n runtime environment):

| Variable | Default | Used By | Purpose |
|---|---|---|---|
| `POSTGRES_USER` | `n8n` | Docker services | DB username |
| `POSTGRES_PASSWORD` | `change_me` | Docker services | DB password |
| `POSTGRES_DB` | `n8n` | Docker services | DB name |
| `POSTGRES_PORT` | `5432` | Docker services | Host DB port mapping |
| `N8N_PORT` | `5678` | n8n | n8n UI/API port |
| `N8N_HOST` | `localhost` | n8n | n8n host |
| `N8N_PROTOCOL` | `http` | n8n | n8n protocol |
| `WEBHOOK_URL` | `http://localhost:5678/` | n8n | webhook base URL |
| `N8N_ENCRYPTION_KEY` | `replace-with-a-long-random-string` | n8n | credential encryption key |
| `N8N_BLOCK_ENV_ACCESS_IN_NODE` | `false` | n8n code nodes | allows `$env.*` in workflows |
| `N8N_RESTRICT_FILE_ACCESS_TO` | `/workspace/outputs` | file write node | output file safety boundary |
| `TZ` | `UTC` | all services | timezone |
| `RSS_URLS` | OpenAI + Google feed URLs | RSS ingest workflow | comma-separated feed list |
| `RSS_MAX_ITEMS` | `60` | RSS ingest workflow | max unique articles per run |
| `CHUNK_SIZE` | `1200` | RSS ingest workflow | splitter chunk size |
| `CHUNK_OVERLAP` | `200` | RSS ingest workflow | splitter overlap |
| `RAG_TOP_K` | `6` | RAG chat workflow | retrieval result count |
| `DIGEST_OUTPUT_PATH` | `/workspace/outputs/weekly-ai-digest.md` | weekly digest workflow | markdown output path |

## 4. Setup and Bootstrap

### 4.1 Docker start

1. Copy environment template:
```bash
cp .env.example .env
```
2. Set at minimum:
- `POSTGRES_PASSWORD`
- `N8N_ENCRYPTION_KEY`
3. Start services:
```bash
docker compose up -d
```
4. Open n8n UI: `http://localhost:5678`

### 4.2 Database migration

Bootstrap file `docker/postgres/init/00_bootstrap.sql` runs on first initialization of a new Postgres volume and executes:
```sql
\i /migrations/001_create_articles_and_vectors.sql
```

If Postgres volume already existed, run migration manually:
```sql
\i db/migrations/001_create_articles_and_vectors.sql
```

### 4.3 Import workflows

Import in this order:
1. `workflows/rss_ingest_and_index.json`
2. `workflows/weekly_digest_markdown.json`
3. `workflows/rag_chat_agent.json`

### 4.4 Credentials wiring (required)

Create one PostgreSQL credential and attach to:
- `Upsert Article` in `AI News - RSS Ingest + PGVector Insert`
- `Fetch Last 7 Days` in `AI News - Weekly Digest Markdown`
- `PGVector Vector Store` in `AI News - RSS Ingest + PGVector Insert`
- `PGVector Vector Store` in `AI News - RAG Chat Agent (AI Agent + PGVector)`

Create one OpenAI credential and attach to:
- `OpenAI Embeddings` in `AI News - RSS Ingest + PGVector Insert`
- `OpenAI Chat Model` in `AI News - RAG Chat Agent (AI Agent + PGVector)`
- `OpenAI Embeddings` in `AI News - RAG Chat Agent (AI Agent + PGVector)`

## 5. Operations Procedures

### 5.1 Procedure A: RSS ingest + vector index

Workflow: `AI News - RSS Ingest + PGVector Insert`

Run:
1. Execute workflow manually.
2. Confirm no node errors.

Expected behavior:
- Reads all feeds from `RSS_URLS`
- Deduplicates by URL
- Sorts by publish date descending
- Keeps up to `RSS_MAX_ITEMS`
- Upserts into `articles` by unique URL
- Deletes old vectors for each updated `article_id`
- Inserts new chunks and embeddings into `n8n_vectors`

Verification SQL:
```sql
SELECT COUNT(*) AS articles_count FROM articles;
SELECT COUNT(*) AS vectors_count FROM n8n_vectors;
SELECT metadata->>'url' AS url, COUNT(*) AS chunks
FROM n8n_vectors
GROUP BY metadata->>'url'
ORDER BY chunks DESC
LIMIT 10;
```

### 5.2 Procedure B: weekly markdown digest

Workflow: `AI News - Weekly Digest Markdown`

Run:
1. Execute workflow manually (or add a schedule trigger).
2. Inspect `Build Markdown` output field `markdown`.
3. Confirm `Write Markdown File` succeeds.

Output:
- Markdown content in execution data (`markdown` field)
- Markdown file at `DIGEST_OUTPUT_PATH`
- If `DIGEST_OUTPUT_PATH` is unset, workflow defaults to `/workspace/outputs/weekly-ai-digest-<week_end>.md`

### 5.3 Procedure C: RAG chat agent

Workflow: `AI News - RAG Chat Agent (AI Agent + PGVector)`

Run:
1. Activate workflow.
2. Open n8n Chat panel for this workflow.
3. Ask a query such as: `What were the main AI model updates this week? Include links.`

Expected behavior:
- Agent retrieves relevant chunks from `n8n_vectors` (tool: `retriever`)
- Response is grounded in retrieved context
- Response includes source URLs

## 6. Deliverables and Evidence Locations

Repository artifacts for case-study evidence:
- Workflows JSON: `workflows/`
- Workflow screenshots: `outputs/rss_ingest_and_index.png`, `outputs/weekly_digest_markdown.png`, `outputs/rag_chat_agent.png`
- Sample markdown digest: `outputs/weekly-ai-digest.md`
- Sample DB export: `outputs/sample_articles_export.json`
- Sample chat transcript: `outputs/chat_transcript.md`

## 7. Troubleshooting

1. `RSS_URLS env var is empty` in `Split RSS URLs`
- Set `RSS_URLS` in runtime environment and rerun.

2. `relation "n8n_vectors" does not exist` during chat
- Re-run `db/migrations/001_create_articles_and_vectors.sql`.
- If still missing, run ingest workflow once to create/populate `n8n_vectors`.

3. File write failure in weekly digest
- Ensure `DIGEST_OUTPUT_PATH` is inside allowed path (`N8N_RESTRICT_FILE_ACCESS_TO`, default `/workspace/outputs`).
- Ensure `./outputs` is mounted and writable.

4. No articles returned in digest
- Run ingest first.
- Check feed availability and `RSS_MAX_ITEMS`.
- Validate `published_at` values in `articles`.

5. Environment values not available in code nodes
- Ensure `N8N_BLOCK_ENV_ACCESS_IN_NODE=false`.

## 8. Recovery and Backfill

1. Re-ingest latest feed window:
- Rerun Procedure A.

2. Backfill with more records:
- Increase `RSS_MAX_ITEMS`, rerun Procedure A.

3. Rebuild vectors from current articles:
```sql
TRUNCATE TABLE n8n_vectors;
```
- Then rerun Procedure A.

4. Recreate base schema on existing DB:
- Re-run `db/migrations/001_create_articles_and_vectors.sql`.

## 9. Operational Checklist

Before production use:
1. All four DB-linked nodes have PostgreSQL credentials attached.
2. All three OpenAI nodes have OpenAI credentials attached.
3. Procedure A creates/upserts `articles` and `n8n_vectors`.
4. Procedure B writes markdown to `outputs/`.
5. Procedure C answers with at least one valid source URL.
