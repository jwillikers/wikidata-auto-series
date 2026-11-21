# Tests for the ISBN functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

def test_hyphenate_isbn_isbn13 [] {
  assert equal ("9781974742035" | hyphenate_isbn) "978-1-9747-4203-5"
}

def test_hyphenate_isbn_isbn10 [] {
  assert equal ("1974742032" | hyphenate_isbn) "1-9747-4203-2"
}

def test_hyphenate_isbn_isbn10_check_digit_x [] {
  assert equal ("080442957X" | hyphenate_isbn) "0-8044-2957-X"
}

def test_hyphenate_isbn_already_hyphenated [] {
  assert equal ("978-1-9747-4203-5" | hyphenate_isbn) "978-1-9747-4203-5"
}

def test_hyphenate_isbn_invalid [] {
  assert equal ("not-an-isbn" | hyphenate_isbn) null
}

def test_hyphenate_isbn [] {
  test_hyphenate_isbn_isbn13
  test_hyphenate_isbn_isbn10
  test_hyphenate_isbn_isbn10_check_digit_x
  test_hyphenate_isbn_already_hyphenated
  test_hyphenate_isbn_invalid
}

def test_into_isbn10_isbn13 [] {
  assert equal ("9781974742035" | into_isbn10) "1974742032"
}

def test_into_isbn10_hyphenated_isbn13 [] {
  assert equal ("978-1-9747-4203-5" | into_isbn10) "1974742032"
}

def test_into_isbn10_979_prefix [] {
  # ISBN-13s with the 979 prefix have no ISBN-10 equivalent.
  assert equal ("9791032000397" | into_isbn10) null
}

def test_into_isbn10_invalid [] {
  assert equal ("not-an-isbn" | into_isbn10) null
}

def test_into_isbn10 [] {
  test_into_isbn10_isbn13
  test_into_isbn10_hyphenated_isbn13
  test_into_isbn10_979_prefix
  test_into_isbn10_invalid
}

export def run_tests [] {
  test_hyphenate_isbn
  test_into_isbn10
}
