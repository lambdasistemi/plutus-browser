# Repository Agent Guide

## What this repo is

Plutus Browser is a PureScript single-page application that evaluates
Untyped Plutus Core (UPLC) programs entirely in the browser, using the real
Plutus CEK machine and cost model compiled to wasm32-wasi
(`uplc.wasm`, fetched from a [lambdasistemi/plutus](https://github.com/lambdasistemi/plutus)
release). User snippets are auto-versioned in a browser-local git repository
(isomorphic-git over lightning-fs/IndexedDB). The built site is deployed to
GitHub Pages: <https://lambdasistemi.github.io/plutus-browser/>.

## How to work here

All commands run inside the nix dev shell (`nix develop`):

- Install JS deps: `just install` (npm ci)
- Compile PureScript: `just build` (regenerates `src/Uplc/Examples.purs`
  from `examples/*.uplc`, then `spago build`)
- Full bundle into `dist/`: `just bundle` (downloads `uplc.wasm`, then
  esbuild + spago bundle)
- Serve locally: `just serve` → <http://127.0.0.1:4173/>
- Test (Playwright, needs a prior `just bundle`): `just test`
- Lint / format: `just lint` / `just fmt` (purs-tidy)
- Everything CI runs: `just ci`
- Reproducible build of the site: `nix build` (output in `result/`)

Constraints:

- `src/Uplc/Examples.purs` is generated — edit `examples/*.uplc` instead.
- `src/assets/uplc.wasm` is not committed; the build fetches it
  (`npm run prepare:wasm` locally, `fetchurl` with pinned hash in
  `flake.nix`). Bumping the evaluator release means updating BOTH
  `package.json` (`prepare:wasm`) and `flake.nix` (url + hash), plus the
  release links in `README.md` and `src/Uplc/App.purs` (footer/app bar,
  asserted by the Playwright suite).
- CI (`.github/workflows/ci.yml`) runs on a self-hosted `nixos` runner;
  pushes to `main` deploy to GitHub Pages (`pages.yml`); PRs get a static
  preview (`preview.yml`).

## Skills

Activatable procedures live under `skills/`:

- `skills/plutus-browser-guide/` — repository map, build/test/run
  commands, code navigation, and how to answer user questions about
  this app.
