{
  lib,
  stdenvNoCC,
  src,
  fetchurl,
  makeWrapper,
  python3,
  texliveBasic,
}:

let
  pythonEnv = python3.withPackages (ps: [
    ps.epam-indigo
    ps.flask
    ps.gunicorn
    ps.pubchempy
  ]);

  # everything the generated LaTeX documents and mol2chemfig.sty load;
  # geometry, psnfss, tools and oberdiek (twoopt) are part of texliveBasic
  tex = texliveBasic.withPackages (ps: [
    ps.chemfig
    ps.helvetic
    ps.ifmtarg
    ps.pgf
    ps.sfmath
    ps.simplekv
    ps.xcolor
    ps.xstring
  ]);

  # The repository ships mol2chemfig.sty v1.4, which wraps \setbondstyle and
  # other chemfig internals that chemfig 1.5 removed. v1.5 from CTAN works
  # with current chemfig and defines the same macros.
  mol2chemfigSty = fetchurl {
    url = "https://mirrors.ctan.org/graphics/mol2chemfig/latex/mol2chemfig.sty";
    hash = "sha256-6TFly3Db6xilihN8jPC+ErbBlT5WqEj69MXNlnfUnzE=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "mol2chemfig-web";
  version = "0-unstable-2015-03-13";

  inherit src;

  # the patch is against LF line endings; upstream pdfgen.py uses CRLF
  prePatch = ''
    find . -name '*.py' -exec sed -i 's/\r$//' {} +
  '';

  patches = [ ../patches/python3.patch ];

  postPatch = ''
    rm -f mol2chemfig/*.pyc
    cp ${mol2chemfigSty} mol2chemfig/mol2chemfig.sty
    substituteInPlace mol2chemfig/pdfgen.py \
      --replace-fail "pdflatex = 'pdflatex'" "pdflatex = '${tex}/bin/pdflatex'"
  '';

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    app=$out/share/mol2chemfig-web
    mkdir -p $app
    cp -r app.py chemistry mol2chemfig static templates $app/

    # coordinates.py is a stray text note, not Python
    ${pythonEnv.interpreter} -m compileall -q -x 'coordinates\.py$' $app

    makeWrapper ${pythonEnv}/bin/gunicorn $out/bin/mol2chemfig-web \
      --add-flags "--chdir $app app:app"

    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv tex;
  };

  meta = {
    description = "Web interface for mol2chemfig: SMILES and molfiles to chemfig code and PDF";
    homepage = "https://github.com/py-chemist/mol2chemfig-web";
    # web interface and ChemDoodle Web Components: GPL-3.0; mol2chemfig: LPPL
    license = [
      lib.licenses.gpl3Only
      lib.licenses.lppl13c
    ];
    mainProgram = "mol2chemfig-web";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
