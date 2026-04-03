#!/usr/bin/env sh
# core-ai setup.sh — installs Claude Code tools into any project's .claude/ directory
# Usage:
#   sh setup.sh              # interactive picker
#   sh setup.sh --force      # overwrite existing files
#   sh setup.sh --update     # check for newer versions of installed tools
#   sh setup.sh --tool <name> # install a specific tool directly (CI-safe)
#
# Override repo URL: CORE_AI_REPO=https://your.mirror/path sh setup.sh
set -e

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
REPO_BASE="${CORE_AI_REPO:-https://raw.github.com/ksarango/cs-core-ai/main}"
REPO_BASE="${REPO_BASE%/}"  # strip trailing slash
# Security: only https:// is allowed — blocks file://, ftp://, and local reads
case "$REPO_BASE" in
  https://*) : ;;
  *) echo "ERROR: CORE_AI_REPO must use https:// (got: $REPO_BASE)" >&2; exit 1 ;;
esac
TARGET="$HOME/.claude"
CLAUDE_MD="$TARGET/CLAUDE.md"
VERSIONS_FILE="$TARGET/.core-ai-versions"
TOOLS_JSON=$(mktemp /tmp/core-ai-tools-XXXXXX.json)
VERSIONS_TMP=""  # set later; declared here so the trap covers it
DEST_TMP=""      # set per-download; declared here so the trap covers it
trap 'rm -f "$TOOLS_JSON" "${VERSIONS_TMP:-}" "${DEST_TMP:-}"' EXIT

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------
FORCE=""
UPDATE=""
TOOL_FLAG=""
prev=""  # must be initialized — used to capture value after --tool

for arg in "$@"; do
  case "$arg" in
    --force)  FORCE=1 ;;
    --update) UPDATE=1 ;;
    --tool)   : ;;  # value captured on next iteration via $prev
    *)
      if [ "$prev" = "--tool" ]; then
        TOOL_FLAG="$arg"
      fi
      ;;
  esac
  prev="$arg"
done

# Detect --tool with no following argument
if [ "$prev" = "--tool" ] && [ -z "$TOOL_FLAG" ]; then
  echo "ERROR: --tool requires an argument (e.g. --tool verify-testing-jest)" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# get_version <tool_name>
# Extracts version for a named tool from $TOOLS_JSON using grep/sed.
# tools.json must be flat (one field per line, no nested arrays).
get_version() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"version"' \
    | head -1 \
    | sed 's/.*"version": *"//;s/".*//'
}

# get_file <tool_name>
# Extracts the file path for a named tool from $TOOLS_JSON.
get_file() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"file"' \
    | head -1 \
    | sed 's/.*"file": *"//;s/".*//'
}

# get_description <tool_name>
# Extracts the description for a named tool from $TOOLS_JSON.
get_description() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"description"' \
    | head -1 \
    | sed 's/.*"description": *"//;s/".*//'
}

# get_requires <tool_name>
# Returns comma-separated requires string (e.g. "jest").
get_requires() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"requires"' \
    | head -1 \
    | sed 's/.*"requires": *"//;s/".*//'
}

# get_deps <tool_name>
# Returns space-separated list of dependency file paths (e.g. agents, shared, prompts).
get_deps() {
  _tool="$1"
  awk "/\"name\": *\"$_tool\"/,/\}/" "$TOOLS_JSON" \
    | grep '"deps"' \
    | head -1 \
    | sed 's/.*"deps": *"//;s/".*//'
}

# list_tool_names
# Prints all tool names from tools.json, one per line.
list_tool_names() {
  grep '"name"' "$TOOLS_JSON" | sed 's/.*"name": *"//;s/".*//'
}

