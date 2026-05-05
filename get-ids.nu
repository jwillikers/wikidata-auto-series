#!/usr/bin/env nu

# Populate work and edition data files with IDs from BookBrainz and Open Library.

use std log
use wikidata-auto-series-lib *

# Loop over each item of the items key in a data file and use BookBrainz and Open Library IDs to fetch missing identifiers.
# It will also attempt to get the publication date for editions.
def main [
  data_file: path # Data file containing values for template variables for each item.
  --type: string # Must be either 'work' or 'edition'. Inferred from filename when omitted.
  --output-file: path # Path of the output file. By default, the input data file is overwritten.
] {
  let id_variables = ($template_variables | where $it not-in [publication_date publication_year])

  let type = (
    if ($type | is-empty) {
      let stem = $data_file | path parse | get stem
      if ($stem | str ends-with "-work-data") {
        "work"
      } else if ($stem | str ends-with "-edition-data") {
        "edition"
      } else {
        log error "Unknown type. Pass 'edition' or 'work' with the --type flag to specify the type."
        exit 1
      }
    } else {
      $type
    }
  )

  let $data = (open $data_file)

  # Verify that all items have unique ids
  for id_variable in $id_variables {
    if ($data | get --optional $id_variable | is-not-empty) {
      let duplicate_identifiers = $data | get $id_variable | uniq --repeated
      if ($duplicate_identifiers | length) > 0 {
        log error $"Duplicate (ansi purple)($id_variable)(ansi reset) identifiers found: (ansi purple)($duplicate_identifiers | str join ' ')(ansi reset)!"
        exit 1
      }
    }
  }

  let items = $data.items | each {|item|
    let empty_ids = $item | empty_identifiers
    if ($empty_ids | is-empty) {
      return $item
    }
    let bookbrainz_work_id = $item | get --optional bookbrainz_work_id
    let bookbrainz_edition_id = $item | get --optional bookbrainz_edition_id
    # First pass, populate with BookBrainz ids.
    let $bookbrainz_identifiers = (
      if ($bookbrainz_work_id | is-not-empty) {
        $bookbrainz_work_id | bookbrainz_get_work_identifiers
      } else if ($bookbrainz_edition_id | is-not-empty) {
        let identifiers = $bookbrainz_edition_id | bookbrainz_get_edition_identifiers
        # log debug $"Output of bookbrainz_get_edition_identifiers: ($identifiers)"
        let publication_date = $bookbrainz_edition_id | bookbrainz_get_edition_publication_date
        # log debug $"Output of bookbrainz_get_edition_publication_date: ($publication_date)"
        let $identifiers = (
          if ($publication_date | is-empty) {
            $identifiers
          } else {
            $identifiers | insert publication_date $publication_date
          }
        )
        $identifiers
      }
    )
    let item = (
      if ($bookbrainz_identifiers | is-empty) {
        $item
      } else {
        $item | merge_identifiers $bookbrainz_identifiers
      }
    )

    # Second pass, populate with Open Library ids.
    let empty_ids = $item | empty_identifiers
    if ($empty_ids | is-empty) {
      return $item
    }

    let open_library_id = $item | get --optional open_library_id
    let open_library_identifiers = (
      if ($open_library_id | is-not-empty) and $type == "work" {
        $open_library_id | open_library_get_work_identifiers
      } else if ($open_library_id | is-not-empty) and $type == "edition" {
        $open_library_id | open_library_get_edition_identifiers
      }
    )
    let item = (
      if ($open_library_identifiers | is-empty) {
        $item
      } else {
        $item | merge_identifiers $open_library_identifiers
      }
    )
    # Rate-limiting
    sleep 0.4sec
    $item
  } | sort-by --natural index

  let data = $data | update items $items

  if ($output_file | is-empty) {
    $data | save --force $data_file
  } else {
    $data | save --force $output_file
  }
}
