use std log

export const wikidata_auto_series_version = "0.0.1"

export const user_agent = $"wikidata-auto-series/($wikidata_auto_series_version) \(https://github.com/jwillikers/wikidata-auto-series; jordan@jwillikers.com\)"

export const wikidata_base_url = "https://www.wikidata.org/w/rest.php/wikibase/v1"

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
  viz_media_id
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
  kobo_data_size
  pdf_data_size
  pdf_blake3
  pdf_sha3_512
  drm_free_epub_blake3
  drm_free_epub_sha3_512
  drm_free_epub_data_size
  kobo_url
  overdrive_uuid
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

export def into_isbn10 []: [string -> string] {
  let isbn = $in
  let result = do { ^to_isbn10 $isbn } | complete
  if ($result.exit_code != 0) {
    log error $"Error converting ISBN13 (ansi yellow)($isbn)(ansi reset) to ISBN10: ($result.stderr)"
    return null
  }
  if ($result.stdout | is-empty) {
    log error $"No ISBN output from to_isbn10 for ISBN (ansi yellow)($isbn)(ansi reset)"
    return null
  }
  $result.stdout | str trim
}

export def update_part_of_the_series_followed_by [
  item_id: string # Wikidata id of the item to modify
  next_item_id: string # Wikidata id of the next item in the series
] {
  log debug $"Updating followed by qualifier for part of the series statement for item ($item_id) to point to next item in series ($next_item_id)"
  # Get 'Part of the series' statement(s)
  let response = (
    try {
      (
        http get --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_base_url)/entities/items/($item_id)/statements"
      )
    } catch {|error|
      log error $"Error getting Wikidata item ($item_id) from (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements(ansi reset): ($error.debug)"
      exit 1
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Wikidata item ($item_id) from (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements(ansi reset): ($response.body)"
    exit 1
  }
  let p179_statements = $response.body.P179 | each {|p179_statement|
    # Update value for each P156 qualifier
    let qualifiers = $p179_statement | get qualifiers
    let p156_qualifiers = $qualifiers | where property.id == "P156" | each {|p156_qualifier|
      $p156_qualifier | update value {
        type: "value"
        content: $next_item_id
      }
    }
    $p179_statement | update qualifiers ($qualifiers | where property.id != "P156" | append $p156_qualifiers)
  }
  sleep 0.2sec
  $p179_statements | each {|p179_statement|
    let payload = $p179_statement | each {|statement|
      {
        statement: ($statement | reject id)
        tags: [],
        bot: false,
        comment: $"Updated followed by qualifier for part of the series statement for item ($item_id) to point to next item in series ($next_item_id)"
      }
    } | to json
    log debug $"Statement update payload: \n($payload)\n"
    let response = (
      try {
        (
          $payload | http put --content-type "application/json" --full --headers {
            "User-Agent": $user_agent
            "Accept": "application/json"
            "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
            "X-Authenticated-User": $env.WIKIDATA_USERNAME
          }
          $"($wikidata_base_url)/entities/items/($item_id)/statements/($p179_statement.id)"
        )
      } catch {|error|
        log error $"Error updating Wikidata statement id ($p179_statement.id) at (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements/($p179_statement.id)(ansi reset): ($error.debug)"
        exit 1
      }
    )
    if ($response.status != 200) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) patching Wikidata item ($item_id) from (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements/($p179_statement.id)(ansi reset): ($response.body)"
      exit 1
    }
    sleep 0.2sec
  }
}

