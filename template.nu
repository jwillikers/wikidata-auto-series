#!/usr/bin/env nu

use std log

export const wikidata_auto_series_version = "0.0.1"

export const user_agent = $"wikidata-auto-series/($wikidata_auto_series_version) \(https://github.com/jwillikers/wikidata-auto-series; jordan@jwillikers.com\)"

export const wikidata_base_url = "https://www.wikidata.org/w/rest.php/wikibase/v1"

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
  {
    item: $item
    comment: ""
  } | save --force $output
}
