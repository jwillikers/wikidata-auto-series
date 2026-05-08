{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  pythonAtLeast,

  # build-system
  setuptools,

  # tests
  pytestCheckHook,
  pytest-cov-stub,
}:

buildPythonPackage rec {
  pname = "isbnlib";
  version = "3.11.14";
  pyproject = true;

  # Several tests fail and suggest that the package is incompatible with python >= 3.14
  disabled = pythonAtLeast "3.14";

  src = fetchFromGitHub {
    owner = "hans-fritz-pommes";
    repo = "isbnlib";
    tag = "v${version}";
    hash = "sha256-8z0TnPokKRL9pqCyMIbF0uw8TItEpJmUcu21a0cw5oA=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail 'name = "isbnlib2"' 'name = "isbnlib"'
  '';

  build-system = [ setuptools ];

  dependencies = [
    setuptools # needed for 'pkg_resources'
  ];

  nativeCheckInputs = [
    pytestCheckHook
    pytest-cov-stub
  ];

  enabledTestPaths = [ "isbnlib/test/" ];

  disabledTests = [
    # Require a network connection
    "test_cache"
    "test_editions_any"
    "test_editions_merge"
    "test_editions_thingl"
    "test_editions_wiki"
    "test_isbn_from_words"
    "test_desc"
    "test_cover"
  ];

  disabledTestPaths = [
    "isbnlib/test/test_cache_decorator.py"
    "isbnlib/test/test_goom.py"
    "isbnlib/test/test_metadata.py"
    "isbnlib/test/test_openl.py"
    "isbnlib/test/test_rename.py"
    "isbnlib/test/test_webservice.py"
    "isbnlib/test/test_words.py"
  ];

  pythonImportsCheck = [
    "isbnlib"
    "isbnlib.config"
    "isbnlib.dev"
    "isbnlib.dev.helpers"
    "isbnlib.registry"
  ];

  meta = {
    description = "Extract, clean, transform, hyphenate and metadata for ISBNs";
    homepage = "https://github.com/hans-fritz-pommes/isbnlib";
    changelog = "https://github.com/hans-fritz-pommes/isbnlib/blob/${src.tag}/CHANGES.txt";
    license = lib.licenses.lgpl3Plus;
  };
}
