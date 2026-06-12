---
name: plutus-browser-guide
description: Guide to the lambdasistemi/plutus-browser repository — a PureScript single-page app that evaluates UPLC (Untyped Plutus Core) in the browser via uplc.wasm (Plutus CEK + cost model compiled to wasm32-wasi) with browser-local git-versioned snippets. Load when working on or answering questions about plutus-browser, the UPLC playground, Uplc.App, Uplc.Runner, Uplc.Format, SnippetStore, SpaKit.BrowserGit, SpaKit.WasiRunner, examples/*.uplc, generate-examples.mjs, spago.yaml, mkSpagoDerivation, just bundle, prepare:wasm, uplc.wasm, "uplc evaluate -c", uplc-snippets-v1, lightning-fs, isomorphic-git, the Playwright suite test/uplc.spec.mjs, serve-dist.mjs, the GitHub Pages deployment, or bumping the lambdasistemi/plutus evaluator release.
---

# plutus-browser guide

## Repository map

- `src/Main.purs` — entry point; mounts the React app on `#root`.
- `src/Uplc/App.purs` — the entire UI: snippet/example/history drawer,
  CodeMirror editor card, controls row, output card, dialogs, footer.
- `src/Uplc/Runner.purs` + `.js` — compiles the bundled wasm and runs
  `uplc evaluate` (adds `-c` when the budget toggle is on).
- `src/Uplc/Format.purs` + `.js` — UPLC pretty-printer (tokenizer,
  82-column packing, indent width 2/4/8).
- `src/Uplc/Examples.purs` — GENERATED from `examples/*.uplc` by
  `scripts/generate-examples.mjs`. Never edit by hand.
- `src/Uplc/SnippetStore.purs` + `.js` — delete/rename as git commits on
  the browser repo.
- `src/Uplc/SnippetImport.purs` + `.js` — snippet content from URL fetch
  or local file picker.
- `src/Uplc/DialogControls.purs` + `.js`, `src/Uplc/Timer.purs` + `.js` —
  MUI menu/select FFI and setTimeout FFI.
- `src/bootstrap.js` — esbuild entry; inlines `src/assets/uplc.wasm` as
  bytes (`globalThis.uplcWasmBytes`).
- `examples/*.uplc` — 22 bundled example programs (source of truth).
- `scripts/serve-dist.mjs` — minimal static file server for `dist/`.
- `test/uplc.spec.mjs` + `playwright.config.mjs` — end-to-end suite.
- `flake.nix` — nix package (mkSpagoDerivation) building `dist/`,
  dev shell, CI check; pins the `uplc.wasm` release URL + hash.
- `justfile`, `package.json` — command surface (see below).
- `spago.yaml` — PureScript deps; SpaKit modules (wasi-runner, mui,
  codemirror, browser-git) come from lambdasistemi/purescript-spa-kit,
  pinned by git ref.
- `.github/workflows/` — `ci.yml` (build gate + `just ci` on the
  self-hosted `nixos` runner), `pages.yml` (deploy to GitHub Pages on
  main), `preview.yml` (PR static preview).

## Build, test, run

Inside `nix develop`:

```sh
just install   # npm ci
just build     # regenerate Examples.purs + spago build (type-check)
just bundle    # download uplc.wasm + esbuild deps + spago bundle -> dist/
just serve     # serve dist/ on http://127.0.0.1:4173/
just test      # Playwright (chromium from the dev shell); needs dist/
just lint      # purs-tidy check
just fmt       # purs-tidy format-in-place
just ci        # install + lint + build + bundle + test (what CI runs)
```

Reproducible site build without the shell: `nix build` (result/ = dist/).
The Playwright config auto-starts `scripts/serve-dist.mjs`; the dev shell
exports `PLAYWRIGHT_CHROMIUM_EXECUTABLE` so no browser download is needed.

## Navigating the code

- UI behavior (state, debounces, dirty/saved labels, dialogs) is all in
  `src/Uplc/App.purs` — a single react-basic-hooks component
  (`mkApp`). Defaults live at the top: auto-eval debounce 350 ms,
  auto-commit debounce 1500 ms, indent width 2, drawer width 304,
  storage namespace `uplc-snippets-v1`.
- Evaluation path: `App.evaluate` → `Uplc.Runner.runUplc` →
  `SpaKit.WasiRunner.runWasmCli` with args `["uplc","evaluate"]`
  (+ `"-c"`) and the editor text as stdin.
- Persistence path: `SpaKit.BrowserGit` (init/list/read/write/log/checkout)
  plus `Uplc.SnippetStore` (delete/rename); each snippet is
  `<name>.uplc` in a git repo at `/repo` on a lightning-fs filesystem
  (IndexedDB) named `uplc-snippets-v1`; every save is a commit, the
  History panel is `git log`, restore is a new commit.
- Adding an example: drop `NN-name.uplc` into `examples/`, run
  `just build`; the Playwright suite's `exampleCount` (22) in
  `test/uplc.spec.mjs` must be updated to match.
- Bumping the evaluator: update the release URL in `package.json`
  (`prepare:wasm`) and `flake.nix` (`fetchurl` url + hash), and the
  version links in `README.md` and `src/Uplc/App.purs` (footer and app
  bar) — the test suite asserts those hrefs.

## Using the app

- Live instance: <https://lambdasistemi.github.io/plutus-browser/>.
- Type or load a UPLC program, e.g.
  `(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])`,
  press Evaluate → output `(con integer 42)`; enable "show budget (-c)"
  for CPU/Memory budget figures.
- Snippets: quick-add by name, or "new from..." (copy / local file / URL);
  rename/delete via row hover actions; per-snippet history with view and
  restore.

## Answering questions

- "What is this / is it really the chain evaluator?" → README "What is
  this": it is the real Plutus CEK + cost model from the
  lambdasistemi/plutus wasm32 fork, byte-identical to 64-bit results;
  release pinned in `flake.nix` and `package.json`.
- "Where are my snippets / are they uploaded?" → README Usage: browser-only
  (IndexedDB, namespace `uplc-snippets-v1`); clearing site data deletes
  them; nothing leaves the browser.
- "How do I run/build it?" → README Quickstart/Development; commands are
  the `justfile` recipes.
- "Why does the editor re-indent / what formatting rules?" →
  `src/Uplc/Format.js` (82-col packing, indent 2/4/8).
- "What UPLC syntax do the examples cover?" → `examples/` directory;
  names map 1:1 to the in-app list.
- "How is it deployed?" → `.github/workflows/pages.yml`: nix-built site,
  GitHub Pages workflow mode, on push to main.