# validate_selection <input> <count>
# Returns 0 if input is valid ("all", empty, or space-separated numbers in [1,count]).
validate_selection() {
  _input="$1"
  _count="$2"
  [ -z "$_input" ] && return 0
  [ "$_input" = "all" ] && return 0
  for _tok in $_input; do
    # must be a positive integer
    case "$_tok" in
      *[!0-9]*) return 1 ;;
    esac
    [ "$_tok" -ge 1 ] && [ "$_tok" -le "$_count" ] || return 1
  done
  return 0
}

# inject_claude_md <installed_tools_list>
# Writes/updates the ## core-ai tools block in CLAUDE.md.
# Uses <!-- core-ai:start --> / <!-- core-ai:end --> as sole delimiters.
inject_claude_md() {
  _tools_list="$1"

  # Build the block content
  _block="<!-- core-ai:start -->
## core-ai tools
<!-- managed by core-ai, do not edit manually -->"
  for _t in $_tools_list; do
    _desc=$(get_description "$_t")
    _block="$_block
Installed: /$_t ($_desc)"
  done
  _block="$_block
<!-- core-ai:end -->"

  if [ ! -f "$CLAUDE_MD" ]; then
    printf '%s\n' "$_block" > "$CLAUDE_MD"
    echo "  created: $CLAUDE_MD (core-ai block)"
    return
  fi

  if grep -q '<!-- *core-ai:start *-->' "$CLAUDE_MD"; then
    if ! awk '/<!-- *core-ai:start *-->/,/<!-- *core-ai:end *-->/{next}1' "$CLAUDE_MD" > "$CLAUDE_MD.tmp"; then
      rm -f "$CLAUDE_MD.tmp"
      echo "ERROR: $CLAUDE_MD rewrite failed — aborting injection" >&2
      return 1
    fi
    printf '%s\n' "$_block" >> "$CLAUDE_MD.tmp"
    mv "$CLAUDE_MD.tmp" "$CLAUDE_MD"
    echo "  updated: $CLAUDE_MD (core-ai block replaced)"
  else
    printf '\n%s\n' "$_block" >> "$CLAUDE_MD"
    echo "  updated: $CLAUDE_MD (core-ai block appended)"
  fi
}

# ---------------------------------------------------------------------------
# Step 1: Fetch manifest
# ---------------------------------------------------------------------------
echo "Fetching core-ai manifest..."
if ! curl -fsSL "$REPO_BASE/tools.json" -o "$TOOLS_JSON"; then
  echo "ERROR: failed to fetch tools.json from $REPO_BASE" >&2
  exit 1
fi

# Sanity check: file must be non-empty and start with {
if [ ! -s "$TOOLS_JSON" ] || ! grep -q '^{' "$TOOLS_JSON"; then
  echo "ERROR: tools.json appears malformed or empty" >&2
  exit 1
fi

# Security: validate all tool names contain only [a-zA-Z0-9_-] before any
# awk parsing. Tool names are interpolated into awk regex patterns; a
# malicious name could inject awk system() calls (RCE).
for _n in $(grep '"name"' "$TOOLS_JSON" | sed 's/.*"name": *"//;s/".*//'); do
  case "$_n" in
    *[!a-zA-Z0-9_-]*)
      echo "ERROR: invalid tool name in manifest: '$_n' (only a-z A-Z 0-9 _ - allowed)" >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 2: --update mode
