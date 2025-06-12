#!/bin/bash

echo "Updating AI coding agents..."

echo "Updating Amp..."
npm install -g @sourcegraph/amp@latest

echo "Updating Codex..."
npm install -g @openai/codex@latest

echo "Updating Claude..."
npm install -g @anthropic-ai/claude-code@latest

echo "Updating OpenCode..."
curl -fsSL https://raw.githubusercontent.com/opencode-ai/opencode/refs/heads/main/install | bash

echo "All agents updated successfully!"
