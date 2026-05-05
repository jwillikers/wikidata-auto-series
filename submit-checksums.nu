#!/usr/bin/env nu

use std log
use wikidata-auto-series-lib *

# Add file checksums and data sizes to the provided Wikidata item for the provided files.
#
# Calculates SHA3-512 and BLAKE3 checksums for each file.
# Uses the rhash and b3sum utilities.
# The data size is in MiB.
def main [
  wikidata_edition_id: string
  distributors: string # A string of space-separated Wikidata item IDs for each distributor.
  ...files: path
  --epub-version: int = 3 # The EPUB version to use for EPUB files, either 2 or 3.
  --edition-number: string = "" # Relevant edition number, if applicable
  --point-in-time: string # Date time to use for point in time. Now is used by default.
] {
  # todo Verify that wikidata_edition_id is a version, edition, or translation, to ensure it doesn't get swapped with the distributors.
  # todo Verify that distributors are of the correct type
  # todo Check before submitting that an existing statement doesn't already exist for data size and checksums

  if "WIKIDATA_USERNAME" not-in $env {
    log error "Set environment WIKIDATA_USERNAME to your Wikidata username"
    exit 1
  }
  if "WIKIDATA_ACCESS_TOKEN" not-in $env {
    log error "Set environment WIKIDATA_ACCESS_TOKEN to your Wikidata access token"
    exit 1
  }

  let point_in_time = (
    if ($point_in_time | is-empty) {
      date now
    } else {
      $point_in_time | into datetime
    }
  )

  let wd_distributors = $distributors | split row ' '
  $files | each {|file|
    log debug $"Processing file (ansi yellow)($file)(ansi reset)"
    let sha3_512_checksum = $file | hash_sha3_512
    let blake3_checksum = $file | hash_blake3
    let data_size = (
      du $file | first | get physical
    )
    # log debug $"list_file_extensions_for_file: ($file | list_file_extensions_for_file)"
    let wd_file_formats = $file | list_file_extensions_for_file | map_file_extensions_to_wikidata_file_formats --epub-version $epub_version
    {
      data_size: $data_size
      distributors: $wd_distributors
      file_formats: $wd_file_formats
      edition_number: $edition_number
      point_in_time: $point_in_time
    } | submit_data_size $wikidata_edition_id
    sleep 0.2sec
    {
      algorithm: "Q81575705" # BLAKE3
      checksum: $blake3_checksum
      data_size: $data_size
      distributors: $wd_distributors
      file_formats: $wd_file_formats
      edition_number: $edition_number
      point_in_time: $point_in_time
    } | submit_checksum $wikidata_edition_id
    sleep 0.2sec
    {
      algorithm: "Q110651449" # SHA3-512
      checksum: $sha3_512_checksum
      data_size: $data_size
      distributors: $wd_distributors
      file_formats: $wd_file_formats
      edition_number: $edition_number
      point_in_time: $point_in_time
    } | submit_checksum $wikidata_edition_id
    sleep 0.2sec
  }
}
