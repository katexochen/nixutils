#!/usr/bin/env bash

set -euo pipefail

readonly fakeHash="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="

function currentVendorHash() {
    export attr="$1"
    # shellcheck disable=SC2016
    expr='
let
    sys = builtins.currentSystem;
    flake = builtins.getFlake (toString ./.);
    packages = flake.packages.${sys};
    lib = flake.inputs.nixpkgs.lib;
    attrName = builtins.getEnv "attr";
    attr = packages.${attrName};
in
(if (attr.vendorHash != "") then attr.vendorHash else lib.fakeHash)
'
    nix eval \
        --raw \
        --impure \
        --expr "$expr"
}

function filePath() {
    export attr="$1"
    # shellcheck disable=SC2016
    expr='
let
    sys = builtins.currentSystem;
    flake = builtins.getFlake (toString ./.);
    packages = flake.packages.${sys};
    lib = flake.inputs.nixpkgs.lib;
    attrName = builtins.getEnv "attr";
    attrPath = (builtins.unsafeGetAttrPos  "src" packages.${attrName}).file;
in
(lib.strings.removePrefix "/" (lib.strings.removePrefix flake.outPath attrPath))
'
    nix eval \
        --raw \
        --impure \
        --expr "$expr"
}

function updatedVendorHash() {
    attr="$1"
    # shellcheck disable=SC2016
    expr='
{ attr }:
let
    sys = builtins.currentSystem;
    packages = (builtins.getFlake (toString ./.)).packages.${sys};
in
packages.${attr}.goModules.overrideAttrs (_: { outputHash = ""; outputHashAlgo = "sha256"; })
'
    (nix \
        --extra-experimental-features nix-command \
        build \
        --impure \
        --no-link \
        --argstr attr "$1" \
        --expr "$expr" \
        2>&1 \
    || true) \
    | grep "got:" \
    | awk '{print $2}'
}

attr="${1:-}"
if [[ -z "$attr" ]]; then
    echo "Usage: $0 <attr>" >&2
    exit 1
fi

if ! currentHash="$(currentVendorHash "$attr")"; then
    echo "Failed to get current vendorHash" >&2
    exit 1
fi

if ! updatedHash="$(updatedVendorHash "$attr")"; then
    echo "Failed to get updated vendorHash" >&2
    exit 1
fi

if [[ "$currentHash" == "$updatedHash" ]]; then
    echo "vendorHash of ${attr} is up to date" >&2
    exit 0
fi

echo "Updating buildGoModule vendorHash" >&2
echo "Specified: $currentHash" >&2
echo "Got:       $updatedHash" >&2

file="$(filePath "$attr")"

if [[ "$currentHash" == "$fakeHash" ]]; then
    sed -i 's|vendorHash = "";|vendorHash = "'"$updatedHash"'";|' "$file"
else
    sed -i "s|${currentHash}|${updatedHash}|" "$file"
fi
echo "Successfully updated vendorHash of ${attr}" >&2
