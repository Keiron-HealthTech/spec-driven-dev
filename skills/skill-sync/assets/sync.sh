#!/usr/bin/env bash
# Sync skill metadata to .claude/rules/ Auto-invoke sections
# Usage: ./sync.sh [--dry-run] [--scope <scope>]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")}"
SKILLS_DIR="$REPO_ROOT/skills"
RULES_DIR="$REPO_ROOT/.claude/rules"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Options
DRY_RUN=false
FILTER_SCOPE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
  --dry-run)
    DRY_RUN=true
    shift
    ;;
  --scope)
    FILTER_SCOPE="$2"
    shift 2
    ;;
  --help | -h)
    echo "Usage: $0 [--dry-run] [--scope <scope>]"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would change without modifying files"
    echo "  --scope      Only sync specific scope (root, client, server)"
    echo ""
    echo "Output: .claude/rules/{scope}-agents.md"
    exit 0
    ;;
  *)
    echo -e "${RED}Unknown option: $1${NC}"
    exit 1
    ;;
  esac
done

# Temp directory for scope aggregation
TEMP_DIR=$(mktemp -d)
cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Extract YAML frontmatter field using awk
extract_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
        /^---$/ { in_frontmatter = !in_frontmatter; next }
        in_frontmatter && $1 == field":" {
            # Handle single line value
            sub(/^[^:]+:[[:space:]]*/, "")
            if ($0 != "" && $0 != ">") {
                gsub(/^["'\''"]|["'\''"]$/, "")  # Remove quotes
                print
                exit
            }
            # Handle multi-line value
            getline
            while (/^[[:space:]]/ && !/^---$/) {
                sub(/^[[:space:]]+/, "")
                printf "%s ", $0
                if (!getline) break
            }
            print ""
            exit
        }
    ' "$file" | sed 's/[[:space:]]*$//'
}

# Extract nested metadata field
extract_metadata() {
  local file="$1"
  local field="$2"

  awk -v field="$field" '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }

        /^---$/ { in_frontmatter = !in_frontmatter; next }

        in_frontmatter && /^metadata:/ { in_metadata = 1; next }
        in_frontmatter && in_metadata && /^[a-z]/ && !/^[[:space:]]/ { in_metadata = 0 }

        in_frontmatter && in_metadata && $1 == field":" {
            # Remove "field:" prefix
            sub(/^[^:]+:[[:space:]]*/, "")

            # Single-line scalar: auto_invoke: "Action"
            if ($0 != "") {
                v = $0
                gsub(/^["'\''"]|["'\''"]$/, "", v)
                gsub(/^\[|\]$/, "", v)  # legacy: allow inline [a, b]
                print trim(v)
                exit
            }

            # Multi-line list:
            # auto_invoke:
            #   - "Action A"
            #   - "Action B"
            out = ""
            while (getline) {
                # Stop when leaving metadata block
                if ($0 ~ /^---$/) break
                if ($0 ~ /^[a-z]/ && $0 !~ /^[[:space:]]/) break

                # On multi-line list, only accept "- item" lines. Anything else ends the list.
                line = $0
                if (line ~ /^[[:space:]]*-[[:space:]]*/) {
                    sub(/^[[:space:]]*-[[:space:]]*/, "", line)
                    line = trim(line)
                    gsub(/^["'\''"]|["'\''"]$/, "", line)
                    if (line != "") {
                        if (out == "") out = line
                        else out = out "|" line
                    }
                } else {
                    break
                }
            }

            if (out != "") print out
            exit
        }
    ' "$file"
}

# Extract description from frontmatter
extract_description() {
  local file="$1"
  awk '
        /^---$/ { in_frontmatter = !in_frontmatter; next }
        in_frontmatter && /^description:/ {
            sub(/^description:[[:space:]]*/, "")
            if ($0 != "" && $0 != ">") {
                gsub(/^["'\''"]|["'\''"]$/, "")
                print
                exit
            }
            # Multi-line description (> or |)
            out = ""
            while (getline) {
                if (/^[[:space:]]/) {
                    sub(/^[[:space:]]+/, "")
                    if (out == "") out = $0
                    else out = out " " $0
                } else {
                    break
                }
            }
            print out
            exit
        }
    ' "$file" | sed 's/[[:space:]]*$//'
}

echo -e "${BLUE}Skill Sync - Updating .claude/rules/ Auto-invoke sections${NC}"
echo "==========================================================="
echo ""

# Ensure rules directory exists
mkdir -p "$RULES_DIR"

