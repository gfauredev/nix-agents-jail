{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    jail-nix.url = "sourcehut:~alexdavid/jail.nix";
    llm-agents.url = "github:numtide/llm-agents.nix";
  };
  outputs =
    {
      self,
      nixpkgs,
      jail-nix,
      llm-agents,
    }:
    let
      forSystems = nixpkgs.lib.genAttrs [
        "x86_64-linux" # "aarch64-linux"
        # "aarch64-darwin"
      ];
      nixpkgsFor = forSystems (
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        }
      );
      sharedEnvFor =
        system:
        let
          pkgs = nixpkgsFor.${system};
          jail = jail-nix.lib.init pkgs;
          commonPkgs = with pkgs; [
            bashInteractive
            curl
            coreutils
            delta
            diffutils
            findutils
            fd
            git
            gnugrep
            gawkInteractive
            gzip
            gnutar
            jq
            jujutsu
            moreutils
            ps
            ripgrep
            ripgrep-all
            sd
            taplo # TOML LSP
            typescript-language-server # TypeScript LSP
            uutils-coreutils
            unzip
            vscode-langservers-extracted # HTML/CSS/JS(ON)
            wget
            which
            xh
            yaml-language-server # YAML LSP
          ];
          commonJailOptions = with jail.combinators; [
            network
            time-zone
            no-new-session
            mount-cwd
          ];
          mkCrush =
            {
              name ? "jailcrush",
              extraPkgs ? [ ],
            }:
            jail name llm-agents.packages.${system}.crush (
              with jail.combinators;
              (
                commonJailOptions
                ++ [
                  (readwrite (noescape "~/.config/crush"))
                  (readwrite (noescape "~/.cache/crush"))
                  (readwrite (noescape "~/.local/share/crush"))
                  (readwrite (noescape "~/.local/state/crush"))
                  (add-pkg-deps commonPkgs)
                  (add-pkg-deps extraPkgs)
                ]
              )
            );
          mkOpencode =
            {
              name ? "jailopencode",
              extraPkgs ? [ ],
            }:
            jail name llm-agents.packages.${system}.opencode (
              with jail.combinators;
              (
                commonJailOptions
                ++ [
                  (readwrite (noescape "~/.config/opencode"))
                  (readwrite (noescape "~/.cache/opencode"))
                  (readwrite (noescape "~/.local/share/opencode"))
                  (readwrite (noescape "~/.local/state/opencode"))
                  (add-pkg-deps commonPkgs)
                  (add-pkg-deps extraPkgs)
                ]
              )
            );
        in
        {
          version = "0.1.1";
          inherit
            pkgs
            mkCrush
            mkOpencode
            ;
        };
    in
    {
      lib = forSystems (system: {
        mkCrush = (sharedEnvFor system).mkCrush;
        mkOpencode = (sharedEnvFor system).mkOpencode;
      });
      devShells = forSystems (
        system:
        let
          env = sharedEnvFor system;
          pkgs = env.pkgs;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixd
              (env.mkCrush { })
              (env.mkOpencode { })
            ];
          };
        }
      );
    };
}
