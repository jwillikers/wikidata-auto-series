{
  isbntools,
  lib,
  makeWrapper,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "wikidata-auto-series";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -D --mode=0755 --target-directory=$out/bin wikidata-auto-series.nu
    install -D --mode=0755 --target-directory=$out/bin template.nu
    wrapProgram $out/bin/wikidata-auto-series.nu \
      --prefix PATH : ${
        lib.makeBinPath [
          isbntools
        ]
      }
    runHook postInstall
  '';
}
