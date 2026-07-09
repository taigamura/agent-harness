#!/bin/bash
# Bootstrap a fresh WSL Ubuntu with git, python3, pipx, and aider-chat.
# Idempotent — safe to run multiple times.
set -e

echo "=== WSL setup: aider + Ollama stack ==="
echo ""
echo "This script is ONLY needed for the aider+Ollama stack."
echo "If you are using Claude Code only, skip this step."
echo ""

# ── git ──────────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
  echo "Installing git..."
  sudo apt-get update -q
  sudo apt-get install -y git
else
  echo "git already installed ($(git --version))"
fi

# ── python3 ──────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
  echo "Installing python3..."
  sudo apt-get update -q
  sudo apt-get install -y python3 python3-pip
else
  echo "python3 already installed ($(python3 --version))"
fi

# ── pipx ─────────────────────────────────────────────────────────────────────
if ! command -v pipx &>/dev/null; then
  echo "Installing pipx..."
  sudo apt-get update -q
  sudo apt-get install -y pipx
  pipx ensurepath
else
  echo "pipx already installed ($(pipx --version))"
fi

# ── aider-chat ────────────────────────────────────────────────────────────────
if ! command -v aider &>/dev/null; then
  echo "Installing aider-chat via pipx..."
  pipx install aider-chat
else
  echo "aider already installed ($(aider --version 2>/dev/null || echo 'unknown version'))"
fi

echo ""
echo "WSL setup complete."
echo ""
echo "Next: run ./setup-machine.sh to install the harness."
