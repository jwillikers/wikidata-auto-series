# Tests for the Open Library functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

const test_data = path self ../test-data

def test_open_library_parse_work_identifiers_work [] {
  let expected = {
    librarything_work_id: "26917988"
    goodreads_work_id: "86829811"
    wikidata_work_id: "Q139605035"
  }
  assert equal (open ($test_data | path join "open-library-work-frieren-volume-2.json") | open_library_parse_work_identifiers) $expected
}

def test_open_library_parse_work_identifiers_missing_identifiers [] {
  assert equal ({key: "/works/OL42575511W"} | open_library_parse_work_identifiers) {}
}

def test_open_library_parse_work_identifiers_multiple_values [] {
  let body = {identifiers: {goodreads: ["86829811" "12345"]}}
  assert equal ($body | open_library_parse_work_identifiers) {goodreads_work_id: "86829811"}
}

def test_open_library_parse_work_identifiers_null [] {
  assert equal (null | open_library_parse_work_identifiers) null
}

def test_open_library_parse_work_identifiers [] {
  test_open_library_parse_work_identifiers_work
  test_open_library_parse_work_identifiers_missing_identifiers
  test_open_library_parse_work_identifiers_multiple_values
  test_open_library_parse_work_identifiers_null
}

def test_open_library_parse_edition_identifiers_edition [] {
  let expected = {
    asin: "B09J6NPVRJ"
    goodreads_version_id: "59348522"
    google_books_id: "FO9HEAAAQBAJ"
    bookbrainz_edition_id: "ef7fad75-fcd9-492b-b5d2-9a2d6eedb4d3"
    overdrive_uuid: "F4FB9C00-6673-49F5-8BFF-27813A9DE19A"
    wikidata_item_id: "Q139605488"
    isbn_10: "1974731219"
    isbn_13: "9781974731213"
    oclc_number: "1292740943"
    publication_date: "2022-01-11"
  }
  assert equal (open ($test_data | path join "open-library-edition-frieren-volume-2.json") | open_library_parse_edition_identifiers) $expected
}

def test_open_library_parse_edition_identifiers_no_identifiers_field [] {
  # Editions without an identifiers field still have their ISBNs parsed.
  let body = {isbn_13: ["978-1-9747-3121-3"] publish_date: "2022-01-11"}
  assert equal ($body | open_library_parse_edition_identifiers) {isbn_13: "9781974731213" publication_date: "2022-01-11"}
}

def test_open_library_parse_edition_identifiers_copyright_date [] {
  let body = {copyright_date: "2020"}
  assert equal ($body | open_library_parse_edition_identifiers) {copyright_year: "2020"}
}

def test_open_library_parse_edition_identifiers_unknown_identifier [] {
  let body = {identifiers: {librarything: ["26917988"] amazon: ["B09J6NPVRJ"]}}
  assert equal ($body | open_library_parse_edition_identifiers) {asin: "B09J6NPVRJ"}
}

def test_open_library_parse_edition_identifiers_multiple_values [] {
  let body = {isbn_10: ["1974731219" "1974731227"] oclc_numbers: ["1292740943" "1"]}
  assert equal ($body | open_library_parse_edition_identifiers) {isbn_10: "1974731219" oclc_number: "1292740943"}
}

def test_open_library_parse_edition_identifiers_empty [] {
  assert equal ({key: "/books/OL60674406M"} | open_library_parse_edition_identifiers) {}
}

def test_open_library_parse_edition_identifiers_null [] {
  assert equal (null | open_library_parse_edition_identifiers) null
}

def test_open_library_parse_edition_identifiers [] {
  test_open_library_parse_edition_identifiers_edition
  test_open_library_parse_edition_identifiers_no_identifiers_field
  test_open_library_parse_edition_identifiers_copyright_date
  test_open_library_parse_edition_identifiers_unknown_identifier
  test_open_library_parse_edition_identifiers_multiple_values
  test_open_library_parse_edition_identifiers_empty
  test_open_library_parse_edition_identifiers_null
}

export def run_tests [] {
  test_open_library_parse_work_identifiers
  test_open_library_parse_edition_identifiers
}
