#!/bin/bash
input=$(cat)

# Extract JSON data
MODEL=$(echo "$input" | jq -r '.model.display_name')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')

# Calculate context usage
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))
PERCENT_USED=$((TOTAL_TOKENS * 100 / CONTEXT_SIZE))

# Progress bar settings
BAR_WIDTH=20
FILLED=$((PERCENT_USED * BAR_WIDTH / 100))
EMPTY=$((BAR_WIDTH - FILLED))

# Build progress bar
FILLED_BAR=$(printf '%*s' "$FILLED" '' | tr ' ' '█')
EMPTY_BAR=$(printf '%*s' "$EMPTY" '' | tr ' ' '░')

# Output: SUMMONING DEMONS | Model | ⛶ [bar] XX%
printf "SUMMONING DEMONS | %s | ⛶ %s%s %d%%" "$MODEL" "$FILLED_BAR" "$EMPTY_BAR" "$PERCENT_USED"
