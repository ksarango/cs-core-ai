#!/usr/bin/env sh
# core-ai uninstall.sh — removes all (or specific) installed core-ai tools
# Usage:
#   sh uninstall.sh              # remove all installed tools
#   sh uninstall.sh --tool <name> # remove a specific tool only
#   sh uninstall.sh --yes        # skip confirmation prompt
#
# Override repo URL: CORE_AI_REPO=https://your.mirror/path sh uninstall.sh
set -e

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
REPO_BASE="${CORE_AI_REPO:-https://raw.github.com/ksarango/cs-core-ai/main}"
REPO_BASE="${REPO_BASE%/}"
case "$REPO_BASE" in
  https://*) : ;;
  *) echo "ERROR: CORE_AI_REPO must use https:// (got: $REPO_BASE)" >&2; exit 1 ;;
esac
TARGET="$HOME/.claude"
CLAUDE_MD="$TARGET/CLAUDE.md"
VERSIONS_FILE="$TARGET/.core-ai-versions"
TOOLS_JSON=$(mktemp /tmp/core-ai-tools-XXXXXX.json)
trap 'rm -f "$TOOLS_JSON"' EXIT

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
YES=""
TOOL_FLAG=""
prev=""

for arg in "$@"; do
  case "$arg" in
    --yes|-y) YES=1 ;;
    --tool)   : ;;
    *)
      if [ "$prev" = "--tool" ]; then
        TOOL_FLAG="$arg"
      fi
      ;;
  esac
  prev="$arg"
done

if [ "$prev" = "--tool" ] && [ -z "$TOOL_FLAG" ]; then
  echo "ERROR: --tool requires an argument (e.g. --tool verify-testing-jest)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# get_file_from_manifest <tool_name>
# Returns the file path from the manifest, or empty string if not found.
get_file_from_manifest() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"file"' \
    | head -1 \
    | sed 's/.*"file": *"//;s/".*//'
}

# get_deps_from_manifest <tool_name>
# Returns space-separated dep paths declared for a tool.
get_deps_from_manifest() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"deps"' \
    | head -1 \
    | sed 's/.*"deps": *"//;s/".*//'
}

# list_all_tool_names
# Prints all tool names from the manifest, one per line.
list_all_tool_names() {
  grep '"name"' "$TOOLS_JSON" | sed 's/.*"name": *"//;s/".*//'
}

# resolve_file <tool_name>
# Returns the absolute file path for a tool — manifest first, then conventional fallback.
resolve_file() {
  _tool="$1"
  _f=""
  if [ -s "$TOOLS_JSON" ]; then
    _f=$(get_file_from_manifest "$_tool")
    [ -n "$_f" ] && _f="$HOME/$_f"
  fi
  # Fallback: conventional location used by the installer
  if [ -z "$_f" ]; then
    _f="$TARGET/commands/$_tool.md"
  fi
  printf '%s' "$_f"
}

# strip_claude_md_block
# Removes the <!-- core-ai:start --> ... <!-- core-ai:end --> block from $CLAUDE_MD.
strip_claude_md_block() {
  if [ ! -f "$CLAUDE_MD" ]; then
    return
  fi
  if ! grep -q '<!-- *core-ai:start *-->' "$CLAUDE_MD"; then
    return
  fi
  if ! awk '/<!-- *core-ai:start *-->/,/<!-- *core-ai:end *-->/{next}1' \
      "$CLAUDE_MD" > "$CLAUDE_MD.tmp"; then
    rm -f "$CLAUDE_MD.tmp"
    echo "WARNING: failed to strip core-ai block from $CLAUDE_MD" >&2
    return
  fi
  mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
  echo "  updated: $CLAUDE_MD (core-ai block removed)"
}

