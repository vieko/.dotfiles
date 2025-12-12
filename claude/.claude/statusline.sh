#!/bin/bash
input=$(cat)

# Extract JSON data
MODEL=$(echo "$input" | jq -r '.model.display_name')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')

# Calculate usage from JSON data only
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))
TOKENS_REMAINING=$((CONTEXT_SIZE - TOTAL_TOKENS))
PERCENT_USED=$((TOTAL_TOKENS * 100 / CONTEXT_SIZE))

# Format tokens (K for thousands)
if [[ $TOTAL_TOKENS -ge 1000 ]]; then
    USED_DISPLAY="$((TOTAL_TOKENS / 1000))K"
else
    USED_DISPLAY="$TOTAL_TOKENS"
fi

if [[ $CONTEXT_SIZE -ge 1000 ]]; then
    SIZE_DISPLAY="$((CONTEXT_SIZE / 1000))K"
else
    SIZE_DISPLAY="$CONTEXT_SIZE"
fi

# Progress bar settings (shows usage filling up)
BAR_WIDTH=20
FILLED=$((PERCENT_USED * BAR_WIDTH / 100))

# Autocompact threshold at 77.5% (155k/200k)
THRESHOLD_POS=$((BAR_WIDTH * 775 / 1000))

# Build progress bar with threshold marker
BAR=""
for ((i=0; i<BAR_WIDTH; i++)); do
    if [[ $i -eq $THRESHOLD_POS ]]; then
        BAR+="│"
    elif [[ $i -lt $FILLED ]]; then
        BAR+="█"
    else
        BAR+="░"
    fi
done

# Output: SUMMONING DEMONS ▲ Model [bar] XXK/XXXK
printf "\033[1mSUMMONING DEMONS\033[22m ▲ %s %s %s/%s" "$MODEL" "$BAR" "$USED_DISPLAY" "$SIZE_DISPLAY"
