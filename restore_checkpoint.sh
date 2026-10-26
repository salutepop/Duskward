#!/usr/bin/env bash
# Restore Duskward to the pre-improvements checkpoint state
# Usage: ./restore_checkpoint.sh
set -euo pipefail

cd "$(dirname -- "$0")"

CHECKPOINT="checkpoint-pre-improvements"

if ! git rev-parse --verify "$CHECKPOINT" >/dev/null 2>&1; then
  echo "ERROR: checkpoint tag '$CHECKPOINT' not found" >&2
  exit 1
fi

echo "Restoring to checkpoint: $CHECKPOINT"
git reset --hard "$CHECKPOINT"
echo "Restored. Current state:"
git log --oneline -3
echo ""
echo "Working tree:"
git status --short
