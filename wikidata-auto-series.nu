#!/usr/bin/env nu

# https://www.mediawiki.org/wiki/Manual:Rate_limits
# Rate Limits are:
# user: 8 edits per minute.
# autoconfirmed user (4+ days old account): 90 edits per minute.

use std log

use wikidata-auto-series-lib *

# Create individual items in a series using the Wikidata API.
def main [
  template_file: path # Template file to use.
  data_file: path # Data file containing values for template variables for each item.
  --previous: string # Wikidata ID of previous item in the series
] {
  let id_variables = ($template_variables | where $it not-in [publication_date publication_year])

  if not ($data_file | path parse | get stem | str ends-with "-data") {
    log warning $"Data file (ansi yellow)($data_file)(ansi reset) doesn't end with '-data', is it the correct file?"
    sleep 5sec
  }
  if not ($template_file | path parse | get stem | str ends-with "-template") {
    log warning $"Template file (ansi yellow)($template_file)(ansi reset) doesn't end with '-template', is it the correct file?"
    sleep 5sec
  }

  let $data = (open $data_file)
  let template = (open $template_file)

  if "WIKIDATA_USERNAME" not-in $env {
    log error "Set environment WIKIDATA_USERNAME to your Wikidata username"
    exit 1
  }
  if "WIKIDATA_ACCESS_TOKEN" not-in $env {
    log error "Set environment WIKIDATA_ACCESS_TOKEN to your Wikidata access token"
    exit 1
  }

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

  let has_part_of_the_series_statement = (
    $template.item.statements | get --optional P179 | is-not-empty
  )

  let has_edition_or_translation_of_statement = (
    $template.item.statements | get --optional P629 | is-not-empty
  )

  let last_index = $data.range | last

  let created_items = $data.range | reduce --fold [] {|index, created_items|
    let items = (
      $data
      | get --optional items
      | where index == $index
    )
    if ($items | length) > 1 {
      log error $"Duplicate items with index (ansi yellow)($index)(ansi reset) exist"
      exit 1
    }
    let item = $items | first
    let item = $item | upsert publication_year (
      $item.publication_date | split row '-' | first
    )
    let payload = (
      $template
      | to json
      | str replace --all '{{ index }}' $index
    )
    let payload = (
      $template_variables
      | reduce --fold $payload {|data_field, payload_acc|
        let value = (
          if $data_field == "isbn_10" {
            let isbn13 = $item | get --optional isbn_13
            if ($isbn13 | is-not-empty) and ($isbn13 | str starts-with "978") {
              let isbn10 = $isbn13 | str trim | into_isbn10 | hyphenate_isbn
              if ($isbn10 | is-empty) {
                log warning $"Error attempting to produce ISBN-10 from the ISBN-13 (ansi purple)($isbn13)(ansi reset). Attempting to use ISBN-10 if set instead."
                $item | get --optional $data_field
              } else {
                log debug $"Produced ISBN-10 (ansi purple)($isbn10)(ansi reset) from ISBN-13 (ansi purple)($isbn13)(ansi reset)"
                $isbn10
              }
            } else {
              $item | get --optional $data_field
            }
          } else {
            $item | get --optional $data_field
          }
        )
        if ($value | is-empty) {
          $payload_acc
        } else {
          let value = (
            if $data_field in ["isbn_10", "isbn_13"] {
              let isbn = $value | hyphenate_isbn
              if ($isbn | is-empty) {
                log error $"Error hyphenating ISBN value (ansi yellow)($value)(ansi reset) for item with index (ansi yellow)($index)(ansi reset)"
                exit 1
              }
              $isbn
            } else {
              $value
            }
          )
          $payload_acc | str replace --all $"{{ ($data_field) }}" $value
        }
      }
    )
    let payload = (
      if ($created_items | is-not-empty) {
        $payload | str replace --all "{{ previous_wikidata_item }}" ($created_items | last)
      } else if ($previous | is-not-empty) {
        $payload | str replace --all "{{ previous_wikidata_item }}" $previous
      } else if ($payload | from json | get --optional item.statements.P179 | is-not-empty) {
        let p179 = $payload | from json | get item.statements.P179
        $payload | from json | update item.statements.P179 (
          $p179 | each {|statement|
            let qualifiers = $statement.qualifiers
            $statement | update qualifiers (
              $qualifiers
              | each {|qualifier|
                if $qualifier.property.id == "P155" {
                  $qualifier | update value {
                    type: "novalue"
                  }
                } else {
                  $qualifier
                }
              }
            )
          }
        ) | to json
      } else {
        $payload
      }
    )
    # Check for any remaining template arguments.
    $payload | lines | each {|line|
      if $line =~ '"{{ [a-zA-Z0-9_-]+ }}"' {
        error make {
          msg: "unsubstituted template variable"
          labels: [
            {text: "line" span: (metadata $line).span}
          ]
          help: $"unsubstituted template variable for index (ansi purple)($index)(ansi reset): (ansi red)($line)(ansi reset)"
        }
      }
    }
    let payload = $payload | from json
    log debug $"Submitting payload ($payload | to json)"
    log debug $"Running command: http post --content-type application/json --full --headers {User-Agent: '($user_agent)', Accept: 'application/json', Authorization: 'Bearer <WIKIDATA_ACCESS_TOKEN>', X-Authenticated-User: <WIKIDATA_USERNAME>} '($wikidata_base_url)/entities/items'"
    let response = (
      try {
        (
          $payload
          | (
            http post
              --content-type "application/json"
              --full
              --headers {
                "User-Agent": $user_agent
                "Accept": "application/json"
                "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
                "X-Authenticated-User": $env.WIKIDATA_USERNAME
              }
              $"($wikidata_base_url)/entities/items"
          )
        )
      } catch {|error|
        log error $"Error submitting payload ($payload | to json) to (ansi yellow)($wikidata_base_url)/entities/items(ansi reset): ($error.debug)"
        exit 1
      }
    )
    log debug $"HTTP Response: ($response)"
    if ($response.status != 201) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) submitting payload ($payload | to json) to (ansi yellow)($wikidata_base_url)/entities/items(ansi reset): ($response.body)"
      exit 1
    }
    let id = $response.body | get --optional id
    if ($id | is-empty) {
      log error $"No Wikidata id found in response ($response.body)"
      exit 1
    }
    sleep 0.3sec
    # Add a Wikidata edition to its corresponding work.
    if $has_edition_or_translation_of_statement and ($item | get --optional wikidata_work_id | is-not-empty) {
      $payload | add_edition_to_work $item.wikidata_work_id $id
    }
    if $has_part_of_the_series_statement {
      if ($previous | is-not-empty) or ($created_items | is-not-empty) {
        let previous_item = (
          if ($created_items | is-empty) {
            $previous
          } else {
            $created_items | last
          }
        )
        update_part_of_the_series_followed_by $previous_item $id
      }
    }
    sleep 1sec
    $created_items | append $id
  }

  # todo Is it necessary to check for an error here?
  # https://github.com/nushell/nushell/issues/10633
  # $created_items | each {|created_item|
  #   try {
  #     $created_item
  #   } catch {|error|

  #   }
  # }

  let items_list = $created_items | each {|i|
    $"https://www.wikidata.org/wiki/($i)" | ansi link --text $i
  } | str join "\n"
  print $"Wikidata items created:\n($items_list)"
}