# update_claude_md_block
# Rewrites the core-ai block in $CLAUDE_MD with the remaining tools.
# If no tools remain, removes the block entirely.
update_claude_md_block() {
  _remaining="$1"
  if [ -z "$_remaining" ]; then
    strip_claude_md_block
    return
  fi

  if [ ! -f "$CLAUDE_MD" ] || ! grep -q '<!-- *core-ai:start *-->' "$CLAUDE_MD"; then
    return
  fi

  _block="<!-- core-ai:start -->
## core-ai tools
<!-- managed by core-ai, do not edit manually -->"
  for _t in $_remaining; do
    _block="$_block
Installed: /$_t"
  done
  _block="$_block
<!-- core-ai:end -->"

  if ! awk '/<!-- *core-ai:start *-->/,/<!-- *core-ai:end *-->/{next}1' \
      "$CLAUDE_MD" > "$CLAUDE_MD.tmp"; then
    rm -f "$CLAUDE_MD.tmp"
    echo "WARNING: failed to update core-ai block in $CLAUDE_MD" >&2
    return
  fi
  printf '%s\n' "$_block" >> "$CLAUDE_MD.tmp"
  mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
  echo "  updated: $CLAUDE_MD (core-ai block updated)"
}

# ---------------------------------------------------------------------------
# Step 1: Check versions file
# ---------------------------------------------------------------------------
if [ ! -f "$VERSIONS_FILE" ]; then
  echo "No core-ai tools installed (no $VERSIONS_FILE found)."
  exit 0
fi

INSTALLED_TOOLS=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  _tname="${line%@*}"
  INSTALLED_TOOLS="$INSTALLED_TOOLS $_tname"
done < "$VERSIONS_FILE"
INSTALLED_TOOLS="${INSTALLED_TOOLS# }"

if [ -z "$INSTALLED_TOOLS" ]; then
  echo "No core-ai tools installed."
  rm -f "$VERSIONS_FILE"
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 2: Determine which tools to remove
# ---------------------------------------------------------------------------
if [ -n "$TOOL_FLAG" ]; then
  # Validate the tool is actually installed
  _found=0
  for _t in $INSTALLED_TOOLS; do
    [ "$_t" = "$TOOL_FLAG" ] && _found=1 && break
  done
  if [ "$_found" -eq 0 ]; then
    echo "ERROR: '$TOOL_FLAG' is not installed." >&2
    echo "Installed tools: $INSTALLED_TOOLS" >&2
    exit 1
  fi
  TO_REMOVE="$TOOL_FLAG"
else
  TO_REMOVE="$INSTALLED_TOOLS"
fi

# ---------------------------------------------------------------------------
# Step 3: Fetch manifest (best-effort — used to resolve file paths)
# ---------------------------------------------------------------------------
if curl -fsSL "$REPO_BASE/tools.json" -o "$TOOLS_JSON" 2>/dev/null; then
  # Validate: non-empty and starts with {
  if [ ! -s "$TOOLS_JSON" ] || ! grep -q '^{' "$TOOLS_JSON"; then
    rm -f "$TOOLS_JSON"
    touch "$TOOLS_JSON"  # keep the trap target valid
    echo "  note: manifest unavailable — using fallback file paths"
  fi
else
  touch "$TOOLS_JSON"
  echo "  note: could not fetch manifest — using fallback file paths"
fi

# ---------------------------------------------------------------------------
# Step 4: Confirmation
# ---------------------------------------------------------------------------
if [ -z "$YES" ] && [ -t 0 ]; then
  echo ""
  echo "The following tools will be removed:"
  for _t in $TO_REMOVE; do
    _f=$(resolve_file "$_t")
    printf '  %s  (%s)\n' "$_t" "$_f"
  done
  if [ -z "$TOOL_FLAG" ]; then
    echo "  $VERSIONS_FILE"
  fi
  echo ""
  printf "Continue? [y/N] "
  read -r _answer
  case "$_answer" in
    y|Y) : ;;
    *) echo "Aborted."; exit 0 ;;
  esac
fi

