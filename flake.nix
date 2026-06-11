{
  description = "PureScript browser UI scaffold for the wasm32 Plutus evaluator";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    purescript-overlay = {
      url = "github:paolino/purescript-overlay/fix/remove-nodePackages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mkSpagoDerivation = {
      url = "github:jeslie0/mkSpagoDerivation";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      purescript-overlay,
      mkSpagoDerivation,
      ...
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [
            purescript-overlay.overlays.default
            mkSpagoDerivation.overlays.default
          ];
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          nodeModules = pkgs.importNpmLock.buildNodeModules {
            npmRoot = ./.;
            nodejs = pkgs.nodejs_22;
          };
          uplcWasm = pkgs.fetchurl {
            url = "https://github.com/lambdasistemi/plutus/releases/download/1.65.0.0-wasm32.1/uplc.wasm";
            hash = "sha256-nRGtaKXlERl99yQ4yYhbcvfYGRQJUQW7e4cM5Hs5txU=";
          };
        in
        {
          default = pkgs.mkSpagoDerivation {
            pname = "plutus-browser";
            version = "0.1.0";
            src = ./.;
            spagoYaml = ./spago.yaml;
            spagoLock = ./spago.lock;
            nativeBuildInputs = [
              pkgs.purs
              pkgs.spago-unstable
              pkgs.esbuild
              pkgs.nodejs_22
            ];
            buildPhase = ''
              ln -s ${nodeModules}/node_modules node_modules
              mkdir -p src/assets dist
              cp ${uplcWasm} src/assets/uplc.wasm
              npm run build:inside
            '';
            installPhase = ''
              mkdir -p $out
              cp -R dist/. $out/
            '';
          };
        }
      );

      checks = forAllSystems (system: {
        build = self.packages.${system}.default;
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            buildInputs = [
              pkgs.purs
              pkgs.spago-unstable
              pkgs.purs-tidy-bin.purs-tidy-0_10_0
              pkgs.purescript-language-server
              pkgs.esbuild
              pkgs.nodejs_22
              pkgs.just
              pkgs.python3
              pkgs.chromium
            ];
            PLAYWRIGHT_CHROMIUM_EXECUTABLE = "${pkgs.chromium}/bin/chromium";
          };
        }
      );
    };
}