# ---------------------------------------------------------------------------
if [ -n "$UPDATE" ]; then
  echo "Checking for updates..."

  if [ ! -f "$VERSIONS_FILE" ]; then
    echo "No installed tools found. Run setup.sh first to install tools."
    exit 0
  fi

  _updated=0
  _removed=0

  # Scan for deleted tools first — clean up versions file
  _tmpv=$(mktemp /tmp/core-ai-versions-XXXXXX)
  while IFS= read -r line; do
    _tname="${line%@*}"
    _tfile=$(get_file "$_tname")
    if [ -z "$_tfile" ]; then
      # Tool no longer in manifest — remove entry
      echo "  removed from manifest: $_tname (dropping from versions)"
      _removed=$(( _removed + 1 ))
    elif [ ! -f "$_tfile" ]; then
      # File deleted from disk — remove entry
      echo "  file missing on disk: $_tfile (dropping $_tname from versions)"
      _removed=$(( _removed + 1 ))
    else
      printf '%s\n' "$line" >> "$_tmpv"
    fi
  done < "$VERSIONS_FILE"
  sort "$_tmpv" > "$VERSIONS_FILE"
  rm -f "$_tmpv"

  # Snapshot VERSIONS_FILE before the update loop to avoid iterating a file
  # we may write to during the loop (C1 from adversarial review).
  _snap=$(mktemp /tmp/core-ai-versions-snap-XXXXXX)
  cp "$VERSIONS_FILE" "$_snap"

  # Now check versions against the snapshot
  while IFS= read -r line; do
    _tname="${line%@*}"
    _installed_ver="${line#*@}"
    _manifest_ver=$(get_version "$_tname")

    if [ -z "$_manifest_ver" ]; then
      echo "  skip (not in manifest): $_tname"
      continue
    fi

    if [ "$_installed_ver" = "$_manifest_ver" ]; then
      echo "  up to date: $_tname@$_installed_ver"
    else
      printf "  update available: %s (%s → %s). Update? [y/N] " \
        "$_tname" "$_installed_ver" "$_manifest_ver"
      read -r _answer
      case "$_answer" in
        y|Y)
          _dest=$(get_file "$_tname")
          _remote="$REPO_BASE/$_dest"
          mkdir -p "$(dirname "$_dest")"
          DEST_TMP="$_dest.tmp"
          if curl -fsSL "$_remote" -o "$DEST_TMP"; then
            mv "$DEST_TMP" "$_dest"
            DEST_TMP=""
            # Update version entry atomically
            _tmpv2=$(mktemp /tmp/core-ai-versions-XXXXXX)
            grep -v "^${_tname}@" "$VERSIONS_FILE" > "$_tmpv2" || true
            printf '%s@%s\n' "$_tname" "$_manifest_ver" >> "$_tmpv2"
            sort "$_tmpv2" > "$VERSIONS_FILE"
            rm -f "$_tmpv2"
            echo "  updated: $_dest"
            _updated=$(( _updated + 1 ))
          else
            echo "ERROR: failed to download update for $_tname" >&2
            rm -f "$DEST_TMP"
            DEST_TMP=""
          fi
          ;;
        *) echo "  skipped: $_tname" ;;
      esac
    fi
  done < "$_snap"
  rm -f "$_snap"

  echo ""
  echo "Done. $_updated tool(s) updated, $_removed stale entries removed."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 3: Build tool list and auto-detect
# ---------------------------------------------------------------------------
TOOL_NAMES=$(list_tool_names)
# Count tool names by iterating — avoids grep -c exit-code and double-output
# issues under set -e when the manifest has no tools.
TOOL_COUNT=0
for _t in $TOOL_NAMES; do TOOL_COUNT=$(( TOOL_COUNT + 1 )); done

if [ "$TOOL_COUNT" -eq 0 ]; then
  echo "No tools available in manifest. Nothing to install."
  exit 0
fi

# Auto-detect: pre-select tools whose requires match this project
RECOMMENDED=""
if [ -f "./package.json" ]; then
  for _t in $TOOL_NAMES; do
    _req=$(get_requires "$_t")
    case "$_req" in
      *jest*)
        if grep -q '"jest"' ./package.json 2>/dev/null; then
          RECOMMENDED="$RECOMMENDED $_t"
        fi
        ;;
    esac
  done
  RECOMMENDED="${RECOMMENDED# }"  # strip leading space
fi

# ---------------------------------------------------------------------------
# Step 4: Tool selection
# ---------------------------------------------------------------------------

