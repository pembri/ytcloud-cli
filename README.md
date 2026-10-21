# YT Cloud CLI

**YT Cloud CLI by Rira Project** is a YouTube downloader for your terminal. Download videos in any resolution or audio in many formats, one link or many at once. Built for **Termux (Android)**.

## Features

- Download YouTube **videos** as MP4 in any available resolution (no re-encoding, so it is fast and keeps the original quality)
- Download **audio** as WEBM or M4A (original streams), or as MP3, OPUS, FLAC and WAV (converted automatically with FFmpeg)
- **Multi-download**: give several links and get them all in one run
- Shortcut commands: `--videos` and `--audio` skip the format menu
- Size estimate and confirmation before every download
- Automatic retry when YouTube temporarily refuses a download (HTTP 403)
- Built-in repair command (`--fix`) and one-command update (`--update`)
- Videos and audio are saved in separate folders
- Colorized, easy-to-read terminal UI
- Single-file installer and a clean uninstaller that never touches your downloads

## Requirements

- Termux (Android)
- Internet connection
- `git` (only to clone this repo): `pkg install git`

Everything else (Python, FFmpeg, yt-dlp, Deno, curl) is installed by the installer.

## Installation

```bash
pkg install -y git && git clone https://github.com/pembri/ytcloud-cli && cd ytcloud-cli && chmod +x install.sh && ./install.sh
```

The installer will automatically:
1. Check that you are running Termux
2. Install `python`, `ffmpeg` and `deno`, and check the MP3 and OPUS encoders
3. Install `yt-dlp`
4. Check storage access (tap **Allow** when Android asks for permission)
5. Fetch the `ytcloud` command and install it so it can be run from anywhere

The cloned `ytcloud-cli` folder is removed automatically once installation finishes — you don't need to clean it up yourself, and it isn't needed to run `ytcloud` afterward.

If you see `command not found` after installing, run `exec $SHELL` and try again.

## Usage

| Command | What it does |
|---|---|
| `ytcloud` | Interactive mode, asks for the link |
| `ytcloud "URL"` | Start with a link, then choose video or audio |
| `ytcloud "URL" "URL" "URL"` | Download several links at once |
| `ytcloud --videos "URL"` | Download video directly (skips the format menu) |
| `ytcloud --audio "URL"` | Download audio directly (skips the format menu) |
| `ytcloud --version` | Show the version number |
| `ytcloud --help` | Show the help page |
| `ytcloud --fix` | Fix download errors: updates yt-dlp first, then Deno |
| `ytcloud --update` | Update to the latest version |
| `ytcloud --remove` | Uninstall YT Cloud CLI |

Interactive mode looks like this:

```
╔══════════════════════════════════╗
║   YT Cloud CLI by Rira Project   ║
╚══════════════════════════════════╝

Input URL :
```

Steps:
1. Paste one or more links (separated by spaces)
2. Choose **Format Videos** or **Format Audio**
3. Choose the resolution or audio format
4. Check the estimated size and confirm with `y`
5. The files are saved to their matching folder

### Downloading several links

- Separate the links with spaces, with or without quotes: `ytcloud "URL" "URL"` or `ytcloud URL URL`
- The same works at the `Input URL :` prompt (all links on one line)
- One format choice is applied to every link
- If a video does not have the chosen resolution, the closest lower one is used
- If an original audio stream (WEBM or M4A) is not available for a link, that link is skipped
- One failed link never stops the others, and a summary is shown at the end

### Audio formats

| Format | Type | Notes |
|---|---|---|
| WEBM | Original stream | No conversion, available qualities depend on the video |
| M4A | Original stream | No conversion, available qualities depend on the video |
| MP3 (320 / 192 / 128 kbps) | Converted | Converted with FFmpeg |
| OPUS | Repacked or converted | No quality loss when the source is already Opus |
| FLAC | Converted, lossless | Large files |
| WAV | Converted, PCM 16-bit | Large files |

## Download Location

```
/sdcard/Download/ytcloud/
├── Videos/
└── Audio/
```

The folders are created automatically on the first download.

## Repo Structure

```
ytcloud-cli/
├── install.sh
└── README.md
```

`install.sh` fetches the `ytcloud` command and installs it directly to Termux's `bin` folder. The cloned repo folder is deleted automatically right after installation, so nothing is left behind except the ready-to-use `ytcloud` command.

## Updating

```bash
ytcloud --update
```

This clones a fresh, temporary copy of this repo, reinstalls `ytcloud` from it, and removes the temporary copy afterward — so you always end up on the latest version without any leftover files. The installer also refreshes yt-dlp and Deno while it runs.

If your version is too old to have `--update`, update once by hand:

```bash
git clone https://github.com/pembri/ytcloud-cli && cd ytcloud-cli && chmod +x install.sh && ./install.sh
```

## Uninstall

```bash
ytcloud --remove
```

This will remove:
- The `ytcloud` command
- The install record
- The yt-dlp cache

You'll also be asked whether to keep or remove the packages the installer added on top of what was already on your device (for example `ffmpeg`, `deno`, or `yt-dlp` if they weren't installed before). Keeping them is the safe default if you plan to reinstall later or use them for something else.

Your downloaded files in `/sdcard/Download/ytcloud` are **never** deleted. The folder is only removed when it is completely empty.

## Notes

- Put links in quotes, or use the `Input URL :` prompt. Links containing `&` or `?` can be misread by the terminal.
- Only the single video in a link is downloaded, not whole playlists.
- Private or login-required content cannot be downloaded.
- yt-dlp needs a JavaScript runtime (Deno) to read YouTube. If downloads fail with errors about a JS runtime, cookies or `HTTP 403`, run `ytcloud --fix`.
- This tool uses [yt-dlp](https://github.com/yt-dlp/yt-dlp) and [FFmpeg](https://ffmpeg.org/) as its core engines.

## License

For personal use. Please respect content owners' copyright when downloading or redistributing media.
