#!/usr/bin/env nu

# Populate work and edition data files with IDs from BookBrainz and Open Library.

use std log

export const wikidata_auto_series_version = "0.0.1"

export const user_agent = $"wikidata-auto-series/($wikidata_auto_series_version) \(https://github.com/jwillikers/wikidata-auto-series; jordan@jwillikers.com\)"

# todo Verify each template variable is in the correct format
export const template_variables = [
  publication_date
  publication_year
  zero_padded_index
  subtitle_kanji
  subtitle_kana
  subtitle_hepburn
  subtitle_english
  open_library_id
  # Work identifiers
  librarything_work_id
  goodreads_work_id
  fandom_wiki_article_id
  penguin_random_house_work_id
  isfdb_title_id
  isfdb_title_id_1
  isfdb_title_id_2
  # Edition identifiers
  wikidata_work_id
  isbn_13
  isbn_10
  bookbrainz_edition_id
  oclc_number
  goodreads_version_id
  google_books_id
  asin
  hoopla_title_id
  comic_vine_id
  isfdb_publication_id
  musicbrainz_release_1
  musicbrainz_release_2
]

export def hyphenate_isbn []: [string -> string] {
  let isbn = $in
  let result = do { ^isbn_mask $isbn } | complete
  if ($result.exit_code != 0) {
    log error $"Error hyphenating ISBN (ansi yellow)($isbn)(ansi reset): ($result.stderr)"
    return null
  }
  if ($result.stdout | is-empty) {
    log error $"No ISBN output from isbn_mask for ISBN (ansi yellow)($isbn)(ansi reset)"
    return null
  }
  $result.stdout | str trim
}

# Call a function, retrying up to the given number of retries
export def retry [
  request: closure # The function to call
  should_retry: closure # A closure which determines whether to retry or not based on the result of the request closure. True means retry, false means stop.
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
  ignore_exceptions: bool # Whether to ignore exceptions thrown by the request closure and retry
]: nothing -> any {
  for attempt in 1..($retries - 1) {
    let response = (
      try {
        do $request
      } catch {|error|
        if $ignore_exceptions {
          log warning $"Error during request attempt ($attempt): ($error.debug)"
          continue
        } else {
          throw $error
        }
      }
    )
    if not (do $should_retry $response) {
      return $response
    }
    sleep $delay
  }
  do $request
}

# Make an http call, retrying up to the given number of retries
export def retry_http [
  request: closure # The function to call
  retries: int # The number of retries to perform
  delay: duration # The amount of time to wait between successive executions of the request closure
  http_status_codes_to_retry: list<int> = [408 429 500 502 503 504] # HTTP status codes where the request will be retries
  ignore_exceptions: bool = true # Whether to ignore exceptions thrown by the request closure and retry
]: nothing -> any {
  let should_retry = {|result|
    $result.status in $http_status_codes_to_retry
  }
  retry $request $should_retry $retries $delay $ignore_exceptions
}

const bookbrainz_identifier_translation_table = {
  "Amazon ASIN": "asin"
  "Goodreads Book ID": "goodreads_version_id"
  "ISBN-13": "isbn_13"
  "ISBN-10": "isbn_10"
  "OCN/Worldcat ID": "oclc_number"
  "OpenLibrary Book ID": "open_library_id"
  # "Wikidata Edition ID": "wikidata_item_id"
  # "Wikidata Work ID": "wikidata_work_id"
  "MusicBrainz Work ID": "musicbrainz_work_id"
  "OpenLibrary Work ID": "open_library_id"
  "LibraryThing Work ID": "librarything_work_id"
}

