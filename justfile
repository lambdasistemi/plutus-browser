build:
    npm run generate:examples
    spago build

bundle:
    npm run build

install:
    npm ci

dev:
    npm run generate:examples
    spago build --watch

serve:
    npm run serve

test:
    npm test

ci: install lint build bundle test

fmt:
    purs-tidy format-in-place 'src/**/*.purs'

lint:
    purs-tidy check 'src/**/*.purs'

format-check: lint