# Adds a version, edition, or translation as an edition of a work.
#
# Currently, this only works well for books and not audiobooks.
# todo Add support for including the duration for audiobooks.
export def add_edition_to_work [
  wikidata_work_id: string
  wikidata_edition_id: string
]: record -> nothing {
  let wikidata_edition_payload = $in
  # Reuse properties from edition payload.
  # Only use property and value fields.
  let qualifiers = (
    $wikidata_edition_payload.item.statements
    | select --optional P123 P212 P407 P437 P577
    | items {|property, statements|
      $statements | each {|statement|
        log debug $"statement: ($statement | to nuon)"
        $statement | select property value
      }
    } | flatten
  )
  let payload = {
    "statement": {
      "rank": "normal",
      "property": {
        "id": "P747",
        "data_type": "wikibase-item"
      },
      "value": {
        "type": "value",
        "content": $wikidata_edition_id
      },
      "qualifiers": $qualifiers,
      "references": []
    },
    "tags": [],
    "bot": false,
    "comment": $"Adding edition ($wikidata_edition_id) to work ($wikidata_work_id)"
  }
  log debug $"Statement add payload: \n($payload | to json)\n"
  let response = (
    try {
      (
        $payload | to json | http post --content-type "application/json" --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_base_url)/entities/items/($wikidata_work_id)/statements"
      )
    } catch {|error|
      log error $"Error adding edition ($wikidata_edition_id) to work ($wikidata_work_id) at (ansi yellow)($wikidata_base_url)/entities/items/($wikidata_work_id)/statements(ansi reset): ($error.debug)"
      exit 1
    }
  )
  if ($response.status != 201) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) submitting edition or translation of statement to Wikidata item ($wikidata_work_id) at (ansi yellow)($wikidata_base_url)/entities/items/($wikidata_work_id)/statements(ansi reset): ($response.body)"
    exit 1
  }
  sleep 0.2sec
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

