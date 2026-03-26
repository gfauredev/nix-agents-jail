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
            moreutils
            ps
            ripgrep
            ripgrep-all
            sd
            uutils-coreutils
            unzip
            wget
            which
            xh
          ];
          commonJailOptions = with jail.combinators; [
            network
            time-zone
            no-new-session
            mount-cwd
          ];
          mkCrush =
            {
              extraPkgs ? [ ],
            }:
            jail "jailed-crush" llm-agents.packages.${system}.crush (
              with jail.combinators;
              (
                commonJailOptions
                ++ [
                  (readwrite (noescape "~/.config/crush"))
                  (readwrite (noescape "~/.local/share/crush"))
                  (add-pkg-deps commonPkgs)
                  (add-pkg-deps extraPkgs)
                ]
              )
            );
          mkOpencode =
            {
              extraPkgs ? [ ],
            }:
            jail "jailed-opencode" llm-agents.packages.${system}.opencode (
              with jail.combinators;
              (
                commonJailOptions
                ++ [
                  (readwrite (noescape "~/.config/opencode"))
                  (readwrite (noescape "~/.local/share/opencode"))
                  (readwrite (noescape "~/.local/state/opencode"))
                  (add-pkg-deps commonPkgs)
                  (add-pkg-deps extraPkgs)
                ]
              )
            );
        in
        {
          version = "0.1.0";
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
