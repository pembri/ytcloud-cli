#!/data/data/com.termux/files/usr/bin/bash
# YT Cloud CLI installer for Termux (single file)
# Usage: ./install.sh

APP="ytcloud"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
BIN="$PREFIX/bin/$APP"
OUT_DIR="/sdcard/Download/ytcloud"
RECORD="$HOME/.ytcloud"
SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
TOTAL=5

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

# 2. Packages
step 2 "Installing packages (python, ffmpeg)"
apt-get update >/dev/null 2>&1 || warn "Package list update failed, trying anyway"
NEW_PKGS=""
command -v python3 >/dev/null 2>&1 || NEW_PKGS="$NEW_PKGS python"
command -v ffmpeg >/dev/null 2>&1 || NEW_PKGS="$NEW_PKGS ffmpeg"
pkg install -y python ffmpeg || die "Could not install python/ffmpeg. Check your internet connection and try again."
command -v python3 >/dev/null 2>&1 || die "python3 not found after install."
command -v ffmpeg >/dev/null 2>&1 || die "ffmpeg not found after install."
for enc in libmp3lame libopus; do
  if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q " $enc "; then
    ok "ffmpeg encoder: $enc"
  else
    warn "ffmpeg encoder missing: $enc (that audio format will fail)"
  fi
done

# 3. yt-dlp
step 3 "Installing yt-dlp (this can take a minute)"
NEW_YTDLP=0; YT_HOW=pip
command -v yt-dlp >/dev/null 2>&1 || NEW_YTDLP=1
if python3 -m pip install -U yt-dlp >/dev/null 2>&1; then YT_HOW=pip
elif python3 -m pip install -U --break-system-packages yt-dlp >/dev/null 2>&1; then YT_HOW=pip
elif pkg install -y yt-dlp >/dev/null 2>&1; then YT_HOW=pkg
else die "Could not install yt-dlp."
fi
command -v yt-dlp >/dev/null 2>&1 || die "yt-dlp not found after install."
ok "yt-dlp $(yt-dlp --version 2>/dev/null)"

# 4. Storage
step 4 "Checking storage access"
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

# 5. Generate the ytcloud command
step 5 "Generating the ytcloud command"
cat > "$BIN.new" <<'YTCLOUD_EOF'
#!/usr/bin/env python3
import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

VERSION = "v1.0"
OUT_DIR = "/sdcard/Download/ytcloud"
CLR = "\033[K"
USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")


def paint(s, code):
    return f"\033[{code}m{s}\033[0m" if USE_COLOR else s


def header():
    title = "YT Cloud CLI by Rira Project"
    w = len(title) + 6
    print(paint("╔" + "═" * w + "╗", "1;36"))
    print(paint("║", "1;36") + paint(title.center(w), "1;37") + paint("║", "1;36"))
    print(paint("╚" + "═" * w + "╝", "1;36"))
    print()


def heading(text):
    print(paint(text, "1;33"))


def die(msg):
    print(paint(msg, "31"))
    sys.exit(1)


def print_help():
    print(f"""{paint('ytcloud', '1')} {VERSION} - download YouTube videos or audio from your terminal.

{paint('USAGE', '1;33')}
  ytcloud                    Start in interactive mode (it asks for the URL)
  ytcloud "URL"              Start with a URL, then choose video or audio
  ytcloud "URL" "URL" ...    Download several links in one go (also with --videos / --audio)
  ytcloud --videos "URL"     Download video directly (skips the format menu)
  ytcloud --audio "URL"      Download audio directly (skips the format menu)
  ytcloud --remove           Uninstall YT Cloud CLI completely

{paint('OPTIONS', '1;33')}
  --videos      Go straight to video download, then pick a resolution
  --audio       Go straight to audio download, then pick an audio format
  --version     Show the version number
  --remove      Uninstall YT Cloud CLI (your downloaded files are always kept)
  --help, -h    Show this help message

{paint('NOTES', '1;33')}
  - Always put the URL in quotes. Links often contain ? and & which the
    terminal may misread.
  - You can give several links at once, separated by spaces. The same works
    at the "Input URL :" prompt (one line). One format choice is applied to
    every link.
  - Videos are saved as MP4. They are merged without re-encoding, so it is
    fast and keeps the original quality.
  - Audio: WEBM and M4A are the original streams from YouTube. MP3, OPUS,
    FLAC and WAV are converted automatically with FFmpeg.
  - Videos are saved to {OUT_DIR}/Videos and audio to {OUT_DIR}/Audio.

{paint('EXAMPLES', '1;33')}
  ytcloud
  ytcloud "https://youtu.be/xxxxxxxxxxx"
  ytcloud --audio "https://youtu.be/xxxxxxxxxxx"
""")


