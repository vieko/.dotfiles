#!/bin/bash
input=$(cat)

MODEL=$(echo "$input" | jq -r '.model.display_name')

printf "\033[1mSUMMONING DEMONS\033[22m ▲ %s" "$MODEL"
