#!/usr/bin/env bash
set -euo pipefail

if (( $# != 2 )); then
  echo "Usage: $0 <source_file> <target_file>"
  exit 1
fi

SOURCE_FILE=$1
TARGET_FILE=$2

[[ -f $SOURCE_FILE ]] || { echo "Source file '$SOURCE_FILE' not found."; exit 1; }

CODE_STR='```'
IN_CODE=0
concatenated=''

while IFS= read -r line; do
  if [[ ${line:0:3} == "$CODE_STR" ]]; then
    (( IN_CODE ^= 1 ))
    continue
  elif [[ -n $line ]]; then
    if (( IN_CODE == 1 )) || [[ ${line:0:1} == "#" ]]; then
      concatenated+="$line"
    else
      concatenated+="# $line"
    fi
  fi
  concatenated+=$'\n'
done < "$SOURCE_FILE"

printf '%s' "$concatenated" > "$TARGET_FILE"
echo "Script written to $TARGET_FILE"

