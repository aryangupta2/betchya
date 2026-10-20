# Betchya API (Cloudflare Workers + D1)

Local tooling: **Bun** (`bun install`, `bun test`). Production runtime: **Cloudflare Workers** (not Bun).

> Note: `wrangler dev` currently breaks when the CLI itself is started under Bun
> ([workers-sdk#39247](https://github.com/oven-sh/bun/issues/39247)). Use `bun test` (Miniflare smoke)
> for local verification, or run `wrangler dev` with Node if you need a live `:8787` proxy.

## Setup

```bash
cd backend
bun install
bun test                  # settle math + Miniflare API smoke (no Node required)
bun run db:local          # optional: apply migrations to wrangler local D1
```

Create a remote D1 database when deploying (needs Cloudflare login):

```bash
bunx wrangler login
bunx wrangler d1 create betchya
# paste database_id into wrangler.toml
bunx wrangler d1 migrations apply betchya --remote
bunx wrangler deploy
```

## Auth

Send `X-User-Id: <uuid>` on mutating requests (matches the iOS Keychain id).

## Smoke (local)

```bash
export UID=user-a
curl -s localhost:8787/health
curl -s -X POST localhost:8787/users/bootstrap -H 'content-type: application/json' -d "{\"id\":\"$UID\"}"
# create group, join second user, create market, bet, resolve…
```