def bad_usage(msg):
    print(paint(f"Error: {msg}", "31"))
    print("Try: ytcloud --help")
    sys.exit(2)


def parse_args(argv):
    mode, urls = None, []
    for a in argv:
        if a in ("-h", "--help"):
            header()
            print_help()
            sys.exit(0)
        if a == "--version":
            print(VERSION)
            sys.exit(0)
        if a == "--remove":
            do_remove()
            sys.exit(0)
        if a in ("--videos", "--video", "--audio"):
            m = 2 if a == "--audio" else 1
            if mode and mode != m:
                bad_usage("Use only one of --videos or --audio.")
            mode = m
        elif a.startswith("-") and len(a) > 1:
            bad_usage(f"Unknown option: {a}")
        else:
            urls.extend(a.split())
    return mode, urls


def ask(valid):
    while True:
        try:
            v = input("Input : ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(130)
        if v.isdigit() and int(v) in valid:
            return int(v)
        print("Input tidak valid.")


def ask_urls():
    while True:
        try:
            raw = input("Input URL : ")
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(130)
        urls = [t.strip("\"',") for t in raw.split()]
        urls = [t for t in urls if t]
        if urls:
            return urls
        print("URL tidak boleh kosong.")


def ask_yn(prompt):
    while True:
        try:
            a = input(prompt).strip().lower()
        except (EOFError, KeyboardInterrupt):
            print()
            sys.exit(130)
        if a in ("y", "n"):
            return a == "y"


def fmt_dur(s):
    if not s:
        return "-"
    s = int(s)
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}"


def fmt_eta(s):
    s = int(max(s, 0))
    return f"{s // 60:02d}:{s % 60:02d}"


def fmt_size(b):
    if b is None:
        return "-"
    for u in ("B", "KB", "MB", "GB"):
        if b < 1024 or u == "GB":
            return f"{b:.1f}{u}"
        b /= 1024


def num(x):
    try:
        return float(x)
    except (TypeError, ValueError):
        return None


def bar(pct):
    n = int(pct / 10)
    return "#" * n + "-" * (10 - n)


def draw(label, pct, extra):
    sys.stdout.write(f"\r{label.ljust(12)} [{bar(pct)}] {pct:5.1f}% {extra}{CLR}")
    sys.stdout.flush()


def fsize(f, duration):
    s = f.get("filesize") or f.get("filesize_approx")
    if s:
        return s
    tbr = f.get("tbr")
    if tbr and duration:
        return tbr * 1000 / 8 * duration
    return None


def trim_bytes(s, limit):
    # Potong berdasarkan byte UTF-8 (bukan jumlah karakter) supaya nama file
    # tidak melebihi batas 255 byte; "ignore" membuang karakter yang terpotong.
    return s.encode("utf-8")[:limit].decode("utf-8", "ignore").strip()


def run_yt_once(label, args, outtmpl, url):
    tpl = ("download:YTP|%(progress.downloaded_bytes)s|%(progress.total_bytes)s|"
           "%(progress.total_bytes_estimate)s|%(progress.speed)s|%(progress.eta)s")
    cmd = ["yt-dlp", "--no-playlist", "--quiet", "--no-warnings", "--newline",
           "--progress", "--progress-template", tpl] + args + ["-o", outtmpl, url]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    errs = []
    for line in p.stdout:
        line = line.strip()
        if line.startswith("YTP|"):
            _, d, t1, t2, sp, eta = line.split("|")
            d, total = num(d), num(t1) or num(t2)
            sp, eta = num(sp), num(eta)
            if d is not None and total:
                pct = min(d / total * 100, 100.0)
                draw(label, pct, f"{fmt_size(sp)}/s ETA {fmt_eta(eta) if eta is not None else '--:--'}")
        elif line:
            errs.append(line)
    p.wait()
    if p.returncode == 0:
        draw(label, 100.0, "selesai")
        print()
        return True
    print()
    print("\n".join(errs[-8:]))
    return False


