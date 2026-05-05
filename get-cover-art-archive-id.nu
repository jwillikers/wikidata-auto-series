#!/usr/bin/env nu

use std log
use wikidata-auto-series-lib *

# Get the cover art image id for a given MusicBrainz release ID in the format required for Wikidata property P14071.
def main [
  musicbrainz_release_id: string
] {
  # todo Check return status.
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting Hardcover edition by ($type) ($id) from (ansi yellow)($hardcover_api_url)(ansi reset): ($error.debug)"
      log error $"GraphQL query:\n(ansi yellow)($graphql_query | to json)(ansi reset)\n"
      return null
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) searching for Hardcover editions with ($type) ($id) with GraphQL query ($graphql_query) at (ansi yellow)($hardcover_api_url)(ansi reset): ($response.body)"
    return null
  }
  $response.body | get --optional data.editions
  let cover_art_url = (
    http get --full --headers {"User-Agent": $user_agent} $"https://coverartarchive.org/release/($musicbrainz_release_id)"
    | get body.images.0.image
  )
  let cover_art_id = (
    $cover_art_url
    | str replace 'https://coverartarchive.org/release/' ''
    | path parse
    | update extension ""
    | path join
  )
  print ($cover_art_url | ansi link --text $cover_art_id)

}
