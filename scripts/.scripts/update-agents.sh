#!/bin/bash

echo "Updating AI coding agents..."

echo "Updating Amp..."
npm install -g @sourcegraph/amp@latest

echo "Updating Codex..."
npm install -g @openai/codex@latest

echo "Updating Claude..."
npm install -g @anthropic-ai/claude-code@latest

echo "Updating OpenCode..."
npm install -g opencode-ai@latest

echo "All agents updated successfully!"
