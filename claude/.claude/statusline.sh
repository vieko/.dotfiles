#!/bin/bash
input=$(cat)

# Extract JSON data
MODEL=$(echo "$input" | jq -r '.model.display_name')
INPUT_TOKENS=$(echo "$input" | jq -r '.context_window.total_input_tokens')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')

# Use input tokens only - output tokens don't consume context for next call
PERCENT_USED=$((INPUT_TOKENS * 100 / CONTEXT_SIZE))

# Format tokens (K for thousands)
if [[ $INPUT_TOKENS -ge 1000 ]]; then
    USED_DISPLAY="$((INPUT_TOKENS / 1000))K"
else
    USED_DISPLAY="$INPUT_TOKENS"
fi

if [[ $CONTEXT_SIZE -ge 1000 ]]; then
    SIZE_DISPLAY="$((CONTEXT_SIZE / 1000))K"
else
    SIZE_DISPLAY="$CONTEXT_SIZE"
fi

# Progress bar settings (20 chars: ~2.5% threshold tolerance on 200k, ~0.5% on 1M)
BAR_WIDTH=20
FILLED=$((PERCENT_USED * BAR_WIDTH / 100))

# Autocompact buffer is fixed at 45k tokens - threshold is dynamic based on context size
AUTOCOMPACT_BUFFER=45000
THRESHOLD_TOKENS=$((CONTEXT_SIZE - AUTOCOMPACT_BUFFER))
THRESHOLD_POS=$((THRESHOLD_TOKENS * BAR_WIDTH / CONTEXT_SIZE))

# Build progress bar with threshold marker
BAR=""
for ((i=0; i<BAR_WIDTH; i++)); do
    if [[ $i -eq $THRESHOLD_POS ]]; then
        # Threshold marker - show state AND marker
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

# Output: SUMMONING DEMONS ▲ Model [bar] XXK/XXXK
printf "\033[1mSUMMONING DEMONS\033[22m ▲ %s %s %s/%s" "$MODEL" "$BAR" "$USED_DISPLAY" "$SIZE_DISPLAY"