# ---------------------------------------------------------------------------
# Step 5: Remove tool files
# ---------------------------------------------------------------------------
echo ""
echo "Removing core-ai tools..."

REMOVED_COUNT=0

# Build list of tools NOT being removed (to detect shared deps)
REMAINING_NOW=""
for _t in $INSTALLED_TOOLS; do
  _keep=1
  for _r in $TO_REMOVE; do
    [ "$_t" = "$_r" ] && _keep=0 && break
  done
  [ "$_keep" -eq 1 ] && REMAINING_NOW="$REMAINING_NOW $_t"
done
REMAINING_NOW="${REMAINING_NOW# }"

for _t in $TO_REMOVE; do
  # Remove the main command file
  _f=$(resolve_file "$_t")
  if [ -f "$_f" ]; then
    rm -f "$_f"
    echo "  removed: $_f"
    REMOVED_COUNT=$(( REMOVED_COUNT + 1 ))
  else
    echo "  missing (already gone): $_f"
  fi

  # Remove deps that are not shared with remaining tools
  _deps=$(get_deps_from_manifest "$_t")
  for _dep in $_deps; do
    _dep_path="$HOME/$_dep"
    [ ! -f "$_dep_path" ] && continue

    # Check if any remaining tool also declares this dep
    _shared=0
    for _other in $REMAINING_NOW; do
      _other_deps=$(get_deps_from_manifest "$_other")
      for _od in $_other_deps; do
        [ "$_od" = "$_dep" ] && _shared=1 && break
      done
      [ "$_shared" -eq 1 ] && break
    done

    if [ "$_shared" -eq 0 ]; then
      rm -f "$_dep_path"
      echo "  removed dep: $_dep_path"
    else
      echo "  keep dep (shared): $_dep_path"
    fi
  done
done

# ---------------------------------------------------------------------------
# Step 6: Update or remove the versions file
# ---------------------------------------------------------------------------
if [ -z "$TOOL_FLAG" ]; then
  # Full uninstall — remove the file entirely
  rm -f "$VERSIONS_FILE"
  echo "  removed: $VERSIONS_FILE"
  REMAINING_TOOLS=""
else
  # Partial uninstall — keep entries for tools that weren't removed
  _tmpv=$(mktemp /tmp/core-ai-versions-XXXXXX)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    _tname="${line%@*}"
    [ "$_tname" = "$TOOL_FLAG" ] && continue
    printf '%s\n' "$line" >> "$_tmpv"
  done < "$VERSIONS_FILE"
  sort "$_tmpv" > "$VERSIONS_FILE"
  rm -f "$_tmpv"
  echo "  updated: $VERSIONS_FILE"

  REMAINING_TOOLS=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    REMAINING_TOOLS="$REMAINING_TOOLS ${line%@*}"
  done < "$VERSIONS_FILE"
  REMAINING_TOOLS="${REMAINING_TOOLS# }"
fi

# ---------------------------------------------------------------------------
# Step 7: Update CLAUDE.md
# ---------------------------------------------------------------------------
update_claude_md_block "$REMAINING_TOOLS"

# ---------------------------------------------------------------------------
# Step 8: Clean up empty subdirectories (full uninstall only)
# ---------------------------------------------------------------------------
if [ -z "$TOOL_FLAG" ]; then
  for _subdir in commands agents shared prompts; do
    if [ -d "$TARGET/$_subdir" ] && [ -z "$(ls -A "$TARGET/$_subdir" 2>/dev/null)" ]; then
      rmdir "$TARGET/$_subdir"
      echo "  removed: $TARGET/$_subdir (empty)"
    fi
  done
fi

# ---------------------------------------------------------------------------
# Step 9: Summary
# ---------------------------------------------------------------------------
echo ""
echo "Done. $REMOVED_COUNT tool(s) removed."
if [ -n "$REMAINING_TOOLS" ]; then
  echo ""
  echo "Still installed:"
  for _t in $REMAINING_TOOLS; do
    echo "  /$_t"
  done
fi
