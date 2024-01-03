{ writeShellApplication
, gawk
, gnugrep
, gnused
, nix
}:
writeShellApplication {
  name = "update-vendor-hash";
  runtimeInputs = [
    gawk
    gnugrep
    gnused
    nix
  ];
  text = builtins.readFile ./update-vendor-hash.sh;
}
