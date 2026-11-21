# Tests for the checksum functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

def with_test_file [contents: string, test: closure] {
  let file = mktemp --tmpdir
  $contents | save --force $file
  try {
    do $test $file
  } catch {|error|
    rm $file
    error make $error
  }
  rm $file
}

def test_hash_blake3_hello_world [] {
  with_test_file "hello world\n" {|file|
    assert equal ($file | hash_blake3) "dc5a4edb8240b018124052c330270696f96771a63b45250a5c17d3000e823355"
  }
}

def test_hash_blake3_empty_file [] {
  with_test_file "" {|file|
    assert equal ($file | hash_blake3) "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
  }
}

def test_hash_blake3_no_file [] {
  assert error {|| "" | hash_blake3 }
}

def test_hash_blake3_missing_file [] {
  assert error {|| "/nonexistent/wikidata-auto-series-test-file" | hash_blake3 }
}

def test_hash_blake3 [] {
  test_hash_blake3_hello_world
  test_hash_blake3_empty_file
  test_hash_blake3_no_file
  test_hash_blake3_missing_file
}

def test_hash_sha3_512_hello_world [] {
  with_test_file "hello world\n" {|file|
    assert equal ($file | hash_sha3_512) "4a936cbc1db296bd08d1c0bbf5a66a1897f35ee6d93047e0edff893dfbcba02f1e1570e85d1187ea26bea6d54199e0656f1b7c21b9cc2102b8ed2a12769f4531"
  }
}

def test_hash_sha3_512_empty_file [] {
  with_test_file "" {|file|
    assert equal ($file | hash_sha3_512) "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26"
  }
}

def test_hash_sha3_512_no_file [] {
  assert error {|| "" | hash_sha3_512 }
}

def test_hash_sha3_512_missing_file [] {
  assert error {|| "/nonexistent/wikidata-auto-series-test-file" | hash_sha3_512 }
}

def test_hash_sha3_512 [] {
  test_hash_sha3_512_hello_world
  test_hash_sha3_512_empty_file
  test_hash_sha3_512_no_file
  test_hash_sha3_512_missing_file
}

export def run_tests [] {
  test_hash_blake3
  test_hash_sha3_512
}
