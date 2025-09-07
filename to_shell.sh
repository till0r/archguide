#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
  echo "Usage: $0 <source_file>"
  exit 1
fi

SOURCE_FILE=$1

[[ -f $SOURCE_FILE ]] || { echo "Source file '$SOURCE_FILE' not found."; exit 1; }

CODE_STR='```'
IN_CODE=0
header=$'#!/bin/bash\nset -euo pipefail\n'
concatenated=''
file_name="start"
file_block=-1

while IFS= read -r line; do
  if [[ ${line:0:3} == "$CODE_STR" ]]; then
    (( IN_CODE ^= 1 ))
    continue
  elif [[ ${line:0:3} == "## " ]]; then
    if [[ file_block -gt -1 ]]; then
      file_path="$(pwd)/${file_block}_${file_name}.sh"
      printf '%s' "$concatenated" > "$file_path"
      concatenated=""
      concatenated+="$header"
    fi

    ((file_block++))
    file_name=${line:3}
    file_name=${file_name// /_}
    # macOS bs
    # file_name=${file_name,,}
    file_name=$(printf '%s' "$file_name" | tr '[:upper:]' '[:lower:]')
  elif [[ -n $line ]]; then
    if (( IN_CODE == 1 )) || [[ ${line:0:1} == "#" ]]; then
      concatenated+="$line"
    else
      concatenated+="# $line"
    fi
  fi
  concatenated+=$'\n'
done < "$SOURCE_FILE"


