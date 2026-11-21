# Tests for the identifier functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

def test_merge_identifiers_both_empty [] {
  assert equal ({} | merge_identifiers {}) {}
}

def test_merge_identifiers_adds_missing [] {
  let item = {isbn_13: "9781974742035"}
  let other = {oclc_number: "1320851260"}
  let expected = {isbn_13: "9781974742035" oclc_number: "1320851260"}
  assert equal ($item | merge_identifiers $other) $expected
}

def test_merge_identifiers_fills_null [] {
  let item = {isbn_13: "9781974742035" oclc_number: null}
  let other = {oclc_number: "1320851260"}
  let expected = {isbn_13: "9781974742035" oclc_number: "1320851260"}
  assert equal ($item | merge_identifiers $other) $expected
}

def test_merge_identifiers_same_value [] {
  let item = {isbn_13: "9781974742035"}
  assert equal ($item | merge_identifiers {isbn_13: "9781974742035"}) $item
}

def test_merge_identifiers_conflict_keeps_original [] {
  let item = {isbn_13: "9781974742035"}
  assert equal ($item | merge_identifiers {isbn_13: "9781974742042"}) $item
}

def test_merge_identifiers_ignores_null_from_other [] {
  let item = {isbn_13: "9781974742035"}
  assert equal ($item | merge_identifiers {isbn_13: null}) $item
}

def test_merge_identifiers [] {
  test_merge_identifiers_both_empty
  test_merge_identifiers_adds_missing
  test_merge_identifiers_fills_null
  test_merge_identifiers_same_value
  test_merge_identifiers_conflict_keeps_original
  test_merge_identifiers_ignores_null_from_other
}

def test_empty_identifiers_empty_record [] {
  assert equal ({} | empty_identifiers) []
}

def test_empty_identifiers_none_empty [] {
  assert equal ({isbn_13: "9781974742035" oclc_number: "1320851260"} | empty_identifiers) []
}

def test_empty_identifiers_first_empty [] {
  assert equal ({oclc_number: null isbn_13: "9781974742035"} | empty_identifiers) [oclc_number]
}

def test_empty_identifiers_last_empty [] {
  assert equal ({isbn_13: "9781974742035" oclc_number: null} | empty_identifiers) [oclc_number]
}

def test_empty_identifiers_empty_string [] {
  assert equal ({isbn_13: "9781974742035" asin: ""} | empty_identifiers) [asin]
}

def test_empty_identifiers_all_empty [] {
  assert equal ({isbn_13: null oclc_number: null} | empty_identifiers) [isbn_13 oclc_number]
}

def test_empty_identifiers [] {
  test_empty_identifiers_empty_record
  test_empty_identifiers_none_empty
  test_empty_identifiers_first_empty
  test_empty_identifiers_last_empty
  test_empty_identifiers_empty_string
  test_empty_identifiers_all_empty
}

export def run_tests [] {
  test_merge_identifiers
  test_empty_identifiers
}
