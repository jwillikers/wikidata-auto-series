{
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "wikidata-auto-series";
  version = "0.1.0";

  src = ./.;

  installPhase = ''
    runHook preInstall
    install -D --mode=0644 --target-directory=$out/bin wikidata-auto-series.nu
    install -D --mode=0644 --target-directory=$out/bin template.nu
    runHook postInstall
  '';
}
