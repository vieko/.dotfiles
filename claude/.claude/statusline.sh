#!/bin/bash
input=$(cat)

# Extract JSON data from context_window
MODEL=$(echo "$input" | jq -r '.model.display_name')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens')
OUTPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_output_tokens')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
EXCEEDS_200K=$(echo "$input" | jq -r '.exceeds_200k_tokens')

# Use all context_window data for calculations
TOTAL_TOKENS=$((INPUT_TOKENS + OUTPUT_TOKENS))
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

# Progress bar settings
BAR_WIDTH=40
FILLED=$((PERCENT_USED * BAR_WIDTH / 100))

# Autocompact buffer is fixed at 45k tokens - threshold is dynamic based on context size
AUTOCOMPACT_BUFFER=45000
THRESHOLD_TOKENS=$((CONTEXT_SIZE - AUTOCOMPACT_BUFFER))
THRESHOLD_POS=$((THRESHOLD_TOKENS * BAR_WIDTH / CONTEXT_SIZE))

# Build progress bar with threshold marker (no color on marker)
BAR=""
for ((i=0; i<BAR_WIDTH; i++)); do
    if [[ $i -eq $THRESHOLD_POS ]]; then
        # Threshold marker - no color
        if [[ $i -lt $FILLED ]]; then
            BAR+="▓"  # Filled + threshold
        else
            BAR+="│"  # Empty + threshold
        fi
    elif [[ $i -lt $FILLED ]]; then
        BAR+="█"
    else
        BAR+="░"
    fi
done

# Output: SUMMONING DEMONS ▲ Model [bar] XXK/XXXK (yellow counts if exceeds 200k)
if [[ "$EXCEEDS_200K" == "true" ]]; then
    printf "\033[1mSUMMONING DEMONS\033[22m ▲ %s %s \033[33m%s/%s\033[0m" "$MODEL" "$BAR" "$USED_DISPLAY" "$SIZE_DISPLAY"
else
    printf "\033[1mSUMMONING DEMONS\033[22m ▲ %s %s %s/%s" "$MODEL" "$BAR" "$USED_DISPLAY" "$SIZE_DISPLAY"
fi