# Fetch the identifiers for a BookBrainz edition
export def bookbrainz_get_edition_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let bookbrainz_edition_id = $in
  let bookbrainz_api_edition_identifiers_url = $"https://api.bookbrainz.org/1/edition/($bookbrainz_edition_id)/identifiers"
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($bookbrainz_api_edition_identifiers_url)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting identifiers for BookBrainz edition ($bookbrainz_edition_id) from (ansi yellow)($bookbrainz_api_edition_identifiers_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting identifiers for BookBrainz edition ($bookbrainz_edition_id) from (ansi yellow)($bookbrainz_api_edition_identifiers_url)(ansi reset): ($response.body)"
    return null
  }
  let identifiers = $response.body.identifiers
  if ($identifiers | is-empty) {

  } else {
    $identifiers | reduce --fold {} {|type_value_pair, acc|
      # todo Handle multiple values here
      let value = (
        if ($type_value_pair.type in ["ISBN-10" "ISBN-13"]) {
          $type_value_pair.value | str replace --all "-" ""
        } else {
          $type_value_pair.value
        }
      )
      try {
        $acc | insert ($bookbrainz_identifier_translation_table | get $type_value_pair.type) $value
      } catch {|error|
        log warning $"Error inserting the value ($value) for identifier ($bookbrainz_identifier_translation_table | get $type_value_pair.type) into the record ($acc). Most likely a duplicate. Ignoring."
        $acc
      }
    }
  }
}

# Get edition publication date for a BookBrainz edition
# Returned in "yyyy-mm-dd" format.
export def bookbrainz_get_edition_publication_date [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let bookbrainz_edition_id = $in
  let bookbrainz_api_edition_url = $"https://api.bookbrainz.org/1/edition/($bookbrainz_edition_id)"
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($bookbrainz_api_edition_url)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting publication date for BookBrainz edition ($bookbrainz_edition_id) from (ansi yellow)($bookbrainz_api_edition_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting identifiers for BookBrainz edition ($bookbrainz_edition_id) from (ansi yellow)($bookbrainz_api_edition_url)(ansi reset): ($response.body)"
    return null
  }
  let publication_date = $response.body | get releaseEventDate
  if ($publication_date | is-not-empty) {
    $publication_date | str replace "+00" ""
  }
}

# Fetch the identifiers for a BookBrainz work
export def bookbrainz_get_work_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let bookbrainz_work_id = $in
  let bookbrainz_api_work_identifiers_url = $"https://api.bookbrainz.org/1/work/($bookbrainz_work_id)/identifiers"
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($bookbrainz_api_work_identifiers_url)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting identifiers for BookBrainz work ($bookbrainz_work_id) from (ansi yellow)($bookbrainz_api_work_identifiers_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting identifiers for BookBrainz work ($bookbrainz_work_id) from (ansi yellow)($bookbrainz_api_work_identifiers_url)(ansi reset): ($response.body)"
    return null
  }
  let identifiers = $response.body.identifiers
  if ($identifiers | is-empty) {

  } else {
    $identifiers | reduce --fold {} {|type_value_pair, acc|
      # todo Handle multiple values here
      try {
        $acc | insert ($bookbrainz_identifier_translation_table | get $type_value_pair.type) $type_value_pair.value
      } catch {|error|
        log warning $"Error inserting the value ($type_value_pair.value) for identifier ($bookbrainz_identifier_translation_table | get $type_value_pair.type) into the record ($acc). Most likely a duplicate. Ignoring."
        $acc
      }
    }
  }
}

# Fetch the identifiers for an Open Library work
export def open_library_get_work_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let open_library_work_id = $in
  let open_library_api_work_url = $"https://openlibrary.org/works/($open_library_work_id).json"
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($open_library_api_work_url)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting identifiers for Open Library work ($open_library_work_id) from (ansi yellow)($open_library_api_work_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting identifiers for Open Library work ($open_library_work_id) from (ansi yellow)($open_library_api_work_url)(ansi reset): ($response.body)"
    return null
  }
  let identifiers = $response.body.identifiers
  if ($identifiers | is-empty) {

  } else {
    $identifiers | columns | reduce --fold {} {|id, acc|
      # todo Handle multiple values here
      let identifier_values = $identifiers | get $id
      if ($identifier_values | length) > 1 {
        log warning $"More than one value for ($id): ($identifiers). Ignoring all but the first value."
      }
      $acc | insert ($id + "_work_id") ($identifier_values | first)
    }
  }
}

const open_library_edition_identifier_translation_table = {
  "amazon": "asin"
  "goodreads": "goodreads_version_id"
  # "ISBN-13": "isbn_13"
  # "ISBN-10": "isbn_10"
  "bookbrainz": "bookbrainz_edition_id"
  "google": "google_books_id"
  # "wikidata": "wikidata_edition_id"
}

