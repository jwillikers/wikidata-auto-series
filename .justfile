default: check

alias c := check

check: && format
    yamllint .
    asciidoctor *.adoc
    lychee --cache *.html
    nu wikidata-auto-series-lib-tests.nu
    nix flake check

alias f := format
alias fmt := format

format:
    treefmt

alias t := test

test:
    nu wikidata-auto-series-lib-tests.nu

alias u := update
alias up := update

update:
    nix run ".#update-nix-direnv"
    nix run ".#update-nixos-release"
    nix flake update