# --tool flag: bypass picker
if [ -n "$TOOL_FLAG" ]; then
  # Validate the tool exists in manifest
  if ! printf '%s\n' "$TOOL_NAMES" | grep -qx "$TOOL_FLAG"; then
    echo "ERROR: unknown tool '$TOOL_FLAG'" >&2
    echo "Available tools:" >&2
    printf '%s\n' "$TOOL_NAMES" | sed 's/^/  /' >&2
    exit 1
  fi
  SELECTED="$TOOL_FLAG"

# Non-interactive (piped stdin)
elif [ ! -t 0 ]; then
  echo "core-ai: interactive mode required. Run directly:"
  echo "  curl -fsSL $REPO_BASE/setup.sh -o setup.sh && sh setup.sh"
  echo "Or install a specific tool:"
  echo "  sh setup.sh --tool <name>"
  echo ""
  echo "Available tools:"
  _i=1
  for _t in $TOOL_NAMES; do
    _desc=$(get_description "$_t")
    printf '  %d. %s — %s\n' "$_i" "$_t" "$_desc"
    _i=$(( _i + 1 ))
  done
  exit 0

# Interactive picker
else
  echo ""
  echo "core-ai — available tools:"
  echo ""
  _i=1
  for _t in $TOOL_NAMES; do
    _desc=$(get_description "$_t")
    _marker=""
    case " $RECOMMENDED " in
      *" $_t "*) _marker=" [recommended]" ;;
    esac
    printf '  %d. %s%s\n     %s\n' "$_i" "$_t" "$_marker" "$_desc"
    _i=$(( _i + 1 ))
  done
  echo ""

  if [ -n "$RECOMMENDED" ]; then
    echo "Recommended for this project: $RECOMMENDED"
    echo "Press Enter to install recommended, type numbers (e.g. 1 2), or 'all'."
  else
    echo "Type tool numbers (e.g. 1 2), 'all', or press Enter to install all."
  fi

  while true; do
    printf "Select: "
    read -r SELECTION
    if validate_selection "$SELECTION" "$TOOL_COUNT"; then
      break
    fi
    echo "  Invalid selection. Enter numbers 1-$TOOL_COUNT, 'all', or press Enter."
  done

  if [ -z "$SELECTION" ]; then
    # Enter with recommended → install recommended (or all if none recommended)
    SELECTED="${RECOMMENDED:-$TOOL_NAMES}"
  elif [ "$SELECTION" = "all" ]; then
    SELECTED="$TOOL_NAMES"
  else
    SELECTED=""
    _i=1
    for _t in $TOOL_NAMES; do
      for _num in $SELECTION; do
        [ "$_num" = "$_i" ] && SELECTED="$SELECTED $_t"
      done
      _i=$(( _i + 1 ))
    done
    SELECTED="${SELECTED# }"
  fi
fi

if [ -z "$SELECTED" ]; then
  echo "Nothing selected. Exiting."
  exit 0
fi

# ---------------------------------------------------------------------------
# Step 5: Install selected tools
# ---------------------------------------------------------------------------
echo ""
echo "Installing core-ai tools into $TARGET/..."
mkdir -p "$TARGET/commands"

INSTALLED_TOOLS=""
VERSIONS_TMP=$(mktemp /tmp/core-ai-versions-XXXXXX)

# Preserve existing entries for tools NOT being installed in this run
if [ -f "$VERSIONS_FILE" ]; then
  while IFS= read -r line; do
    _tname="${line%@*}"
    _in_selected=0
    for _s in $SELECTED; do
      [ "$_s" = "$_tname" ] && _in_selected=1 && break
    done
    [ "$_in_selected" -eq 0 ] && printf '%s\n' "$line" >> "$VERSIONS_TMP"
  done < "$VERSIONS_FILE"
fi