def run_yt(label, args, outtmpl, url, tries=3):
    for n in range(1, tries + 1):
        if run_yt_once(label, args, outtmpl, url):
            return True
        if n < tries:
            print(f"  gagal, coba lagi ({n + 1}/{tries})...")
            time.sleep(2)
    return False


def run_ffmpeg(label, cmd, cwd, total):
    full = [cmd[0], "-hide_banner", "-loglevel", "error", "-y",
            "-progress", "pipe:1", "-nostats"] + cmd[1:]
    p = subprocess.Popen(full, cwd=cwd, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT, text=True)
    errs = []
    speed = ""
    for line in p.stdout:
        line = line.strip()
        if "=" not in line:
            if line:
                errs.append(line)
            continue
        k, v = line.split("=", 1)
        if k == "speed":
            speed = v.strip()
        elif k in ("out_time_us", "out_time_ms") and total:
            try:
                t = int(v) / 1e6
            except ValueError:
                continue
            pct = max(0.0, min(100.0, t / total * 100))
            eta = "--:--"
            m = re.match(r"([\d.]+)x", speed)
            if m and float(m.group(1)) > 0:
                eta = fmt_eta((total - t) / float(m.group(1)))
            draw(label, pct, f"{speed or '-'} ETA {eta}")
    p.wait()
    if p.returncode == 0:
        draw(label, 100.0, "selesai")
        print()
        return True
    print()
    print("\n".join(errs[-8:]))
    return False


# ---------- Audio ----------

def audio_formats(formats):
    return [f for f in formats
            if f.get("acodec") not in (None, "none")
            and f.get("vcodec") in (None, "none")
            and "drc" not in str(f.get("format_id", ""))]


def abr_of(f):
    return num(f.get("abr")) or num(f.get("tbr")) or 0


def khz(asr):
    asr = num(asr)
    return f"{asr / 1000:g}kHz" if asr else "?kHz"


def native_audio(formats):
    best = {}
    for f in audio_formats(formats):
        ext = f.get("ext")
        if ext not in ("webm", "m4a"):
            continue
        key = (ext, round(abr_of(f)), f.get("asr"))
        note = (f.get("format_note") or "").lower()
        score = (("original" in note or "default" in note), abr_of(f))
        if key not in best or score > best[key][0]:
            best[key] = (score, f)
    items = [v[1] for v in best.values()]
    items.sort(key=lambda f: (f["ext"] != "webm", -abr_of(f)))
    return items


def build_audio_options(formats, duration):
    cand = audio_formats(formats)
    if not cand:
        return []
    src = max(cand, key=abr_of)
    src_abr = abr_of(src)
    src_asr = num(src.get("asr")) or 44100
    ch = int(num(src.get("audio_channels")) or 2)
    opts = []

    for f in native_audio(formats):
        opts.append({"label": f"{f['ext'].upper()} (~{abr_of(f):.0f} kbps, {khz(f.get('asr'))})",
                     "kind": "native", "fmt": f, "est": fsize(f, duration)})

    for k in (320, 192, 128):
        opts.append({"label": f"MP3 (~{k} kbps, 44.1kHz)", "kind": "mp3", "kbps": k,
                     "src": src, "est": k * 1000 / 8 * duration if duration else None})

    opus_copy = str(src.get("acodec", "")).startswith("opus")
    opus_k = src_abr if (opus_copy and src_abr) else 160
    opts.append({"label": f"OPUS (~{opus_k:.0f} kbps, 48kHz)", "kind": "opus", "copy": opus_copy,
                 "src": src, "est": opus_k * 1000 / 8 * duration if duration else None})

    opts.append({"label": f"FLAC (lossless, {khz(src_asr)})", "kind": "flac", "src": src,
                 "est": src_asr * ch * 2 * duration * 0.6 if duration else None})
    opts.append({"label": f"WAV (PCM 16-bit, {khz(src_asr)})", "kind": "wav", "src": src,
                 "est": src_asr * ch * 2 * duration if duration else None})
    return opts