# 1. Collect skills into temp files per scope + collect skill info for Available Skills table
find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 | while IFS= read -r -d '' skill_file; do

  skill_name=$(extract_field "$skill_file" "name")
  scope_raw=$(extract_metadata "$skill_file" "scope")
  auto_invoke_raw=$(extract_metadata "$skill_file" "auto_invoke")
  description=$(extract_description "$skill_file")

  # Collect skill info for Available Skills table (all skills, regardless of auto_invoke)
  if [ -n "$skill_name" ] && [ -n "$scope_raw" ]; then
    # Get relative path from repo root
    rel_path="${skill_file#$REPO_ROOT/}"

    IFS=', ' read -r -a scopes <<<"$scope_raw"
    for scope in "${scopes[@]}"; do
      scope=$(echo "$scope" | tr -d '[:space:]')
      [ -z "$scope" ] && continue
      [ -n "$FILTER_SCOPE" ] && [ "$scope" != "$FILTER_SCOPE" ] && continue

      # First sentence of description only
      short_desc=$(echo "$description" | sed 's/\. .*//' | head -c 80)
      echo "${skill_name}|${short_desc}|${rel_path}" >>"$TEMP_DIR/${scope}.skills"
    done
  fi

  # Skip if no auto_invoke defined
  [ -z "$scope_raw" ] || [ -z "$auto_invoke_raw" ] && continue

  # Parse scope (comma or space separated)
  IFS=', ' read -r -a scopes <<<"$scope_raw"

  for scope in "${scopes[@]}"; do
    scope=$(echo "$scope" | tr -d '[:space:]')
    [ -z "$scope" ] && continue

    # Filter by scope if specified
    [ -n "$FILTER_SCOPE" ] && [ "$scope" != "$FILTER_SCOPE" ] && continue

    # Parse auto_invoke actions (pipe separated from extract_metadata)
    IFS='|' read -r -a actions <<<"$auto_invoke_raw"

    for action in "${actions[@]}"; do
      action=$(echo "$action" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
      [ -z "$action" ] && continue

      echo "${action}|${skill_name}" >>"$TEMP_DIR/$scope"
    done
  done
done

# 1b. Report skills missing sync metadata
find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md -print0 | while IFS= read -r -d '' skill_file; do
  skill_name=$(extract_field "$skill_file" "name")
  scope_raw=$(extract_metadata "$skill_file" "scope")
  auto_invoke_raw=$(extract_metadata "$skill_file" "auto_invoke")
  if [ -z "$scope_raw" ] || [ -z "$auto_invoke_raw" ]; then
    echo "$skill_name" >>"$TEMP_DIR/.missing"
  fi
done

if [ -f "$TEMP_DIR/.missing" ]; then
  echo -e "${YELLOW}Skills missing sync metadata:${NC}"
  while IFS= read -r name; do
    echo "  - $name"
  done <"$TEMP_DIR/.missing"
  echo ""
fi

# 2. Generate .claude/rules/{scope}-agents.md for each scope
# Collect all scopes (from both .skills and auto-invoke files)
scopes_found=()
for scope_file in "$TEMP_DIR"/*; do
  [ -f "$scope_file" ] || continue
  basename_file=$(basename "$scope_file")
  # Skip hidden files and .skills files (we'll use those within scope processing)
  [[ "$basename_file" == .* ]] && continue
  [[ "$basename_file" == *.skills ]] && continue
  [[ "$basename_file" == "scope_map" ]] && continue
  scopes_found+=("$basename_file")
done

# Also check for scopes that only have .skills files
for skills_file in "$TEMP_DIR"/*.skills; do
  [ -f "$skills_file" ] || continue
  scope=$(basename "$skills_file" .skills)
  # Add if not already in scopes_found
  found=false
  for s in "${scopes_found[@]}"; do
    [ "$s" == "$scope" ] && found=true
  done
  $found || scopes_found+=("$scope")
done

for scope in "${scopes_found[@]}"; do
  output_file="$RULES_DIR/${scope}-agents.md"

  echo -e "${BLUE}Processing: $scope -> .claude/rules/${scope}-agents.md${NC}"

  # Build content
  content="# Agent Skills ($scope)"
  content="${content}

## Available Skills

| Skill | Description | Path |
| --- | --- | --- |"

  # Add available skills
  if [ -f "$TEMP_DIR/${scope}.skills" ]; then
    sorted_skills=$(mktemp)
    sort -t'|' -k1,1 "$TEMP_DIR/${scope}.skills" | uniq >"$sorted_skills"
    while IFS='|' read -r skill_name short_desc rel_path; do
      content="${content}
| \`${skill_name}\` | ${short_desc} | [SKILL.md](${rel_path}) |"
    done <"$sorted_skills"
    rm -f "$sorted_skills"
  fi

  # Add auto-invoke section
  if [ -f "$TEMP_DIR/$scope" ]; then
    content="${content}

## Auto-invoke Skills

When performing these actions, ALWAYS invoke the corresponding skill FIRST:

| Action | Skill |
|--------|-------|"

    sorted_scope_file=$(mktemp)
    sort -t'|' -k1,1 "$TEMP_DIR/$scope" >"$sorted_scope_file"

    while IFS='|' read -r action skill_name; do
      content="${content}
| ${action} | \`${skill_name}\` |"
    done <"$sorted_scope_file"
    rm -f "$sorted_scope_file"
  fi

  if $DRY_RUN; then
    echo -e "${YELLOW}[DRY RUN] Would write to $output_file:${NC}"
    echo "$content"
    echo ""
  else
    echo "$content" >"$output_file"
    echo -e "${GREEN}  ✓ Written ${output_file}${NC}"
  fi
done

echo ""
echo -e "${GREEN}Done!${NC}"
