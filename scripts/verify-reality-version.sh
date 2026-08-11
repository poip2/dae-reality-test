#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: $0 REALITY_GO X Y Z" >&2
  exit 2
fi

file=$1
x=$2
y=$3
z=$4

[ -f "$file" ] || {
  echo "missing REALITY source: $file" >&2
  exit 1
}

count=$(grep -Ec '^[[:space:]]*Reality_Version_[xyz][[:space:]]+byte[[:space:]]*=' "$file" || true)
[ "$count" -eq 3 ] || {
  echo "expected exactly three REALITY version declarations; found $count" >&2
  exit 1
}

for expected in \
  "Reality_Version_x byte = $x" \
  "Reality_Version_y byte = $y" \
  "Reality_Version_z byte = $z"
do
  grep -Eq "^[[:space:]]*${expected}$" "$file" || {
    echo "missing expected declaration: $expected" >&2
    exit 1
  }
done

echo "verified REALITY client version: $x.$y.$z"