# Fetch the identifiers for an Open Library edition
export def open_library_get_edition_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
]: [string -> table] {
  let open_library_edition_id = $in
  let open_library_api_work_url = $"https://openlibrary.org/books/($open_library_edition_id).json"
  let request = {
    (
      http get
        --full
        --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
        }
        $"($open_library_api_work_url)"
    )
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting identifiers for Open Library edition ($open_library_edition_id) from (ansi yellow)($open_library_api_work_url)(ansi reset): ($error.debug)"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting identifiers for Open Library edition ($open_library_edition_id) from (ansi yellow)($open_library_api_work_url)(ansi reset): ($response.body)"
    return null
  }
  let identifiers = (
    let identifiers = $response.body.identifiers;
    if ($identifiers | is-empty) {

    } else {
      $identifiers | reject --optional overdrive storygraph | columns | reduce --fold {} {|id, acc|
        # todo Handle multiple values here
        let values = $identifiers | get $id
        if ($values | length) > 1 {
          log warning $"Multiple values for identifier ($open_library_edition_identifier_translation_table | get $id): ($values). Ignoring all but the first."
        }
        $acc | insert ($open_library_edition_identifier_translation_table | get $id) ($values | first)
      }
    }
  )
  [isbn_10 isbn_13 oclc_numbers publish_date] | reduce --fold $identifiers {|id, acc|
    if ($response.body | $id | is-empty) {
      $acc
    } else {
      if $id == "publish_date" {
        $acc | insert "publication_date" ($response.body | get $id)
      } else {
        let values = $response.body | get --optional $id
        if ($values | is-empty) {
          return $values
        }
        let id = (
          if $id == "oclc_numbers" {
            "oclc_number"
          } else {
            $id
          }
        )
        if ($values | length) > 1 {
          log warning $"Multiple values for identifier ($id): ($values). Ignoring all but the first."
        }
        let value = (
          if $id in ["isbn_10" "isbn_13"] {
            $values | first | str replace --all "-" ""
          } else {
            $values | first
          }
        )
        $acc | insert $id $value
      }
    }
  }
}

def merge_identifiers [
  identifiers2: record # Identifiers to merge with.
]: record -> record {
  let item = $in
  $item | columns | append ($identifiers2 | columns) | uniq | reduce --fold $item {|id, acc|
    # Incorporate IDs from BookBrainz
    if ($item | get --optional $id | is-not-empty) and ($identifiers2 | get --optional $id | is-not-empty) {
      if ($item | get $id) == ($identifiers2 | get $id) {
        # Everything is as expected!
        $acc
      } else {
        log error $"The value (ansi yellow)($item | get $id)(ansi reset) for the (ansi yellow)($id)(ansi reset) identifier is different from the value (ansi yellow)($identifiers2 | get $id)(ansi reset) from the BookBrainz entity. Ignoring BookBrainz identifier."
        $acc
      }
    } else if ($item | get --optional $id | is-empty) and ($identifiers2 | get --optional $id | is-not-empty) {
      # Found identifier on BookBrainz that is not available.
      $acc | upsert $id ($identifiers2 | get $id)
    } else if ($item | get --optional $id | is-not-empty) and ($identifiers2 | get --optional $id | is-empty) {
      # BookBrainz doesn't have this identifier.
      $acc
    } else {
      # Identifier is not available from either.
      $acc
    }
  }
}

def empty_identifiers []: record -> list {
  let item = $in
  $item | columns | reduce {|id, acc|
    if ($item | get --optional $id | is-empty) {
      $acc | append $id
    } else {
      $acc
    }
  }
}

# Loop over each item of the items key in a data file and use BookBrainz and Open Library IDs to fetch missing identifiers.
# It will also attempt to get the publication date for editions.
def main [
  data_file: path # Data file containing values for template variables for each item.
  type: string # Must be either 'work' or 'edition'
  --output-file: path # Path of the output file. By default, the input data file is overwritten.
] {
  let id_variables = ($template_variables | where $it not-in [publication_date publication_year])

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
