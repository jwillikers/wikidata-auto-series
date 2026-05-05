#!/usr/bin/env nu

use std log
use wikidata-auto-series-lib *

# Get the cover art image id for a given MusicBrainz release ID in the format required for Wikidata property P14071.
def main [
  musicbrainz_release_id: string
  --retries: int = 3 # The number of retries to perform when a request fails
  --retry-delay: duration = 5sec # The interval between successive attempts when there is a failure
] {
  let request = {
    http get --full --headers {"User-Agent": $user_agent} $"https://coverartarchive.org/release/($musicbrainz_release_id)"
  }
  let response = (
    try {
      retry_http $request $retries $retry_delay
    } catch {|error|
      log error $"Error getting the cover art archive id for MusicBrainz release ID (ansi yellow)($musicbrainz_release_id)(ansi reset): ($error.debug)"
      exit 1
    }
  )
  if ($response.status != 200) {
    log error $"HTTP error (ansi red)($response.status)(ansi reset) getting the Cover Art Archive ID for the MusicBrainz release ID (ansi yellow)($musicbrainz_release_id)(ansi reset): ($response.body)"
    exit 1
  }
  let cover_art_url = $response.body.images.0.image
  let cover_art_id = (
    $cover_art_url
    | str replace 'https://coverartarchive.org/release/' ''
    | path parse
    | update extension ""
    | path join
  )
  print ($cover_art_url | ansi link --text $cover_art_id)

}
