# Tests for the retry functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

# Closures can't mutate variables outside of themselves, so count calls in a file.
def new_counter []: nothing -> path {
  let counter = mktemp --tmpdir
  "0" | save --force $counter
  $counter
}

def increment [counter: path]: nothing -> int {
  let count = (open $counter | into int) + 1
  $count | into string | save --force $counter
  $count
}

def count [counter: path]: nothing -> int {
  let count = open $counter | into int
  rm $counter
  $count
}

def test_retry_success_first_attempt [] {
  let counter = new_counter
  let result = retry {|| increment $counter; "ok" } {|result| false } 3 0sec false
  assert equal $result "ok"
  assert equal (count $counter) 1
}

def test_retry_succeeds_after_failures [] {
  let counter = new_counter
  let result = retry {|| increment $counter } {|result| $result < 3 } 5 0sec false
  assert equal $result 3
  assert equal (count $counter) 3
}

def test_retry_exhausts_attempts [] {
  let counter = new_counter
  let result = retry {|| increment $counter } {|result| true } 3 0sec false
  # The result of the final attempt is returned even when it should be retried.
  assert equal $result 3
  assert equal (count $counter) 3
}

def test_retry_one_attempt [] {
  let counter = new_counter
  retry {|| increment $counter } {|result| true } 1 0sec false
  assert equal (count $counter) 1
}

def test_retry_zero_attempts [] {
  let counter = new_counter
  retry {|| increment $counter } {|result| true } 0 0sec false
  assert equal (count $counter) 1
}

def test_retry_ignore_exceptions [] {
  let counter = new_counter
  let result = retry {||
    if (increment $counter) < 2 {
      error make {msg: "transient failure"}
    }
    "ok"
  } {|result| false } 3 0sec true
  assert equal $result "ok"
  assert equal (count $counter) 2
}

def test_retry_rethrows_exceptions [] {
  let counter = new_counter
  assert error {||
    retry {||
      increment $counter
      error make {msg: "failure"}
    } {|result| false } 3 0sec false
  }
  assert equal (count $counter) 1
}

def test_retry [] {
  test_retry_success_first_attempt
  test_retry_succeeds_after_failures
  test_retry_exhausts_attempts
  test_retry_one_attempt
  test_retry_zero_attempts
  test_retry_ignore_exceptions
  test_retry_rethrows_exceptions
}

def test_retry_http_retries_server_errors [] {
  let counter = new_counter
  let result = retry_http {||
    if (increment $counter) < 3 { {status: 503} } else { {status: 200} }
  } 5 0sec
  assert equal $result {status: 200}
  assert equal (count $counter) 3
}

def test_retry_http_does_not_retry_client_errors [] {
  let counter = new_counter
  let result = retry_http {|| increment $counter; {status: 404} } 5 0sec
  assert equal $result {status: 404}
  assert equal (count $counter) 1
}

def test_retry_http_custom_status_codes [] {
  let counter = new_counter
  let result = retry_http {||
    if (increment $counter) < 2 { {status: 404} } else { {status: 200} }
  } 5 0sec [404]
  assert equal $result {status: 200}
  assert equal (count $counter) 2
}

def test_retry_http [] {
  test_retry_http_retries_server_errors
  test_retry_http_does_not_retry_client_errors
  test_retry_http_custom_status_codes
}

export def run_tests [] {
  test_retry
  test_retry_http
}
