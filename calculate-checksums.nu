#!/usr/bin/env nu

use std log
use wikidata-auto-series-lib *

# Add file checksums and data sizes to the provided edition data file.
#
# The provided files must correspond to the each item in the data file's items list in order.
#
# Calculates SHA3-512 and BLAKE3 checksums for each file.
# Uses the rhash and b3sum utilities.
# The data size is in MiB.
def main [
  data_file: path # Data file containing values for template variables for each item.
  ...files: path # The files for which to compute file hashes.
  --output-file: path # Path of the output file. By default, the input data file is overwritten.
] {
  let data = open $data_file
  let difference = ($data.items | length) - ($files | length)
  let files = (
    if ($difference > 0) {
      $files | append (seq 1 $difference | reduce --fold [] {|it acc| $acc | append [""]})
    } else {
      $files
    }
  )
  # log debug $"Files: ($files | str join '\n')"
  let zipped = $data.items | zip $files
  let items = $zipped | each {|zipped_item|
    let item = $zipped_item | get 0
    if ($zipped_item | get --optional 1 | is-empty) {
      return $item
    }
    let file = $zipped_item | get 1
    if not ($file | path exists) {
      log error $"File (ansi yellow)($file)(ansi reset) does not exist!"
      exit 1
    }
    let file_type = $file | path parse | get extension | str downcase
    if ($file_type not-in ["cbz" "epub" "m4b" "mp3" "pdf" "zip"]) {
      log error $"File (ansi yellow)($file)(ansi reset) has unsupported file type (ansi yellow)($file_type)(ansi reset)!"
      exit 1
    }
    let sha3_512_checksum = $file | hash_sha3_512
    let blake3_checksum = $file | hash_blake3
    let data_size = (
      du $file | format filesize MiB physical | first | get physical | str replace "MiB" "" | str trim
    )
    (
      $item
      | upsert $"drm_free_($file_type)_data_size" $data_size
      | upsert $"drm_free_($file_type)_sha3_512" $sha3_512_checksum
      | upsert $"drm_free_($file_type)_blake3" $blake3_checksum
    )
  }

  let data = $data | update items $items

  if ($output_file | is-empty) {
    $data | save --force $data_file
  } else {
    $data | save --force $output_file
  }
}
