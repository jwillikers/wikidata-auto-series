#!/usr/bin/env nu

# Run the tests for wikidata-auto-series-lib
#
# The tests are split into modules under wikidata-auto-series-lib-tests, grouped by functionality.

use wikidata-auto-series-lib-tests/isbn.nu
use wikidata-auto-series-lib-tests/identifiers.nu
use wikidata-auto-series-lib-tests/retry.nu
use wikidata-auto-series-lib-tests/checksums.nu
use wikidata-auto-series-lib-tests/file_formats.nu

def main [] {
  isbn run_tests
  identifiers run_tests
  retry run_tests
  checksums run_tests
  file_formats run_tests
  print $"(ansi green)All tests passed!(ansi reset)"
}
