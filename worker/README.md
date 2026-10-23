# twoByFour server

A Cloudflare Worker at `https://twobyfour.kylefritz.co`, with a D1 database
(`twobyfour`). Today it takes logs people send from the app; later it will
answer Claude lookups for units and sizes the app doesn't know.

## Logs

**Help → Send Logs…** in the app sends `POST /v1/logs` with the debug report
(the build, the open sheet with every answer, and the last 300 log lines), an
optional note, and who sent it:

```json
{
  "user": { "username": "kyle", "fullName": "Kyle Fritz", "computer": "Kyle's MacBook Pro" },
  "device": { "platform": "macOS", "osVersion": "26.6.2", "model": "Mac16,7" },
  "app": { "version": "0.1.1-beta.3", "commit": "abc1234", "channel": "beta" },
  "note": "what happened",
  "report": "…"
}
```

The Worker adds the caller's IP address and country, stores one row in
`log_reports`, and answers `201 {"id": "k7q2mx4dab"}`. The app shows that
reference so someone can mention it.

Reading them back needs `Authorization: Bearer <ADMIN_TOKEN>`:

- `GET /v1/logs?limit=50`: newest first, without the reports
- `GET /v1/logs/<id>`: one report in full

`scripts/logs` in the repository root does both, using the token in
`~/.config/twobyfour/admin-token`.

## Working on it

Uses the `cf` CLI (`cloudflare.config.ts`), Bun for packages and tests.

```sh
bun install
bun test               # runs the real SQL against bun:sqlite
bun run typecheck
bun run deploy         # cf deploy; attaches twobyfour.kylefritz.co
bun run migrate 58e12831-ad66-49cd-bb5a-a2b8be8b003b   # after adding a file to migrations/
```

Set or change the admin token by deploying with `--secrets-file` (a `.env`
file with `ADMIN_TOKEN=...`, kept out of git).
