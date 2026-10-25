# mol2chemfig-web flake

Nix flake for [mol2chemfig-web](https://github.com/py-chemist/mol2chemfig-web),
the Flask front end for mol2chemfig (SMILES / molfile → chemfig code + PDF).

## Use

Run it locally (serves on http://127.0.0.1:8000/mol_2_chemfig):

```sh
nix run .
nix run . -- --bind 0.0.0.0:8080     # extra arguments go to gunicorn
```

On NixOS:

```nix
{
  inputs.mol2chemfig-web.url = "path:/path/to/this/flake";

  outputs = { nixpkgs, mol2chemfig-web, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        mol2chemfig-web.nixosModules.default
        {
          services.mol2chemfig-web = {
            enable = true;
            listenAddress = "127.0.0.1";
            port = 8000;
          };
        }
      ];
    };
  };
}
```

The app's pages and AJAX calls live under `/mol_2_chemfig` at the root of the
host, so a reverse proxy has to forward the whole host (or at least that
prefix) without rewriting paths.

`nix flake check` builds everything, renders a few molecules to PDF in the
build sandbox and boots a NixOS VM test of the module.

## Outputs

| Output | What |
| --- | --- |
| `packages.<system>.default` | the app, wrapped as `bin/mol2chemfig-web` (gunicorn) |
| `packages.<system>.epam-indigo` | Indigo toolkit 1.46.0 from the PyPI manylinux wheels |
| `packages.<system>.pubchempy` | PubChemPy 1.0.5 |
| `nixosModules.default` | `services.mol2chemfig-web` |
| `overlays.default` | adds all of the above to nixpkgs |
| `devShells.<system>.default` | the Python env plus pdflatex with chemfig |

Systems: `x86_64-linux`, `aarch64-linux`.

## What the packaging changes

Upstream is Python 2 code from 2015. `patches/python3.patch` ports it to
Python 3 and current TeX Live; its header lists every change. In short:
2to3 plus fixes for the things 2to3 misses (sorting, bytes, error messages,
removed `base64.encodestring`), `pdflatex` run through `subprocess` with a
timeout and no shell escape, PubChem URLs updated, and the LaTeX template
moved to chemfig ≥ 1.5's `\setchemfig` keys.

The bundled `mol2chemfig.sty` (v1.4) doesn't work with chemfig ≥ 1.5, so the
build swaps in v1.5 from CTAN.

## Known limitations (inherited from upstream)

- The last molecule and page size are kept in global variables, so
  concurrent users can see each other's "Apply" results. The service runs a
  single gunicorn worker so that at least one process holds that state.
- Aromatic (lowercase) SMILES such as `c1ccccc1` are drawn with wavy bonds,
  because mol2chemfig confuses Indigo's aromatic bond order with its "either"
  stereo flag (both are 4). Kekulé SMILES, which the PubChem search returns,
  render correctly.
- The chemfig editor hands user input straight to pdflatex. The systemd unit
  is sandboxed (dynamic user, read-only system, private /tmp), but think twice
  before exposing it to the internet without authentication.
