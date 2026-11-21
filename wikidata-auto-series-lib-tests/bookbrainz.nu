# Tests for the BookBrainz functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

const test_data = path self ../test-data

def test_bookbrainz_parse_identifiers_edition [] {
  let expected = {
    oclc_number: "1292740943"
    goodreads_version_id: "59348522"
    wikidata_item_id: "Q139605488"
    isbn_13: "9781974731213"
    open_library_id: "OL60674406M"
    asin: "B09J6NPVRJ"
    isbn_10: "1974731219"
  }
  assert equal (open ($test_data | path join "bookbrainz-edition-identifiers-frieren-volume-2.json") | bookbrainz_parse_identifiers) $expected
}

def test_bookbrainz_parse_identifiers_work [] {
  let expected = {
    wikidata_work_id: "Q139605035"
    librarything_work_id: "26917988"
    open_library_id: "OL42575511W"
  }
  assert equal (open ($test_data | path join "bookbrainz-work-identifiers-sample.json") | bookbrainz_parse_identifiers) $expected
}

def test_bookbrainz_parse_identifiers_no_identifiers [] {
  assert equal (open ($test_data | path join "bookbrainz-work-identifiers-frieren-chapter-14.json") | bookbrainz_parse_identifiers) {}
}

def test_bookbrainz_parse_identifiers_missing_identifiers [] {
  assert equal ({bbid: "ef7fad75-fcd9-492b-b5d2-9a2d6eedb4d3"} | bookbrainz_parse_identifiers) {}
}

def test_bookbrainz_parse_identifiers_null [] {
  assert equal (null | bookbrainz_parse_identifiers) null
}

def test_bookbrainz_parse_identifiers_unknown_type [] {
  let body = {
    identifiers: [
      {type: "Some New Identifier" value: "12345"}
      {type: "ISBN-13" value: "978-1-9747-3121-3"}
    ]
  }
  assert equal ($body | bookbrainz_parse_identifiers) {isbn_13: "9781974731213"}
}

def test_bookbrainz_parse_identifiers_duplicate [] {
  let body = {
    identifiers: [
      {type: "Amazon ASIN" value: "B09J6NPVRJ"}
      {type: "Amazon ASIN" value: "1974731219"}
    ]
  }
  assert equal ($body | bookbrainz_parse_identifiers) {asin: "B09J6NPVRJ"}
}

def test_bookbrainz_parse_identifiers [] {
  test_bookbrainz_parse_identifiers_edition
  test_bookbrainz_parse_identifiers_work
  test_bookbrainz_parse_identifiers_no_identifiers
  test_bookbrainz_parse_identifiers_missing_identifiers
  test_bookbrainz_parse_identifiers_null
  test_bookbrainz_parse_identifiers_unknown_type
  test_bookbrainz_parse_identifiers_duplicate
}

def test_bookbrainz_parse_edition_publication_date_edition [] {
  assert equal (open ($test_data | path join "bookbrainz-edition-frieren-volume-2.json") | bookbrainz_parse_edition_publication_date) "2022-01-11"
}

def test_bookbrainz_parse_edition_publication_date_missing [] {
  assert equal ({bbid: "ef7fad75-fcd9-492b-b5d2-9a2d6eedb4d3"} | bookbrainz_parse_edition_publication_date) null
}

def test_bookbrainz_parse_edition_publication_date_null_date [] {
  assert equal ({releaseEventDate: null} | bookbrainz_parse_edition_publication_date) null
}

def test_bookbrainz_parse_edition_publication_date_null [] {
  assert equal (null | bookbrainz_parse_edition_publication_date) null
}

def test_bookbrainz_parse_edition_publication_date [] {
  test_bookbrainz_parse_edition_publication_date_edition
  test_bookbrainz_parse_edition_publication_date_missing
  test_bookbrainz_parse_edition_publication_date_null_date
  test_bookbrainz_parse_edition_publication_date_null
}

export def run_tests [] {
  test_bookbrainz_parse_identifiers
  test_bookbrainz_parse_edition_publication_date
}