export const bookbrainz_identifier_translation_table = {
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
  "LCCN (Library of Congress Control Number)": "library_of_congress_item_id"
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
  --retry-delay: duration = 15sec # The interval between successive attempts when there is a failure
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

export const open_library_edition_identifier_translation_table = {
  "amazon": "asin"
  "goodreads": "goodreads_version_id"
  # "ISBN-13": "isbn_13"
  # "ISBN-10": "isbn_10"
  "bookbrainz": "bookbrainz_edition_id"
  "google": "google_books_id"
  "overdrive": "overdrive_uuid"
  # "wikidata": "wikidata_edition_id"
}

# Fetch the identifiers for an Open Library edition
export def open_library_get_edition_identifiers [
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 15sec # The interval between successive attempts when there is a failure
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
      $identifiers | reject --optional storygraph | columns | reduce --fold {} {|id, acc|
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
    if ($response.body | get --optional $id | is-empty) {
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

export def merge_identifiers [
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

export def empty_identifiers []: record -> list {
  let item = $in
  $item | columns | reduce {|id, acc|
    if ($item | get --optional $id | is-empty) {
      $acc | append $id
    } else {
      $acc
    }
  }
}

# Calculate the SHA3-512 checksum for a file using rhash.
export def hash_sha3_512 []: [string -> string] {
  # File for which to generate the checksum.
  let file = $in
  if ($file | is-empty) {
    error make {
      msg: "no file provided"
      labels: [
        {text: "in" span: (metadata $in).span}
      ]
      help: "pipe in the path of the file to hash"
    }
  }
  log debug $"Running command: (ansi yellow)^rhash --printf '%x{sha3-512}' '($file)'(ansi reset)"
  let result = do { ^rhash --printf '%x{sha3-512}' $file } | complete
  if ($result.exit_code != 0) {
    error make {
      msg: "non-zero exit code from rhash while calculating SHA3-512 checksum"
      labels: [
        {text: "result.exit_code" span: (metadata $result.exit_code).span}
      ]
      help: $"error calculating the SHA3-512 checksum for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  if ($result.stdout | is-empty) {
    error make {
      msg: "missing SHA3-512 checksum in stdout"
      labels: [
        {text: "result.stdout" span: (metadata $result.stdout).span}
      ]
      help: $"no SHA3-512 checksum output by rhash for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  $result.stdout | str trim
}

# Calculate the BLAKE3 checksum for a file using the b3sum utility.
export def hash_blake3 []: [string -> string] {
  # File for which to generate the checksum.
  let file = $in
  if ($file | is-empty) {
    error make {
      msg: "no file provided"
      labels: [
        {text: "in" span: (metadata $in).span}
      ]
      help: "pipe in the path of the file to hash"
    }
  }
  log debug $"Running command: (ansi yellow)^b3sum --no-names '($file)'(ansi reset)"
  let result = do { ^b3sum --no-names $file } | complete
  if ($result.exit_code != 0) {
    error make {
      msg: "non-zero exit code from b3sum while calculating the BLAKE3 checksum"
      labels: [
        {text: "result.exit_code" span: (metadata $result.exit_code).span}
      ]
      help: $"error calculating the BLAKE3 checksum for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  if ($result.stdout | is-empty) {
    error make {
      msg: "missing BLAKE3 checksum in stdout"
      labels: [
        {text: "result.stdout" span: (metadata $result.stdout).span}
      ]
      help: $"no BLAKE3 checksum output by b3sum for the file (ansi yellow)($file)(ansi reset): ($result.stderr)"
    }
  }
  $result.stdout | str trim
}

# List the files in a zip archive
export def list_files_in_archive []: path -> list<path> {
  let archive = $in
  (
    ^unzip -l $archive
    | lines
    | drop nth 0 1
    | drop 2
    | str trim
    | parse "{length}  {date} {time}   {name}"
    | get name
    | uniq
    | sort
  )
}

# Get the the associated file extensions for a given file.
#
# This returns multiple file extensions when a ZIP archive is provided.
export def list_file_extensions_for_file []: [path -> list<string>] {
  let file = $in
  if ($file | is-empty) {
    error make {
      msg: "no file provided"
      labels: [
        {text: "in" span: (metadata $in).span}
      ]
      help: "pipe in the path of the file to determine its file formats"
    }
  }
  let components = $file | path parse
  # ^file --brief --mime-type $file
  if ($components.extension | str downcase) in ["cbz", "zip"] {
    [($components.extension | str downcase)] | append (
      $file
      | list_files_in_archive
      | path parse
      | get extension
      | where ($it | is-not-empty)
      | str downcase
      | each {|extension|
        if $extension == "jpeg" {
          "jpg"
        } else {
          $extension
        }
      }
      | uniq
    )
  } else {
    [($components.extension | str downcase)]
  }
}

export const wikidata_file_extension_format_map = {
  "aax": "Q27960055"
  "cbz": "Q109335570"
  "epub": "Q27196933" # Assume EPUB is EPUB3 for now.
  "epub2": "Q56230180"
  "epub3": "Q27196933"
  "jpg": "Q26329975"
  "jpeg": "Q26329975"
  "m4a": "Q136095526"
  "m4b": "Q136095526"
  "mp3": "Q42591"
  "png": "Q178051"
  "pdf": "Q42332"
  "zip": "Q136218"
}

# Map file extensions to their corresponding Wikidata item IDs.
export def map_file_extensions_to_wikidata_file_formats [
  --epub-version: int = 3 # Assume ePUB files to be this ePUB version, which must be either 2 or 3.
]: [list<string> -> list<string>] {
  let file_extensions = $in
  if ($file_extensions | is-empty) {
    return []
  }
  $file_extensions | each {|file_extension|
    if $file_extension == "epub" {
      $wikidata_file_extension_format_map | get $"epub($epub_version)"
    } else {
      $wikidata_file_extension_format_map | get $file_extension
    }
  }
}

# Submit a data size (P3575) statement to a Wikidata item.
export def submit_data_size [
  item_id: string # Wikidata id to which to add the checksum.
]: [
  record<data_size: filesize, distributors: list<string>, file_formats: list<string>, edition_number: string> -> nothing
] {
  let data = $in
  let data_size_mib = (
    $data.data_size | format filesize MiB | split row ' ' | first
  )
  let qualifiers = [] | append (
    $data.file_formats | each {|file_format|
      {
        "property": {
          "id": "P2701",
          "data_type": "wikibase-item"
        },
        "value": {
          "type": "value",
          "content": $file_format
        }
      }
    }
  ) | append (
    $data.distributors | each {|distributor|
      {
        "property": {
          "id": "P750",
          "data_type": "wikibase-item"
        },
        "value": {
          "type": "value",
          "content": $distributor
        }
      }
    }
  ) | append (
    if ($data.edition_number | is-empty) {

    } else {
      {
        "property": {
          "id": "P393",
          "data_type": "string"
        },
        "value": {
          "type": "value",
          "content": $data.edition_number
        }
      }
    }
  )
  let payload = {
    "statement": {
      "rank": "normal",
      "qualifiers": $qualifiers
      "references": [],
      "property": {
        "id": "P3575",
        "data_type": "quantity"
      },
      "value": {
        "type": "value",
        "content": {
          "amount": $"+($data_size_mib)",
          "unit": "http://www.wikidata.org/entity/Q79758"
        }
      }
    },
    "tags": [],
    "bot": false,
    "comment": ""
  }
  let response = (
    try {
      (
        $payload | http post --content-type "application/json" --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_base_url)/entities/items/($item_id)/statements"
      )
    } catch {|error|
      log error $"Error submitting data size Wikidata statement to (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements(ansi reset): ($error.debug)"
      exit 1
      # error make {
      #   msg: "no file provided"
      #   labels: [
      #     {text: "in" span: (metadata $in).span}
      #   ]
      #   help: "pipe in the path of the file to determine its file formats"
      # }
    }
  )
  if ($response.status != 201) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) submitting data size Wikidata statement for Wikidata item ($item_id) to (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements(ansi reset): ($response.body)"
    exit 1
  }
}

# Submit a file checksum and the corresponding data size to a Wikidata item.
export def submit_checksum [
  item_id: string # Wikidata id to which to add the checksum.
]: [
  record<algorithm: string, checksum: string, data_size: filesize, distributors: list<string>, file_formats: list<string>, edition_number: string> -> nothing
] {
  let data = $in
  let data_size_mib = (
    $data.data_size | format filesize MiB | split row ' ' | first
  )
  let qualifiers = [
    {
      "property": {
        "id": "P459",
        "data_type": "wikibase-item"
      },
      "value": {
        "type": "value",
        "content": $data.algorithm
      }
    },
    {
      "property": {
        "id": "P3575",
        "data_type": "quantity"
      },
      "value": {
        "type": "value",
        "content": {
          "amount": $"+($data_size_mib)",
          "unit": "http://www.wikidata.org/entity/Q79758"
        }
      }
    },
  ] | append (
    $data.file_formats | each {|file_format|
      {
        "property": {
          "id": "P2701",
          "data_type": "wikibase-item"
        },
        "value": {
          "type": "value",
          "content": $file_format
        }
      }
    }
  ) | append (
    $data.distributors | each {|distributor|
      {
        "property": {
          "id": "P750",
          "data_type": "wikibase-item"
        },
        "value": {
          "type": "value",
          "content": $distributor
        }
      }
    }
  ) | append (
    if ($data.edition_number | is-empty) {

    } else {
      {
        "property": {
          "id": "P393",
          "data_type": "string"
        },
        "value": {
          "type": "value",
          "content": $data.edition_number
        }
      }
    }
  )
  let payload = {
    "statement": {
      "rank": "normal",
      "qualifiers": $qualifiers
      "references": [],
      "property": {
        "id": "P4092",
        "data_type": "string"
      },
      "value": {
        "type": "value",
        "content": $data.checksum
      }
    },
    "tags": [],
    "bot": false,
    "comment": ""
  }
  let response = (
    try {
      (
        $payload | http post --content-type "application/json" --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_base_url)/entities/items/($item_id)/statements"
      )
    } catch {|error|
      log error $"Error submitting data size Wikidata statement to (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements(ansi reset): ($error.debug)"
      exit 1
      # error make {
      #   msg: "no file provided"
      #   labels: [
      #     {text: "in" span: (metadata $in).span}
      #   ]
      #   help: "pipe in the path of the file to determine its file formats"
      # }
    }
  )
  if ($response.status != 201) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) submitting data size Wikidata statement for Wikidata item ($item_id) to (ansi yellow)($wikidata_base_url)/entities/items/($item_id)/statements(ansi reset): ($response.body)"
    exit 1
  }
}
