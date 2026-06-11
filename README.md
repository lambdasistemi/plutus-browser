# Plutus Browser

Browser UI for the wasm32 Plutus evaluator: UPLC editor, evaluator output, and
browser-local snippets.

- App repository: https://github.com/lambdasistemi/plutus-browser
- Evaluator release: https://github.com/lambdasistemi/plutus/releases/tag/1.65.0.0-wasm32.1

## Development

```sh
nix develop
just install
just bundle
just serve
```

The app downloads `uplc.wasm` from the evaluator release above with:

```sh
npm run prepare:wasm
```

## Verification

```sh
nix build
nix develop --quiet -c just ci
```

The Playwright suite serves `dist/`, checks that the bundled evaluator shows
`(con integer 42)`, and verifies browser-local snippet persistence.

## Pages

The main branch deploys `dist/` to GitHub Pages through workflow mode.
