#!/data/data/com.termux/files/usr/bin/bash
# YT Cloud CLI installer for Termux (single file)
# Usage: ./install.sh

APP="ytcloud"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin/$APP"
OUT_DIR="/sdcard/Download/ytcloud"
RECORD="$HOME/.ytcloud"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL=4

API_BASE="https://riracloud.my.id/api/ytcloud-cli"
API_KEY="068c2a75086b0d3c4e003c8424abb0adfe074c539fe7e8b00d0f000c413a45e0"
REPO_URL="https://github.com/pembri/ytcloud-cli"

if [ -t 1 ]; then
  C_B=$'\033[1;36m'; C_G=$'\033[32m'; C_R=$'\033[31m'
  C_Y=$'\033[33m'; C_D=$'\033[2m'; C_0=$'\033[0m'
else
  C_B=""; C_G=""; C_R=""; C_Y=""; C_D=""; C_0=""
fi

step() { printf '\n%s[%s/%s]%s %s\n' "$C_B" "$1" "$TOTAL" "$C_0" "$2"; }
ok()   { printf '  %s✔%s %s\n' "$C_G" "$C_0" "$1"; }
warn() { printf '  %s!%s %s\n' "$C_Y" "$C_0" "$1"; }
die()  { printf '\n%s✖ %s%s\n' "$C_R" "$1" "$C_0"; exit 1; }

LINE=$(printf '═%.0s' $(seq 1 34))
printf '%s╔%s╗\n' "$C_B" "$LINE"
printf '║   YT Cloud CLI by Rira Project   ║\n'
printf '╚%s╝%s\n' "$LINE" "$C_0"
printf '%sInstaller%s\n' "$C_D" "$C_0"

# 1. Environment
step 1 "Checking environment"
[ -d "$PREFIX/bin" ] && command -v pkg >/dev/null 2>&1 || die "This installer is for Termux only."
ok "Termux detected"

# 2. Preparing environment (quiet: no raw package manager output)
step 2 "Preparing environment"
apt-get update >/dev/null 2>&1
NEW_PKGS=""
command -v python3 >/dev/null 2>&1 || NEW_PKGS="$NEW_PKGS python"
command -v ffmpeg >/dev/null 2>&1 || NEW_PKGS="$NEW_PKGS ffmpeg"
pkg install -y python ffmpeg >/dev/null 2>&1 || die "Could not prepare the environment. Check your internet connection and try again."
NEW_DENO=0
command -v deno >/dev/null 2>&1 || NEW_DENO=1
pkg install -y deno >/dev/null 2>&1
if [ "$NEW_DENO" = 1 ] && command -v deno >/dev/null 2>&1; then NEW_PKGS="$NEW_PKGS deno"; fi
command -v python3 >/dev/null 2>&1 || die "Could not prepare the environment. Check your internet connection and try again."
command -v ffmpeg >/dev/null 2>&1 || die "Could not prepare the environment. Check your internet connection and try again."
NEW_YTDLP=0
command -v yt-dlp >/dev/null 2>&1 || NEW_YTDLP=1
if python3 -m pip install -U yt-dlp >/dev/null 2>&1; then :
elif python3 -m pip install -U --break-system-packages yt-dlp >/dev/null 2>&1; then :
elif pkg install -y yt-dlp >/dev/null 2>&1; then :
else die "Could not prepare the environment. Check your internet connection and try again."
fi
command -v yt-dlp >/dev/null 2>&1 || die "Could not prepare the environment. Check your internet connection and try again."
ok "Environment ready"

# 3. Storage
step 3 "Checking storage access"
try_storage() { mkdir -p "$OUT_DIR" 2>/dev/null && [ -w "$OUT_DIR" ]; }
if ! try_storage; then
  warn "Storage access is not granted yet."
  echo "    Tap 'Allow' on the Android permission pop-up..."
  termux-setup-storage
  for _ in $(seq 1 45); do
    sleep 2
    try_storage && break
  done
fi
try_storage || die "No access to /sdcard. Run 'termux-setup-storage', tap Allow, then run ./install.sh again."
ok "Downloads folder ready: $OUT_DIR"

# 4. Fetch the ytcloud command
step 4 "Fetching the ytcloud command"
command -v curl >/dev/null 2>&1 || pkg install -y curl >/dev/null 2>&1
command -v curl >/dev/null 2>&1 || die "curl is required but could not be installed."

HTTP_CODE="$(curl -sS -o "$BIN.new" -w '%{http_code}' \
  -H "X-YTCLOUD-KEY: $API_KEY" \
  "$API_BASE/download")"

if [ "$HTTP_CODE" != "200" ] || [ ! -s "$BIN.new" ]; then
  rm -f "$BIN.new"
  die "Could not fetch ytcloud (HTTP $HTTP_CODE). Check your internet connection and try again."
fi
chmod 755 "$BIN.new"
mv -f "$BIN.new" "$BIN" || die "Could not install $BIN"

REMOTE_VERSION="$(curl -sS -H "X-YTCLOUD-KEY: $API_KEY" "$API_BASE/version" 2>/dev/null)"
PREV=""
[ -f "$RECORD" ] && PREV="$(grep -E '^(pkg|pip):' "$RECORD" 2>/dev/null)"
{
  printf '%s\n' "$REPO_URL"
  {
    printf '%s\n' "$PREV"
    for p in $NEW_PKGS; do printf 'pkg:%s\n' "$p"; done
    [ "$NEW_YTDLP" = 1 ] && printf 'pip:yt-dlp\n'
  } | grep -E '^(pkg|pip):' | sort -u
} > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
hash -r 2>/dev/null
FOUND="$(command -v ytcloud 2>/dev/null)"
if [ -n "$FOUND" ] && [ "$FOUND" != "$BIN" ]; then
  warn "Another 'ytcloud' comes first in PATH: $FOUND"
  warn "Delete it so the new one is used:  rm $FOUND"
fi
ok "Installed: $BIN ${REMOTE_VERSION:+($REMOTE_VERSION)}"

if [ -d "$SRC_DIR/.git" ] && [ "$(basename "$SRC_DIR")" = "ytcloud-cli" ]; then
  cd "$HOME" 2>/dev/null && rm -rf "$SRC_DIR" 2>/dev/null
fi

printf '\n%s✔ Done!%s Run:  %sytcloud%s\n' "$C_G" "$C_0" "$C_B" "$C_0"
printf '%sHelp: ytcloud --help   |   Uninstall: ytcloud --remove%s\n' "$C_D" "$C_0"
printf '%sIf "command not found" appears, run: exec $SHELL%s\n\n' "$C_D" "$C_0"
