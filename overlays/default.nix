_: {
  isbnlib2 = final: prev: {
    pythonPackagesOverlays = (prev.pythonPackagesOverlays or [ ]) ++ [
      (python-final: _python-prev: {
        isbnlib = python-final.callPackage ./isbnlib2/package.nix { };
      })
    ];

    python3 =
      let
        self = prev.python3.override {
          inherit self;
          packageOverrides = prev.lib.composeManyExtensions final.pythonPackagesOverlays;
        };
      in
      self;

    python3Packages = final.python3.pkgs;
  };
  isbntools = _final: prev: {
    isbntools = prev.callPackage ./isbntools/package.nix { };
  };
  wikidata-auto-series = _final: prev: {
    wikidata-auto-series = prev.callPackage ../package.nix { };
  };
}
