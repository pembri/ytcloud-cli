#!/data/data/com.termux/files/usr/bin/bash
# YT Cloud CLI installer for Termux (single file)
# Usage: ./install.sh

APP="ytcloud"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin/$APP"
OUT_DIR="/sdcard/Download/ytcloud"
RECORD="$HOME/.ytcloud"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"

API_BASE="https://riracloud.my.id/api/ytcloud-cli"
API_KEY="068c2a75086b0d3c4e003c8424abb0adfe074c539fe7e8b00d0f000c413a45e0"
REPO_URL="https://github.com/pembri/ytcloud-cli"

if [ -t 1 ]; then
  C_B=$'\033[1;36m'; C_W=$'\033[1;97m'; C_SUB=$'\033[1;95m'
  C_LBL=$'\033[96m'; C_VER=$'\033[1;92m'; C_DEV=$'\033[1;93m'; C_GH=$'\033[1;94m'
  C_G=$'\033[1;92m'
  C_D=$'\033[2m'; C_R=$'\033[31m'; C_0=$'\033[0m'
else
  C_B=""; C_W=""; C_SUB=""; C_LBL=""; C_VER=""; C_DEV=""; C_GH=""; C_G=""; C_D=""; C_R=""; C_0=""
fi

clear_screen() { [ -t 1 ] && printf '\033[2J\033[3J\033[H'; }

LOGO=(
  '##\     ##\ ########\  ######\  ##\                           ##\ '
  '\##\   ##  |\__##  __|##  __##\ ## |                          ## |'
  ' \##\ ##  /    ## |   ## /  \__|## | ######\  ##\   ##\  ####### |'
  '  \####  /     ## |   ## |      ## |##  __##\ ## |  ## |##  __## |'
  '   \##  /      ## |   ## |      ## |## /  ## |## |  ## |## /  ## |'
  '    ## |       ## |   ## |  ##\ ## |## |  ## |## |  ## |## |  ## |'
  '    ## |       ## |   \######  |## |\######  |\######  |\####### |'
  '    \__|       \__|    \______/ \__| \______/  \______/  \_______|'
)

