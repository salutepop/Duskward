#!/usr/bin/env bash
# Run developer regression tests without touching a player's DUSKWARD save.
set -u
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT_BIN:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
  printf 'Godot executable not found. Set GODOT_BIN to Godot 4.6.3 standard.\n' >&2
  exit 2
fi
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/duskward-tests.XXXXXX")" || exit 2
export HOME="$TEST_ROOT/home"
export XDG_DATA_HOME="$HOME/data"
export XDG_CONFIG_HOME="$HOME/config"
export XDG_CACHE_HOME="$HOME/cache"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
printf 'Isolated test data and logs: %s\n' "$TEST_ROOT"
"$GODOT" --version > "$TEST_ROOT/engine-version.txt" 2>&1
if ! grep -q '^4\.6\.3\.' "$TEST_ROOT/engine-version.txt"; then
  printf 'Warning: this project is validated with Godot 4.6.3; detected: '
  cat "$TEST_ROOT/engine-version.txt"
fi
# A fresh source archive has no .godot import cache. Import bundled assets first.
if ! "$GODOT" --headless --path "$ROOT" --editor --import --quit > "$TEST_ROOT/import.log" 2>&1; then
  cat "$TEST_ROOT/import.log"
  exit 1
fi
if grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:)' "$TEST_ROOT/import.log"; then
  cat "$TEST_ROOT/import.log"
  exit 1
fi
result=0
for suite in hard_profile_catalog fast_profile_support hunt_opportunity_lifecycle hunt_opt_in spawn_schedule campaign_roles growth_progression defender_boss_geometry model_smoke model_regression rng_streams checkpoint_validation checkpoint_resources presentation_clock_controls presentation_layout presentation_results presentation_redesign presentation_support presentation_occlusion qa_hunt_controller; do
  printf '\n== %s ==\n' "$suite"
  if "$GODOT" --headless --path "$ROOT" --script "res://tests/$suite.gd" > "$TEST_ROOT/$suite.log" 2>&1; then
    status=0
  else
    status=$?
  fi
  cat "$TEST_ROOT/$suite.log"
  # Godot may log a script error and still exit 0 after a test tree calls quit().
  if [ "$status" -ne 0 ] || grep -Eq '(^|[[:space:]])(SCRIPT ERROR:|ERROR:|FAIL:)' "$TEST_ROOT/$suite.log"; then
    printf 'FAILED: %s (exit %s)\n' "$suite" "$status" >&2
    result=1
  fi
done
printf '\nDeveloper tests finished. Logs retained at %s\n' "$TEST_ROOT"
printf 'Controlled tests do not prove physical touch feel, Android FPS or full-match balance.\n'
exit "$result"
