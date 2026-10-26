#!/usr/bin/env bash
# Builds Terraform provider network mirror metadata for every release of this
# repo, served as registry.terraform.io/cyrilgdn/postgresql so consumers keep
# the upstream source address. Archives stay on GitHub releases; the metadata
# points at them with absolute URLs.
# https://developer.hashicorp.com/terraform/internals/provider-network-mirror-protocol
set -euo pipefail

out="$1"
repo="${GITHUB_REPOSITORY:?}"
dir="$out/registry.terraform.io/cyrilgdn/postgresql"
mkdir -p "$dir"

versions='{}'
for tag in $(gh release list -R "$repo" --limit 100 --json tagName,isDraft -q '.[] | select(.isDraft | not) | .tagName'); do
  v="${tag#v}"
  base="https://github.com/$repo/releases/download/$tag"
  # SHA256SUMS lines: "<sha256>  terraform-provider-postgresql_<v>_<os>_<arch>.zip"
  gh release download "$tag" -R "$repo" -p '*_SHA256SUMS' -O - |
    awk -v base="$base" '/\.zip$/ { n = split($2, a, "_"); arch = a[n]; sub(/\.zip$/, "", arch); printf "%s_%s\t%s/%s\t%s\n", a[n-1], arch, base, $2, $1 }' |
    jq -Rn '{archives: ([inputs | split("\t") | {(.[0]): {url: .[1], hashes: ["zh:" + .[2]]}}] | add)}' > "$dir/$v.json"
  versions=$(jq --arg v "$v" '.versions[$v] = {}' <<<"$versions")
done
echo "$versions" > "$dir/index.json"