print_header() {
  local l
  for l in "${LOGO[@]}"; do
    printf '%s%s%s\n' "$C_B" "$l" "$C_0"
  done
  echo

  local title="YT Cloud CLI"
  local subtitle="YouTube Downloader For Termux"
  local dev_label="Developed" dev_value="Rira Project"
  local gh_label="Github" gh_value="$REPO_URL"

  local label_w=${#dev_label}
  [ ${#gh_label} -gt "$label_w" ] && label_w=${#gh_label}
  local dev_label_pad gh_label_pad
  printf -v dev_label_pad '%-*s' "$label_w" "$dev_label"
  printf -v gh_label_pad '%-*s' "$label_w" "$gh_label"
  local dev_row="${dev_label_pad} : ${dev_value}"
  local gh_row="${gh_label_pad} : ${gh_value}"

  local w=0 x
  for x in "$title" "$subtitle" "$dev_row" "$gh_row"; do
    [ ${#x} -gt "$w" ] && w=${#x}
  done
  w=$(( w + 4 ))

  local EDGE_L="${C_B}##${C_0}"
  local EDGE_R="${C_B}## |${C_0}"

  printf '%s%s\\%s\n' "$C_B" "$(printf '#%.0s' $(seq 1 $((w + 4))))" "$C_0"

  local pad left right
  pad=$(( w - ${#title} )); left=$(( pad / 2 )); right=$(( pad - left ))
  printf '%s%*s%s%s%s%*s%s\n' "$EDGE_L" "$left" '' "$C_W" "$title" "$C_0" "$right" '' "$EDGE_R"

  pad=$(( w - ${#subtitle} )); left=$(( pad / 2 )); right=$(( pad - left ))
  printf '%s%*s%s%s%s%*s%s\n' "$EDGE_L" "$left" '' "$C_SUB" "$subtitle" "$C_0" "$right" '' "$EDGE_R"

  printf '%s%*s%s\n' "$EDGE_L" "$w" '' "$EDGE_R"

  local trailing
  trailing=$(( w - 2 - ${#dev_row} ))
  printf '%s  %s%s%s : %s%s%s%*s%s\n' "$EDGE_L" "$C_LBL" "$dev_label_pad" "$C_0" "$C_DEV" "$dev_value" "$C_0" "$trailing" '' "$EDGE_R"

  trailing=$(( w - 2 - ${#gh_row} ))
  printf '%s  %s%s%s : %s%s%s%*s%s\n' "$EDGE_L" "$C_LBL" "$gh_label_pad" "$C_0" "$C_GH" "$gh_value" "$C_0" "$trailing" '' "$EDGE_R"

  printf '%s\\%s |%s\n' "$C_B" "$(printf '#%.0s' $(seq 1 $((w + 3))))" "$C_0"
  printf '%s \\%s/%s\n' "$C_B" "$(printf '_%.0s' $(seq 1 $((w + 2))))" "$C_0"
}

WIDTH=30
STATE_DIR="$(mktemp -d)"
cleanup() { rm -rf "$STATE_DIR"; }
trap cleanup EXIT

DONE_STEPS=()
LAST_LINES=0

draw_bar() {
  local pct=$1 label=$2
  local filled=$(( pct * WIDTH / 100 ))
  local empty=$(( WIDTH - filled ))
  local bar="" i
  for ((i = 0; i < filled; i++)); do bar+="#"; done
  for ((i = 0; i < empty; i++)); do bar+="-"; done
  printf '%s[%s]%s %3d%%  %s' "$C_B" "$bar" "$C_0" "$pct" "$label"
}

# Redraws the whole block in place: completed steps as checkmarks, then
# the live progress bar for the step currently running.
render() {
  local pct="$1" label="$2"
  if [ "$LAST_LINES" -gt 0 ]; then
    printf '\033[%dA\033[J' "$LAST_LINES"
  fi
  local item
  for item in "${DONE_STEPS[@]}"; do
    printf '%s✔%s %s\n' "$C_G" "$C_0" "$item"
  done
  draw_bar "$pct" "$label"
  echo
  LAST_LINES=$(( ${#DONE_STEPS[@]} + 1 ))
}

# Final redraw once everything is done: checklist only, no bar line left behind.
finish_render() {
  if [ "$LAST_LINES" -gt 0 ]; then
    printf '\033[%dA\033[J' "$LAST_LINES"
  fi
  local item
  for item in "${DONE_STEPS[@]}"; do
    printf '%s✔%s %s\n' "$C_G" "$C_0" "$item"
  done
  LAST_LINES=0
}

die() {
  finish_render
  printf '\n%s✖ %s%s\n' "$C_R" "$1" "$C_0"
  exit 1
}

# Like die(), but also shows the last lines of $STATE_DIR/log so a real
# failure (not just "no internet") can actually be diagnosed.
die_with_log() {
  finish_render
  if [ -s "$STATE_DIR/log" ]; then
    printf '\n%s--- details ---%s\n' "$C_D" "$C_0"
    cat "$STATE_DIR/log"
    printf '%s---------------%s\n' "$C_D" "$C_0"
  fi
  printf '\n%s✖ %s%s\n' "$C_R" "$1" "$C_0"
  exit 1
}

# Runs "$@" in the background while animating the bar from $2 to $3-1,
# then snaps to $3 when the job finishes. On success, marks the step done
# (so it becomes a permanent checklist line) and returns 0; else returns 1.
run_step() {
  local label="$1" start="$2" end="$3"; shift 3
  render "$start" "$label"
  ( "$@" ) >"$STATE_DIR/log" 2>&1 &
  local pid=$!
  local pct=$start
  while kill -0 "$pid" 2>/dev/null; do
    sleep 0.2
    if [ "$pct" -lt $(( end - 1 )) ]; then pct=$(( pct + 1 )); fi
    render "$pct" "$label"
  done
  wait "$pid"
  local rc=$?
  render "$end" "$label"
  if [ "$rc" -eq 0 ]; then
    DONE_STEPS+=("$label")
  fi
  return $rc
}

clear_screen
print_header
echo

render 0 "Checking environment"
if ! { [ -d "$PREFIX/bin" ] && command -v pkg >/dev/null 2>&1; }; then
  die "This installer is for Termux only."
fi
render 5 "Checking environment"
DONE_STEPS+=("Checking environment")

HAD_PYTHON=0; command -v python3 >/dev/null 2>&1 && HAD_PYTHON=1
HAD_FFMPEG=0; command -v ffmpeg >/dev/null 2>&1 && HAD_FFMPEG=1
HAD_DENO=0; command -v deno >/dev/null 2>&1 && HAD_DENO=1
HAD_YTDLP=0; command -v yt-dlp >/dev/null 2>&1 && HAD_YTDLP=1

# Makes sure yt-dlp really exists on PATH. A plain "pip install" exit code
# is not enough: an interrupted upgrade leaves a "~t_dlp" leftover that
# makes pip think the package is installed while the command is gone.
ensure_ytdlp() {
  local sp
  sp="$(python3 -c 'import site;print(site.getsitepackages()[0])' 2>/dev/null)"
  [ -n "$sp" ] && rm -rf "$sp"/~*
  python3 -m pip install -U yt-dlp || python3 -m pip install -U --break-system-packages yt-dlp
  if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "yt-dlp hilang dari PATH, reinstall paksa..."
    [ -n "$sp" ] && rm -rf "$sp"/~*
    python3 -m pip install --force-reinstall yt-dlp || python3 -m pip install --force-reinstall --break-system-packages yt-dlp
  fi
  if ! command -v yt-dlp >/dev/null 2>&1; then
    echo "pip gagal, coba paket Termux..."
    python3 -m pip uninstall -y yt-dlp
    pkg install -y yt-dlp
  fi
  command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp tidak ditemukan di PATH"; return 1; }
}
export -f ensure_ytdlp

prepare_env() {
  apt-get update
  pkg install -y python ffmpeg curl || return 1
  pkg install -y deno
  ensure_ytdlp || return 1
  command -v python3 >/dev/null 2>&1 || { echo "python3 tidak ditemukan"; return 1; }
  command -v ffmpeg >/dev/null 2>&1 || { echo "ffmpeg tidak ditemukan"; return 1; }
  command -v yt-dlp >/dev/null 2>&1 || { echo "yt-dlp tidak ditemukan"; return 1; }
  return 0
}
export -f prepare_env

run_step "Preparing environment" 5 60 prepare_env \
  || die_with_log "Could not prepare the environment. See details above."

check_storage() {
  if [ ! -d /sdcard ] || [ ! -w /sdcard ]; then
    echo "Run: termux-setup-storage"
    return 1
  fi
  mkdir -p "$OUT_DIR" || return 1
}
export -f check_storage
export OUT_DIR

run_step "Checking storage access" 60 75 check_storage \
  || die_with_log "Cannot access /sdcard. Run: termux-setup-storage, then try again."

fetch_cli() {
  local tmp="$STATE_DIR/ytcloud.bin"
  curl -fsSL -H "X-YTCLOUD-KEY: $API_KEY" "$API_BASE/download" -o "$tmp" || return 1
  [ -s "$tmp" ] || { echo "Downloaded file is empty"; return 1; }
  head -c 2 "$tmp" | grep -q '#!' || { echo "Downloaded file is not a valid script"; return 1; }
  install -m 755 "$tmp" "$BIN" || return 1
}
export -f fetch_cli
export STATE_DIR BIN API_BASE API_KEY

run_step "Fetching the ytcloud command" 75 95 fetch_cli \
  || die_with_log "Could not download the ytcloud command. Check your internet connection and try again."

# Install record: first line = installer folder, then what this installer added.
{
  echo "$SRC_DIR"
  [ "$HAD_PYTHON" -eq 0 ] && echo "pkg:python"
  [ "$HAD_FFMPEG" -eq 0 ] && echo "pkg:ffmpeg"
  [ "$HAD_DENO" -eq 0 ] && echo "pkg:deno"
  [ "$HAD_YTDLP" -eq 0 ] && echo "pip:yt-dlp"
} > "$RECORD"

VER="$("$BIN" --version 2>/dev/null)"
DONE_STEPS+=("Installed (${VER:-unknown})")
render 100 "Done"
finish_render

echo
printf '%s✔ Done!%s Run:  %s%s%s\n' "$C_G" "$C_0" "$C_W" "$APP" "$C_0"
printf '%sHelp: ytcloud --help   |   Uninstall: ytcloud --remove%s\n' "$C_D" "$C_0"
printf '%sIf "command not found" appears, run: exec $SHELL%s\n' "$C_D" "$C_0"
