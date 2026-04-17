#!/usr/bin/env nu

use std log

export const wikidata_auto_series_version = "0.0.1"

export const user_agent = $"wikidata-auto-series/($wikidata_auto_series_version) \(https://github.com/jwillikers/wikidata-auto-series; jordan@jwillikers.com\)"

export const wikidata_base_url = "https://www.wikidata.org/w/rest.php/wikibase/v1"

export const template_variables = [
  publication_date
  publication_year
  open_library_work_id
  librarything_work_id
  goodreads_work_id
  fandom_wiki_article_id
  penguin_random_house_work_id
]

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


# Adds an version, edition, or translation as an edition of a work.
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

# Create individual items in a series using the Wikidata API.
def main [
  template_file: path # Template file to use.
  data_file: path # Data file containing values for template variables for each item.
  --previous: string # Wikidata ID of previous item in the series
] {
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

  let has_part_of_the_series_statement = (
    $template.item.statements | get --optional P179 | is-not-empty
  )

  let has_edition_or_translation_of_statement = (
    $template.item.statements | get --optional P629 | is-not-empty
  )

  let last_index = $data.range | last

  mut created_items = []
  for $index in $data.range {
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
        let value = $item | get --optional $data_field
        if ($value | is-empty) {
          $payload_acc
        } else {
          $payload_acc | str replace --all $"{{ ($data_field) }}" $value
        }
      }
    )
    let payload = (
      if ($created_items | is-not-empty) {
        $payload | str replace --all "{{ previous_wikidata_item }}" ($created_items | last)
      } else if ($previous | is-not-empty) {
        $payload | str replace --all "{{ previous_wikidata_item }}" $previous
      } else {
        $payload | str replace --all "{{ previous_wikidata_item }}" "novalue"
      }
    )
    log debug $"Submitting payload ($payload)"
    log debug $"Running command: http post --content-type application/json --full --headers {User-Agent: '($user_agent)', Accept: 'application/json', Authorization: 'Bearer <WIKIDATA_ACCESS_TOKEN>', X-Authenticated-User: <WIKIDATA_USERNAME>} '($wikidata_base_url)/entities/items'"
    let response = (
      try {
        (
          $payload
          | from json
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
        log error $"Error submitting payload ($payload) to (ansi yellow)($wikidata_base_url)/entities/items(ansi reset): ($error.debug)"
        exit 1
      }
    )
    log debug $"HTTP Response: ($response)"
    if ($response.status != 201) {
      log error $"HTTP error (ansi red)($response.status)(ansi reset) submitting payload ($payload) to (ansi yellow)($wikidata_base_url)/entities/items(ansi reset): ($response.body)"
      exit 1
    }
    let id = $response.body | get --optional id
    if ($id | is-empty) {
      log error $"No Wikidata id found in response ($response.body)"
      exit 1
    }
    $created_items = $created_items | append $id
    sleep 0.3sec
    # Add a Wikidata edition to its corresponding work.
    if $has_edition_or_translation_of_statement and ($item | get --optional wikidata_work_id | is-not-empty) {
      $payload | add_edition_to_work $item.wikidata_work_id $id
    }
    sleep 1sec
  }

  # Go back through each created item and update the followed by statement for the part of the series statement or statements.
  if $has_part_of_the_series_statement {
    $created_items | prepend $previous | reverse | reduce {|it, acc|
      update_part_of_the_series_followed_by $it $acc
      sleep 0.2sec
      $it
    }
  }

  let items_list = $created_items | each {|i| $"https://www.wikidata.org/wiki/($i)"} | str join "\n"
  print $"Wikidata items created:\n($items_list)"
}
