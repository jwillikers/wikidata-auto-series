# Tests for the file format functions in wikidata-auto-series-lib

use std assert

use ../wikidata-auto-series-lib *

# Create a ZIP archive with the given files in a temporary directory and pass its path to the test.
def with_test_archive [archive_name: string, files: list<string>, test: closure] {
  let directory = mktemp --directory --tmpdir
  for file in $files {
    mkdir ($directory | path join $file | path dirname)
    touch ($directory | path join $file)
  }
  let archive = $directory | path join $archive_name
  do {
    cd $directory
    ^zip --quiet --recurse-paths $archive_name ...$files
  }
  try {
    do $test $archive
  } catch {|error|
    rm --recursive $directory
    error make $error
  }
  rm --recursive $directory
}

def test_list_files_in_archive [] {
  with_test_archive "test.cbz" ["002.png" "001.jpg" "ComicInfo.xml" "extras/cover.jpg"] {|archive|
    assert equal ($archive | list_files_in_archive) ["001.jpg" "002.png" "ComicInfo.xml" "extras/cover.jpg"]
  }
}

def test_list_files_in_archive_file_name_with_spaces [] {
  with_test_archive "test.zip" ["Chapter 01 - The Beginning.mp3"] {|archive|
    assert equal ($archive | list_files_in_archive) ["Chapter 01 - The Beginning.mp3"]
  }
}

def test_list_file_extensions_for_file_epub [] {
  assert equal ("/books/Frieren, Vol. 1.epub" | list_file_extensions_for_file) [epub]
}

def test_list_file_extensions_for_file_uppercase [] {
  assert equal ("/books/Frieren, Vol. 1.PDF" | list_file_extensions_for_file) [pdf]
}

def test_list_file_extensions_for_file_no_file [] {
  assert error {|| "" | list_file_extensions_for_file }
}

def test_list_file_extensions_for_file_cbz [] {
  with_test_archive "test.cbz" ["001.JPEG" "002.jpg" "003.png" "ComicInfo.xml" "README"] {|archive|
    assert equal ($archive | list_file_extensions_for_file) [cbz jpg png xml]
  }
}

def test_list_file_extensions_for_file_zip [] {
  with_test_archive "test.zip" ["01.mp3" "02.mp3" "cover.jpg"] {|archive|
    assert equal ($archive | list_file_extensions_for_file) [zip mp3 jpg]
  }
}

def test_list_file_extensions_for_file [] {
  test_list_files_in_archive
  test_list_files_in_archive_file_name_with_spaces
  test_list_file_extensions_for_file_epub
  test_list_file_extensions_for_file_uppercase
  test_list_file_extensions_for_file_no_file
  test_list_file_extensions_for_file_cbz
  test_list_file_extensions_for_file_zip
}

def test_map_file_extensions_to_wikidata_file_formats_empty [] {
  assert equal ([] | map_file_extensions_to_wikidata_file_formats) []
}

def test_map_file_extensions_to_wikidata_file_formats_multiple [] {
  assert equal ([cbz jpg png] | map_file_extensions_to_wikidata_file_formats) [Q109335570 Q26329975 Q178051]
}

def test_map_file_extensions_to_wikidata_file_formats_epub_default [] {
  assert equal ([epub] | map_file_extensions_to_wikidata_file_formats) [Q27196933]
}

def test_map_file_extensions_to_wikidata_file_formats_epub2 [] {
  assert equal ([epub] | map_file_extensions_to_wikidata_file_formats --epub-version 2) [Q56230180]
}

def test_map_file_extensions_to_wikidata_file_formats_unknown [] {
  assert error {|| [docx] | map_file_extensions_to_wikidata_file_formats }
}

def test_map_file_extensions_to_wikidata_file_formats [] {
  test_map_file_extensions_to_wikidata_file_formats_empty
  test_map_file_extensions_to_wikidata_file_formats_multiple
  test_map_file_extensions_to_wikidata_file_formats_epub_default
  test_map_file_extensions_to_wikidata_file_formats_epub2
  test_map_file_extensions_to_wikidata_file_formats_unknown
}

export def run_tests [] {
  test_list_file_extensions_for_file
  test_map_file_extensions_to_wikidata_file_formats
}
