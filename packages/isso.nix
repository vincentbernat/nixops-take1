{ fetchFromGitHub, python3Packages }:

# Custom derivation for Isso using a personal fork. It would be possible to
# use the one from nixpkgs with `python3Packages.toPythonModule pkgs.isso`.
# Also, we don't build the JS part as it is not served from here.
python3Packages.buildPythonPackage rec {
  pname = "isso";
  version = "custom";
  format = "setuptools";

  src = fetchFromGitHub {
    owner = "vincentbernat";
    repo = pname;
    rev = "vbe/master";
    hash = "sha256-tLyi8NYr4WB1Hcf3IRJ1vb9JW/NKNcxtN9Spnfw00mc=";
  };

  propagatedBuildInputs = with python3Packages; [
    itsdangerous
    jinja2
    misaka
    mistune
    html5lib
    werkzeug
    bleach
  ];
  nativeBuildInputs = with python3Packages; [
    cffi
  ];
}