for TOOL in $SELECTED; do
  _ver=$(get_version "$TOOL")
  _file=$(get_file "$TOOL")

  # Guard: manifest must provide both file path and version
  if [ -z "$_file" ] || [ -z "$_ver" ]; then
    echo "ERROR: manifest entry for '$TOOL' is missing file or version field" >&2
    exit 1
  fi

  # Security: file path must stay inside .claude/ — blocks path traversal
  case "$_file" in
    .claude/*) : ;;
    *) echo "ERROR: manifest file path '$_file' must be inside .claude/" >&2; exit 1 ;;
  esac

  DEST="$HOME/$_file"
  REMOTE="$REPO_BASE/$_file"

  mkdir -p "$(dirname "$DEST")"

  if [ -f "$DEST" ] && [ -z "$FORCE" ]; then
    echo "  skip (exists): $DEST  (use --force to overwrite)"
    # Still record in versions if not already tracked
    printf '%s@%s\n' "$TOOL" "$_ver" >> "$VERSIONS_TMP"
    INSTALLED_TOOLS="$INSTALLED_TOOLS $TOOL"
  else
    # Download to a temp file first; move into place only on success.
    # This prevents a Ctrl-C or network drop from leaving a truncated file
    # at $DEST that would then be silently skipped on re-run.
    DEST_TMP="$DEST.tmp"
    if curl -fsSL "$REMOTE" -o "$DEST_TMP"; then
      mv "$DEST_TMP" "$DEST"
      DEST_TMP=""
      printf '%s@%s\n' "$TOOL" "$_ver" >> "$VERSIONS_TMP"
      echo "  installed: $DEST"
      INSTALLED_TOOLS="$INSTALLED_TOOLS $TOOL"
    else
      echo "ERROR: failed to download $TOOL from $REMOTE" >&2
      rm -f "$DEST_TMP"
      DEST_TMP=""
      exit 1
    fi
  fi

  # Install deps (agents, shared, prompts) declared for this tool
  _deps=$(get_deps "$TOOL")
  for _dep in $_deps; do
    # Security: dep path must stay inside .claude/
    case "$_dep" in
      .claude/*) : ;;
      *) echo "ERROR: dep path '$_dep' for '$TOOL' must be inside .claude/" >&2; exit 1 ;;
    esac

    _dep_dest="$HOME/$_dep"
    mkdir -p "$(dirname "$_dep_dest")"

    if [ -f "$_dep_dest" ] && [ -z "$FORCE" ]; then
      echo "  skip (exists): $_dep_dest"
    else
      DEST_TMP="$_dep_dest.tmp"
      if curl -fsSL "$REPO_BASE/$_dep" -o "$DEST_TMP"; then
        mv "$DEST_TMP" "$_dep_dest"
        DEST_TMP=""
        echo "  installed dep: $_dep_dest"
      else
        echo "ERROR: failed to download dep '$_dep' for '$TOOL'" >&2
        rm -f "$DEST_TMP"
        DEST_TMP=""
        exit 1
      fi
    fi
  done
done

INSTALLED_TOOLS="${INSTALLED_TOOLS# }"
sort "$VERSIONS_TMP" > "$VERSIONS_FILE"
rm -f "$VERSIONS_TMP"
VERSIONS_TMP=""

# ---------------------------------------------------------------------------
# Step 6: CLAUDE.md injection
# ---------------------------------------------------------------------------

# Collect all tracked tools for the CLAUDE.md block (not just this run)
ALL_TRACKED=""
while IFS= read -r line; do
  ALL_TRACKED="$ALL_TRACKED ${line%@*}"
done < "$VERSIONS_FILE"
ALL_TRACKED="${ALL_TRACKED# }"

inject_claude_md "$ALL_TRACKED"

# ---------------------------------------------------------------------------
# Step 7: Summary
# ---------------------------------------------------------------------------
echo ""
echo "Done. Reload Claude Code to pick up new commands."
echo ""
echo "Installed tools:"
for _t in $INSTALLED_TOOLS; do
  echo "  /$_t"
done
echo ""
echo "To update later: sh setup.sh --update"