def convert_cmd(opt, audio, out):
    k = opt["kind"]
    base = ["ffmpeg", "-i", audio, "-vn"]
    if k == "mp3":
        return base + ["-c:a", "libmp3lame", "-b:a", f"{opt['kbps']}k", "-ar", "44100", out]
    if k == "opus":
        if opt["copy"]:
            return base + ["-c:a", "copy", out]
        return base + ["-c:a", "libopus", "-b:a", "160k", out]
    if k == "flac":
        return base + ["-c:a", "flac", out]
    return base + ["-c:a", "pcm_s16le", out]


# ---------- Uninstall ----------

def do_remove():
    header()
    home = os.path.realpath(os.path.expanduser("~"))
    prefix = os.environ.get("PREFIX", "/data/data/com.termux/files/usr")
    cmds = []
    for p in (os.path.abspath(__file__), os.path.join(prefix, "bin", "ytcloud")):
        if os.path.lexists(p) and p not in cmds:
            cmds.append(p)

    record = os.path.join(home, ".ytcloud")
    repo = None
    lines = []
    if os.path.isfile(record):
        try:
            with open(record, encoding="utf-8") as fh:
                lines = [x.strip() for x in fh.read().splitlines() if x.strip()]
            raw = lines[0] if lines else ""
        except OSError:
            raw = ""
        cand = os.path.realpath(raw) if raw else ""
        if (cand.startswith(home + os.sep) and os.path.basename(cand) == "ytcloud-cli"
                and os.path.isfile(os.path.join(cand, "install.sh"))):
            repo = cand

    tracked = [x for x in lines[1:] if x.startswith(("pip:", "pkg:"))]
    cache = os.path.join(home, ".cache", "yt-dlp")
    print(paint("This will remove YT Cloud CLI:", "1;33"))
    for p in cmds:
        print(f"  - {p}")
    if repo:
        print(f"  - {repo}  (installer folder)")
    if os.path.isfile(record):
        print(f"  - {record}  (install record)")
    if os.path.isdir(cache):
        print(f"  - {cache}  (yt-dlp cache)")
    print()
    print(paint(f"Your downloaded files in {OUT_DIR} are never touched.", "2"))
    if tracked:
        names = ", ".join(x.split(":", 1)[1] for x in tracked)
        print(paint(f"Packages added by the installer ({names}) are asked about separately.", "2"))
    else:
        print(paint("Python, FFmpeg and yt-dlp were already on this device, so they are kept.", "2"))
    print()
    if not ask_yn("Continue? (y/n) : "):
        print("Cancelled.")
        return

    del_pk = False
    if tracked:
        names = ", ".join(x.split(":", 1)[1] for x in tracked)
        del_pk = ask_yn(f"Also uninstall packages the installer added ({names})? (y/n) : ")
    print()

    def drop(path, is_dir=False):
        if not os.path.lexists(path):
            return
        try:
            if is_dir:
                shutil.rmtree(path)
            else:
                os.remove(path)
            print(paint(f"  ✔ removed {path}", "32"))
        except OSError as e:
            print(paint(f"  ✖ could not remove {path}: {e}", "31"))

    if os.path.isdir(OUT_DIR):
        for sub in ("Videos", "Audio"):
            try:
                os.rmdir(os.path.join(OUT_DIR, sub))
            except OSError:
                pass
        try:
            os.rmdir(OUT_DIR)
            print(paint(f"  ✔ removed empty folder {OUT_DIR}", "32"))
        except OSError:
            print(paint(f"  ✔ kept your downloads in {OUT_DIR}", "32"))
    if repo:
        drop(repo, True)
    if os.path.isfile(record):
        drop(record)
    for p in cmds:
        drop(p)
    drop(cache, True)
    if del_pk:
        def rank(x):
            kind, name = x.split(":", 1)
            return (kind != "pip", name == "python")
        for x in sorted(tracked, key=rank):
            kind, name = x.split(":", 1)
            if kind == "pip":
                c = [sys.executable, "-m", "pip", "uninstall", "-y", name]
            else:
                c = ["pkg", "uninstall", "-y", name]
            rc = subprocess.run(c, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
            if rc == 0:
                print(paint(f"  ✔ uninstalled {name}", "32"))
            else:
                print(paint(f"  ✖ could not uninstall {name}", "31"))
    print()
    print(paint("✔ YT Cloud CLI has been removed.", "32"))
    print("If the shell still finds 'ytcloud', run: exec $SHELL")


class ItemError(Exception):
    pass


def fetch_info(url):
    r = subprocess.run(["yt-dlp", "-J", "--no-playlist", url],
                       capture_output=True, text=True)
    if r.returncode != 0:
        lines = r.stderr.strip().splitlines()
        raise ItemError(lines[-1] if lines else "Gagal ambil info video.")
    try:
        info = json.loads(r.stdout)
    except ValueError:
        raise ItemError("Info video tidak bisa dibaca.")
    return {"url": url, "title": info.get("title", "video"),
            "duration": info.get("duration") or 0,
            "formats": info.get("formats", [])}


def video_best(formats):
    best = {}
    for f in formats:
        w, h = f.get("width"), f.get("height")
        if not w or not h or f.get("vcodec") in (None, "none"):
            continue
        label = min(w, h)
        score = (f.get("acodec") in (None, "none"), f.get("tbr") or 0)
        if label not in best or score > best[label][0]:
            best[label] = (score, f)
    return {k: v[1] for k, v in best.items()}


def pick_height(best, wanted):
    lower = [h for h in best if h <= wanted]
    return max(lower) if lower else min(best)


def video_plan(item, wanted):
    best = video_best(item["formats"])
    if not best:
        return None
    h = pick_height(best, wanted)
    vfmt = best[h]
    audios = audio_formats(item["formats"])
    afmt = max(audios, key=abr_of) if audios else None
    vs = fsize(vfmt, item["duration"])
    as_ = fsize(afmt, item["duration"]) if afmt else None
    return {"height": h, "fmt": vfmt, "est": (vs or 0) + (as_ or 0)}


def match_option(tpl, ref_opts, item_opts):
    if tpl["kind"] != "native":
        for o in item_opts:
            if o["kind"] == tpl["kind"] and o.get("kbps") == tpl.get("kbps"):
                return o
        return None
    ext = tpl["fmt"]["ext"]
    ref_same = [o for o in ref_opts if o["kind"] == "native" and o["fmt"]["ext"] == ext]
    rank = ref_same.index(tpl)
    item_same = [o for o in item_opts if o["kind"] == "native" and o["fmt"]["ext"] == ext]
    if not item_same:
        return None
    return item_same[min(rank, len(item_same) - 1)]


def first_file(tmp, pattern):
    found = [p for p in glob.glob(os.path.join(tmp, pattern))
             if not p.endswith((".part", ".ytdl"))]
    if not found:
        raise ItemError("File hasil unduhan tidak ditemukan.")
    return found[0]


def safe_title(title):
    safe = re.sub(r'[\\/:*?"<>|\x00-\x1f\x7f]', "_", title).strip()
    return trim_bytes(safe, 200).strip(" .") or "video"


def unique_base(base, used):
    name, n = base, 2
    while name in used:
        name = f"{base} ({n})"
        n += 1
    used.add(name)
    return name


def download_one(item, mode, plan, base):
    url, duration = item["url"], item["duration"]
    tmp = tempfile.mkdtemp(prefix="ytdl_")
    try:
        if mode == 1:
            if not run_yt(f"Videos {plan['height']}p", ["-f", plan["fmt"]["format_id"]],
                          os.path.join(tmp, "video.%(ext)s"), url):
                raise ItemError("Download video gagal.")
            if not run_yt("Audio", ["-f", "bestaudio"],
                          os.path.join(tmp, "audio.%(ext)s"), url):
                raise ItemError("Download audio gagal.")
            video = first_file(tmp, "video.*")
            audio = first_file(tmp, "audio.*")
            ext = "mp4"
            out_tmp = os.path.join(tmp, "out.mp4")
            cmd = ["ffmpeg", "-i", video, "-i", audio,
                   "-map", "0:v:0", "-map", "1:a:0", "-c", "copy", out_tmp]
            if not run_ffmpeg("Merge", cmd, tmp, duration):
                raise ItemError("Merge ffmpeg gagal.")
        else:
            dl = plan["fmt"] if plan["kind"] == "native" else plan["src"]
            if not run_yt("Audio", ["-f", dl["format_id"]],
                          os.path.join(tmp, "audio.%(ext)s"), url):
                raise ItemError("Download audio gagal.")
            audio = first_file(tmp, "audio.*")
            if plan["kind"] == "native":
                ext = os.path.splitext(audio)[1].lstrip(".") or dl.get("ext", "m4a")
                out_tmp = audio
            else:
                ext = plan["kind"]
                out_tmp = os.path.join(tmp, "out." + ext)
                if not run_ffmpeg("Convert", convert_cmd(plan, audio, out_tmp), tmp, duration):
                    raise ItemError("Konversi ffmpeg gagal.")
        out_dir = os.path.join(OUT_DIR, "Videos" if mode == 1 else "Audio")
        try:
            os.makedirs(out_dir, exist_ok=True)
        except OSError:
            raise ItemError(f"Tidak bisa membuat folder {out_dir}")
        dest = os.path.join(out_dir, f"{base}.{ext}")
        shutil.move(out_tmp, dest)
        return dest
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main():
    mode, urls = parse_args(sys.argv[1:])
    header()

    for b in ("yt-dlp", "ffmpeg"):
        if not shutil.which(b):
            die(f"{b} belum terinstall.")

    if not urls:
        urls = ask_urls()
        print()
    seen = set()
    urls = [u for u in urls if not (u in seen or seen.add(u))]
    total_n = len(urls)

    items, failed = [], []
    for i, u in enumerate(urls, 1):
        sys.stdout.write(paint(f"Mengambil info video ({i}/{total_n})...", "2"))
        sys.stdout.flush()
        try:
            items.append(fetch_info(u))
        except ItemError as e:
            failed.append((u, str(e)))
        sys.stdout.write("\r" + CLR)
    sys.stdout.flush()
    for label, why in failed:
        print(paint(f"✖ {label}: {why}", "31"))
    if not items:
        die("Tidak ada URL yang bisa diproses.")

    if len(items) == 1:
        it = items[0]
        print(f"{paint('URL', '2')}      : {it['url']}")
        print(f"{paint('Title', '2')}    : {it['title']}")
        print(f"{paint('Duration', '2')} : {fmt_dur(it['duration'])}")
    else:
        print(paint(f"Ditemukan {len(items)} video:", "1"))
        for i, it in enumerate(items, 1):
            print(f"  {i}) {it['title']}  [{fmt_dur(it['duration'])}]")
    print()

    if mode is None:
        heading("Select Format")
        print("  1) Format Videos")
        print("  2) Format Audio")
        mode = ask(range(1, 3))
        print()

    if mode == 1:
        heights = sorted({h for it in items for h in video_best(it["formats"])}, reverse=True)
        if not heights:
            die("Tidak ada resolusi video yang tersedia.")
        heading("Select Videos Quality")
        for i, h in enumerate(heights, 1):
            print(f"  {i}) {h}p")
        wanted = heights[ask(range(1, len(heights) + 1)) - 1]
        print()
        plans = [video_plan(it, wanted) for it in items]
    else:
        refs = [build_audio_options(it["formats"], it["duration"]) for it in items]
        ref_opts = max(refs, key=len)
        if not ref_opts:
            die("Tidak ada format audio yang tersedia.")
        heading("Select Audio Format")
        for i, o in enumerate(ref_opts, 1):
            print(f"  {i}) {o['label']}")
        tpl = ref_opts[ask(range(1, len(ref_opts) + 1)) - 1]
        print()
        plans = [match_option(tpl, ref_opts, o) if o else None for o in refs]

    est = 0
    todo = []
    for it, pl in zip(items, plans):
        if pl is None:
            failed.append((it["title"], "format yang dipilih tidak tersedia"))
        else:
            todo.append((it, pl))
            est += pl["est"] or 0
    if not todo:
        die("Tidak ada item yang bisa diunduh dengan pilihan itu.")

    if len(items) > 1:
        heading("Plan")
        for it, pl in zip(items, plans):
            if pl is None:
                print(paint(f"  - {it['title']}: not available, skipped", "31"))
                continue
            if mode == 1:
                what_pl = f"{pl['height']}p"
                if pl["height"] != wanted:
                    what_pl += f" ({wanted}p not available)"
            else:
                what_pl = pl["label"]
            size = f"~{fmt_size(pl['est'])}" if pl["est"] else "unknown"
            print(f"  - {it['title']}: {what_pl}, {size}")
        print()

    est_txt = f"~{fmt_size(est)}" if est else "unknown"
    what = "video" if mode == 1 else "audio"
    label_sz = (f"Estimated {what} size" if len(todo) == 1
                else f"Estimated total size ({len(todo)} items)")
    if not ask_yn(f"{label_sz} : {est_txt}, are you sure you want to "
                  f"continue downloading? (y/n) : "):
        die("Dibatalkan.")
    print()

    try:
        os.makedirs(OUT_DIR, exist_ok=True)
    except OSError:
        die("Tidak bisa akses /sdcard. Jalankan: termux-setup-storage")

    used = set()
    done = []
    try:
        for n, (it, pl) in enumerate(todo, 1):
            if len(todo) > 1:
                print(paint(f"[{n}/{len(todo)}] {it['title']}", "1;36"))
            base = unique_base(safe_title(it["title"]), used)
            try:
                path = download_one(it, mode, pl, base)
            except ItemError as e:
                failed.append((it["title"], str(e)))
                print(paint(f"✖ {e}", "31"))
            else:
                done.append(path)
                print()
                print(paint(f"✔ Selesai: {path}", "32"))
            print()
    except KeyboardInterrupt:
        print()
        die("Dibatalkan.")

    if total_n > 1:
        print(paint(f"Selesai {len(done)} dari {total_n}", "1;33" if failed else "1;32"))
        for label, why in failed:
            print(paint(f"  ✖ {label}: {why}", "31"))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
YTCLOUD_EOF
[ -s "$BIN.new" ] || die "Could not write $BIN.new"
python3 -c "import ast,sys; ast.parse(open(sys.argv[1], encoding='utf-8').read())" "$BIN.new" \
  || { rm -f "$BIN.new"; die "Generated ytcloud failed the syntax check. Your existing ytcloud was left untouched."; }
chmod 755 "$BIN.new"
mv -f "$BIN.new" "$BIN" || die "Could not install $BIN"
PREV=""
[ -f "$RECORD" ] && PREV="$(grep -E '^(pkg|pip):' "$RECORD" 2>/dev/null)"
{
  printf '%s\n' "$SRC_DIR"
  {
    printf '%s\n' "$PREV"
    for p in $NEW_PKGS; do printf 'pkg:%s\n' "$p"; done
    [ "$NEW_YTDLP" = 1 ] && printf '%s:yt-dlp\n' "$YT_HOW"
  } | grep -E '^(pkg|pip):' | sort -u
} > "$RECORD.tmp" && mv "$RECORD.tmp" "$RECORD"
hash -r 2>/dev/null
FOUND="$(command -v ytcloud 2>/dev/null)"
if [ -n "$FOUND" ] && [ "$FOUND" != "$BIN" ]; then
  warn "Another 'ytcloud' comes first in PATH: $FOUND"
  warn "Delete it so the new one is used:  rm $FOUND"
fi
ok "Installed: $BIN ($("$BIN" --version))"

printf '\n%s✔ Done!%s Run:  %sytcloud%s\n' "$C_G" "$C_0" "$C_B" "$C_0"
printf '%sHelp: ytcloud --help   |   Uninstall: ytcloud --remove%s\n' "$C_D" "$C_0"
printf '%sIf "command not found" appears, run: exec $SHELL%s\n\n' "$C_D" "$C_0"
