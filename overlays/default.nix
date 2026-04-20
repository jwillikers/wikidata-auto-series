_:
{
  isbntools = _final: prev: {
    isbntools = prev.callPackage ./isbntools/package.nix { };
  };
  wikidata-auto-series = _final: prev: {
    wikidata-auto-series = prev.callPackage ../package.nix { };
  };
}
