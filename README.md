# YT Cloud CLI

**YT Cloud CLI by Rira Project** is a YouTube downloader for your terminal. Download videos in any resolution or audio in many formats, one link or many at once. Built for **Termux (Android)**.

## Features

- Download YouTube **videos** as MP4 in any available resolution (no re-encoding, so it is fast and keeps the original quality)
- Download **audio** as WEBM or M4A (original streams), or as MP3, OPUS, FLAC and WAV (converted automatically)
- **Multi-download**: give several links and get them all in one run
- Shortcut commands: `--videos` and `--audio` skip the format menu
- Every selection menu has a `0) Exit` option to cancel cleanly
- Automatic retry when YouTube temporarily refuses a download, tried quietly in the background — you only see an error if every attempt fails
- Built-in repair command (`--fix`) and one-command update (`--update`)
- Videos and audio are saved in separate folders
- Colorized terminal UI that clears the screen before every run, so output never piles up
- Single-file installer and a clean uninstaller that never touches your downloads

## Requirements

- Termux (Android)
- Internet connection
- `git` (only to clone this repo): `pkg install git`

Everything else needed to run YT Cloud CLI is installed automatically by the installer.

## Installation

```bash
pkg install -y git && git clone https://github.com/pembri/ytcloud-cli && cd ytcloud-cli && chmod +x install.sh && ./install.sh
```

The installer will automatically:
1. Check that you are running Termux
2. Prepare the environment (a single progress bar, no clutter)
3. Check storage access (tap **Allow** when Android asks for permission)
4. Fetch and install the `ytcloud` command so it can be run from anywhere

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
| `ytcloud --update` | Update to the latest version (pulls this repo and reinstalls) |
| `ytcloud --remove` | Uninstall YT Cloud CLI |

Interactive mode looks like this:

```
##\     ##\ ########\  ######\  ##\                           ##\
\##\   ##  |\__##  __|##  __##\ ## |                          ## |
 \##\ ##  /    ## |   ## /  \__|## | ######\  ##\   ##\  ####### |
  \####  /     ## |   ## |      ## |##  __##\ ## |  ## |##  __## |
   \##  /      ## |   ## |      ## |## /  ## |## |  ## |## /  ## |
    ## |       ## |   ## |  ##\ ## |## |  ## |## |  ## |## |  ## |
    ## |       ## |   \######  |## |\######  |\######  |\####### |
    \__|       \__|    \______/ \__| \______/  \______/  \_______|

#########################################################\
##                    YT Cloud CLI                     ## |
##            YouTube Downloader For Termux            ## |
##                                                     ## |
##  Version   : v1.9                                   ## |
##  Developed : Rira Project                           ## |
##  Github    : https://github.com/pembri/ytcloud-cli  ## |
\######################################################## |
 \_________________________________________________________/

Input URL :
```

Steps:
1. Paste one or more links (separated by spaces)
2. Choose **Format Videos** or **Format Audio** (or `0` to exit)
3. Choose the resolution or audio format (or `0` to exit)
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
| MP3 (320 / 192 / 128 kbps) | Converted | Good compatibility |
| OPUS | Repacked or converted | No quality loss when the source is already Opus |
| FLAC | Converted, lossless | Large files |
| WAV | Converted, lossless | Largest files |

## Updating

```bash
ytcloud --update
```

This pulls the latest version of this repo and reinstalls the `ytcloud` command. Your downloaded files are never touched.

## Uninstalling

```bash
ytcloud --remove
```

This removes the `ytcloud` command and the installer's own files. Your downloaded files in `/sdcard/Download/ytcloud` are always kept. You will be asked separately whether to also remove the components the installer added, if any.
