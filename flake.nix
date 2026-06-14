{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flakelight = {
      url = "github:nix-community/flakelight";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    { flakelight, ... }@inputs:
    flakelight ./. (
      { outputs, ... }:
      {
        inherit inputs;
        flakelight.builtinFormatters = false;

        devShell =
          pkgs: with pkgs; {
            packages = [
              esp-rust-toolchain
            ];
            env.RUST_SRC_PATH = "${esp-rust-toolchain}/lib/rustlib/src/rust/library";
          };

        packages =
          let
            version = "1.95.0.0";
            binHash = "sha256-3wpKYEA9i9+/6OkzuBjFD7MSufN8ZCgBmUNdB2LeprI=";
            srcHash = "sha256-mUpucCIRJxgFWiW5HlT95ZKvA+u4+T5CvEfgoQZoNOA=";

            mkComponent = outputs.lib.mkComponent version;
          in
          rec {
            default = esp-rust-toolchain;
            esp-rust-toolchain =
              pkgs:
              with pkgs;
              symlinkJoin {
                pname = "esp-rust-toolchain";
                inherit version;
                paths = [
                  esp-cargo
                  esp-clippy
                  # esp-rust-analyzer?
                  esp-rust-docs
                  esp-rust-docs-json
                  esp-rust-std
                  esp-rustc-with-src
                  esp-rustfmt
                ];
              };
          }
          # Splited to avoid resolving via `rec` instead of `with pkgs;`
          // {
            # See https://rust-lang.github.io/rustup/concepts/components.html
            # and the content of esprs-rust-bin.
            esp-cargo = mkComponent "cargo";
            esp-clippy = mkComponent "clippy";
            esp-rust-docs = mkComponent "rust-docs";
            esp-rust-docs-json = mkComponent "rust-docs-json";
            esp-rust-src = mkComponent "rust-src"; # this will use esprs-rust-src as src
            esp-rust-std = mkComponent "rust-std";
            esp-rustc = mkComponent "rustc";
            esp-rustfmt = mkComponent "rustfmt";

            # This component includes both rustc and rust-src in the same output, for IDEs/tools that need them together.
            esp-rustc-with-src = mkComponent "rustc-with-src";

            # TODO: esp-rust-analyzer?

            esprs-rust-bin =
              {
                fetchzip,
                stdenv,
              }:
              let
                target = stdenv.hostPlatform.rust.rustcTarget; # e.g. "x86_64-unknown-linux-gnu";
              in
              fetchzip {
                url = "https://github.com/esp-rs/rust-build/releases/download/v${version}/rust-${version}-${target}.tar.xz";
                hash = binHash;
              };

            esprs-rust-src =
              {
                fetchzip,
              }:
              fetchzip {
                url = "https://github.com/esp-rs/rust-build/releases/download/v${version}/rust-src-${version}.tar.xz";
                hash = srcHash;
              };
          };

        lib = {
          mkComponent =
            version: component: # required arguments
            {
              stdenv,
              esprs-rust-src,
              esprs-rust-bin,
              esp-rustc, # for clippy and rustfmt
              autoPatchelfHook,
              libz,
            }:
            stdenv.mkDerivation {
              pname = "esp-${component}";
              inherit version;

              src =
                let
                  src' = if component == "rust-src" then esprs-rust-src else esprs-rust-bin;
                  target = stdenv.hostPlatform.rust.rustcTarget; # e.g. "x86_64-unknown-linux-gnu";
                  component' =
                    # Rename components to match the names used in the rust-build releases,
                    # which are different from rustup's component names.
                    {
                      clippy = "clippy-preview";
                      rust-docs-json = "rust-docs-json-preview";
                      rust-std = "rust-std-${target}";
                      rustfmt = "rustfmt-preview";
                      rustc-with-src = "rustc"; # use the rustc files as the source; add the rust-src files later in installPhase
                    }
                    .${component} or component;
                in
                "${src'}/${component'}";

              nativeBuildInputs = [ autoPatchelfHook ];
              buildInputs = [
                stdenv.cc.cc
                libz # needed by rustc
              ]
              # clippy and rustfmt need rustc to build; gated behind a conditional to avoid circular dependency
              ++ (if (component == "clippy" || component == "rustfmt") then [ esp-rustc ] else [ ]);

              dontConfigure = true;
              dontBuild = true;

              installPhase = ''
                runHook preInstall;

                mkdir -p $out
                cp -r ./* $out/

                ${
                  # Also see README.md for the rationale behind this implementation.
                  if component == "rustc-with-src" then
                    ''
                      # Add the rust-src files to the rustc output for the "rustc-with-src" component, so that IDEs can find them together.
                      cp -r ${esprs-rust-src}/rust-src/* $out/
                    ''
                  else
                    ""
                }

                # This is used by Rust installer scripts (install.sh), but we don't need it here.
                rm -f $out/manifest.in

                runHook postInstall;
              '';
            };
        };
      }
    );
}
