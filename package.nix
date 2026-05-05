{
  isbntools,
  lib,
  makeWrapper,
  b3sum,
  rhash,
  stdenvNoCC,
  zip,
}:
stdenvNoCC.mkDerivation {
  pname = "wikidata-auto-series";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -D --mode=0755 --target-directory=$out/bin get-cover-art-archive-id.nu
    install -D --mode=0755 --target-directory=$out/bin get-ids.nu
    install -D --mode=0755 --target-directory=$out/bin submit-checksums.nu
    install -D --mode=0755 --target-directory=$out/bin template.nu
    install -D --mode=0755 --target-directory=$out/bin wikidata-auto-series.nu
    install -D --mode=0644 --target-directory=$out/bin/wikidata-auto-series-lib wikidata-auto-series-lib/mod.nu
    wrapProgram $out/bin/get-ids.nu \
      --prefix PATH : ${
        lib.makeBinPath [
          isbntools
        ]
      }
    wrapProgram $out/bin/submit-checksums.nu \
      --prefix PATH : ${
        lib.makeBinPath [
          b3sum
          rhash
          zip
        ]
      }
    wrapProgram $out/bin/wikidata-auto-series.nu \
      --prefix PATH : ${
        lib.makeBinPath [
          isbntools
        ]
      }
    runHook postInstall
  '';
}
