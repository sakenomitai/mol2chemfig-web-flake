{
  description = "mol2chemfig-web: turn SMILES and molfiles into chemfig code and PDFs in the browser";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Upstream has no flake and has been untouched since 2015. Pinned to the
    # commit patches/python3.patch is written against.
    mol2chemfig-web-src = {
      url = "github:py-chemist/mol2chemfig-web/fe2be5ec5b704cb30792a5115338c601d919b702";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      mol2chemfig-web-src,
    }:
    let
      # Linux only: Indigo comes from prebuilt manylinux wheels
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ self.overlays.default ];
            }
          )
        );
    in
    {
      overlays.default = final: prev: {
        mol2chemfig-web = final.callPackage ./nix/package.nix { src = mol2chemfig-web-src; };

        pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
          (pyFinal: pyPrev: {
            epam-indigo = pyFinal.callPackage ./nix/epam-indigo.nix { };
            pubchempy = pyFinal.callPackage ./nix/pubchempy.nix { };
          })
        ];
      };

      packages = forAllSystems (pkgs: {
        default = pkgs.mol2chemfig-web;
        mol2chemfig-web = pkgs.mol2chemfig-web;
        epam-indigo = pkgs.python3Packages.epam-indigo;
        pubchempy = pkgs.python3Packages.pubchempy;
      });

      nixosModules = {
        default = self.nixosModules.mol2chemfig-web;
        mol2chemfig-web = import ./nix/module.nix self;
      };

      # Python with Flask, Indigo and PubChemPy, plus pdflatex with chemfig,
      # for hacking on a patched checkout
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.mol2chemfig-web.pythonEnv
            pkgs.mol2chemfig-web.tex
          ];
        };
      });

      # checks = forAllSystems (pkgs: {
      #   package = pkgs.mol2chemfig-web;

      #   smoke =
      #     pkgs.runCommand "mol2chemfig-web-smoke-test"
      #       { nativeBuildInputs = [ pkgs.mol2chemfig-web.pythonEnv ]; }
      #       ''
      #         export HOME=$TMPDIR MOL2CHEMFIG_DATA_DIR=$TMPDIR
      #         python ${./nix/smoke-test.py} ${pkgs.mol2chemfig-web}/share/mol2chemfig-web
      #         touch $out
      #       '';
      # });
    };
}
