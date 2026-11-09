# Web release (gullyfight.com on Cloudflare)

The browser version of Gully Fight is served by Cloudflare. Hosting is free; the only cost is the domain.

## How it is served

- **The page and small files** go on Cloudflare Pages (project `gully-fight`).
- **The two big files** are over Pages' 25 MiB per-file limit, so they live in the R2 bucket `gully-fight-game`:
  - the engine, `index.wasm`, stored gzipped (38 MB → 10 MB to download);
  - the game data, `index.pck`, about 95 MB.

  `functions/[[path]].js` serves them on the same site, so there is no second domain and no CORS setup. R2 charges nothing for downloads.
- **Returning players** revalidate by ETag and don't download again.
- **Phones and tablets** get a "not yet" page (the `head_include` in `export_presets.cfg`) and never download the game.

## Commands

From the repository root, in Git Bash:

| Command | What it does |
|---|---|
| `tools/web/deploy.sh remote` | Export, upload to R2, publish the page |
| `tools/web/deploy.sh local` then `tools/web/serve_local.sh` | The same, in Cloudflare's local simulator at http://127.0.0.1:8788 |

Add `--no-export` to reuse the last build in `build/web`.

Wrangler is pinned to 3.114.17 because wrangler 4 needs Node 22. Signing in is a one-time `npx --yes wrangler@3.114.17 login`, which opens Cloudflare in the browser to allow access.

## One-time setup in the Cloudflare dashboard

1. Register `gullyfight.com` (Domain Registration).
2. Open **Workers & Pages → gully-fight → Custom domains** and add `gullyfight.com` and `www.gullyfight.com`.
