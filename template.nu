#!/usr/bin/env nu

use std log
use wikidata-auto-series-lib *

# todo Handle multiple values?
# P1274: "isfdb_title_id_1"
# P7823: "bookbrainz_work_id_1"
# P435: "musicbrainz_work_id_1"
# P5813: "musicbrainz_release_id_1"
export const common_template_variables = {
  P8383: "goodreads_work_id"
  P1085: "librarything_work_id"
  P648: "open_library_id"
  P9818: "penguin_random_house_work_id"
  P629: "wikidata_work_id"
  P212: "isbn_13"
  P957: "isbn_10"
  P12351: "bookbrainz_edition_id"
  P5905: "comic_vine_id"
  P2969: "goodreads_version_id"
  P675: "google_books_id"
  P5749: "asin"
  P5680: "hoopla_title_id"
  P1234: "isfdb_publication_id"
  P243: "oclc_number"
  P478: "index" # volume property
}

# Fetch a Wikidata item from the Wikidata API and create a JSON file submission template from it.
def main [
  id: string # Wikidata ID of the item to fetch
  output: path # Path of the template output file
] {
  if "WIKIDATA_USERNAME" not-in $env {
    log error "Set environment WIKIDATA_USERNAME to your Wikidata username"
    exit 1
  }
  if "WIKIDATA_ACCESS_TOKEN" not-in $env {
    log error "Set environment WIKIDATA_ACCESS_TOKEN to your Wikidata access token"
    exit 1
  }
  if $id !~ '^Q[0-9]+$' {
    log error $"The Wikidata ID (ansi purple)($id)(ansi reset) must be formatted as the letter 'Q' followed by an integer"
    exit 1
  }

  let response = (
    try {
      (
        http get --full --headers {
          "User-Agent": $user_agent
          "Accept": "application/json"
          "Authorization": $"Bearer ($env.WIKIDATA_ACCESS_TOKEN)"
          "X-Authenticated-User": $env.WIKIDATA_USERNAME
        }
        $"($wikidata_base_url)/entities/items/($id)"
      )
    } catch {|error|
      log error $"Error getting Wikidata item ($id) from (ansi yellow)($wikidata_base_url)/entities/items/($id)(ansi reset): ($error.debug)"
      exit 1
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting Wikidata item ($id) from (ansi yellow)($wikidata_base_url)/entities/items/($id)(ansi reset): ($response.body)"
    exit 1
  }
  let item = $response.body | reject type sitelinks id
  let template = {
    item: $item
    comment: ""
  }

  # Remove P747 from the template.
  let template = (
    $template
    | reject --optional item.statements.P747
  )

  # todo Remove references.

  # Remove statement ids
  let template = (
    $template
    | update item.statements (
      $template.item.statements | columns | reduce --fold {} {|it, acc|
        $acc | insert $it (
          $template.item.statements | get $it | reject --optional id
        )
      }
    )
  )

  # Inject publication date template.
  let template = (
    if "P577" in ($template.item.statements | columns) {
      $template | update item.statements (
        $template.item.statements
        # | reject --optional P577
        | upsert P577 [
          {
            "rank": "normal",
            "qualifiers": [],
            "references": [],
            "property": {
              "id": "P577",
              "data_type": "time"
            },
            "value": {
              "type": "value",
              "content": {
                "time": "+{{ publication_date }}T00:00:00Z",
                "precision": 11,
                "calendarmodel": "http://www.wikidata.org/entity/Q1985727"
              }
            }
          }
        ]
      )
    } else {
      $template
    }
  )

  # Template P179 part of the series index
  let template = (
    if "P179" in ($template.item.statements | columns) {
      $template | update item.statements.P179 (
        $template.item.statements.P179 | each {|statement|
          $statement | update qualifiers (
            $statement.qualifiers
            # todo What to do if there are multiple qualifiers of the property P1545?
            | where property.id != "P1545"
            | prepend (
              $statement.qualifiers
              | where property.id == "P1545"
              | first
              | update value.content "{{ index }}"
            )
            | where property.id != "P155"
            | insert 1 (
              $statement.qualifiers
              | where property.id == "P155"
              | first
              | update value {
                type: "value"
                content: "{{ previous_wikidata_item }}"
              }
            )
          )
        }
      )
    } else {
      $template
    }
  )

  # Inject template variables for common properties.
  let template = (
    $template
    | update item.statements (
      $template.item.statements | columns | reduce --fold {} {|it, acc|
        let template_variable = $common_template_variables | get --optional $it
        if ($template_variable | is-empty) {
          $acc | insert $it ($template.item.statements | get $it)
        } else {
          $acc | insert $it (
            $template.item.statements | get $it | update value.content $"{{ ($template_variable) }}"
          )
        }
      }
    )
  )

  # todo Attempt to template {{ index }} in labels, aliases, and titles.

  $template | save --force $output
}
