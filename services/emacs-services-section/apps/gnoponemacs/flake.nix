{
  description = "GnoponEmacs reproducible Emacs closure and engineering shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forAllSystems = nixpkgs.lib.genAttrs systems;

      emacsPackageNames = [
        "ace-window"
        "apheleia"
        "auto-dark"
        "avy"
        "beancount"
        "cape"
        "consult"
        "consult-dir"
        "corfu"
        "corfu-terminal"
        "dape"
        "diff-hl"
        "diminish"
        "dockerfile-mode"
        "doom-modeline"
        "eat"
        "embark"
        "embark-consult"
        "envrc"
        "expand-region"
        "fennel-mode"
        "forge"
        "gptel"
        "helpful"
        "jq-mode"
        "json-mode"
        "magit"
        "markdown-mode"
        "markdown-toc"
        "mixed-pitch"
        "modus-themes"
        "multiple-cursors"
        "nerd-icons"
        "nerd-icons-completion"
        "nerd-icons-dired"
        "nix-mode"
        "no-littering"
        "ob-crystal"
        "orderless"
        "org-drill"
        "org-modern"
        "org-roam"
        "org-roam-ui"
        "org-transclusion"
        "olivetti"
        "ox-gfm"
        "ox-hugo"
        "paredit"
        "popper"
        "restclient"
        "rust-mode"
        "transient"
        "treesit-auto"
        "typescript-mode"
        "vertico"
        "visual-fill-column"
        "which-key"
        "webpaste"
        "wgrep"
        "writegood-mode"
        "yaml-mode"
        "yasnippet"
        "yasnippet-snippets"
      ];

      emacsFor = pkgs:
        if pkgs ? emacs30-pgtk then pkgs.emacs30-pgtk
        else if pkgs ? emacs30 then pkgs.emacs30
        else pkgs.emacs;

      emacsWithGnoponPackages = pkgs:
        let
          emacs = emacsFor pkgs;
          epkgs = pkgs.emacsPackagesFor emacs;
        in
          epkgs.emacsWithPackages
            (_: builtins.filter (package: package != null)
              (builtins.map (name:
                if builtins.hasAttr name epkgs then epkgs.${name} else null)
                emacsPackageNames));
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          emacs = emacsWithGnoponPackages pkgs;
          default = self.packages.${system}.emacs;
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
          nodePackages = pkgs.nodePackages_latest or pkgs.nodePackages;
        in
        {
          default = pkgs.mkShell {
            packages = [
              self.packages.${system}.emacs
              pkgs.bun
              pkgs.cargo
              pkgs.direnv
              pkgs.gh
              pkgs.git
              pkgs.jq
              pkgs.nodejs_24
              pkgs.ollama
              pkgs.pandoc
              pkgs.pnpm
              pkgs.ripgrep
              pkgs.rust-analyzer
              pkgs.shellcheck
              pkgs.shfmt
              nodePackages.eslint
              nodePackages.prettier
              nodePackages.typescript-language-server
            ];

            shellHook = ''
              export GNOPONEMACS_ROOT="$PWD"
              echo "GnoponEmacs shell: emacs --init-directory . --chdir $PWD"
            '';
          };
        });

      formatter = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
          pkgs.nixpkgs-fmt);
    };
}
