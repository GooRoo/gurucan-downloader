<!--
SPDX-FileCopyrightText: © 2024 Serhii Olendarenko
SPDX-License-Identifier: CC0-1.0
-->

# Gurucan Downloader

> [!warn] Disclaimer
>
> Use this code at your own risk. It is very probable that you are violating some user agreement or something.
>
> On the other hand, this tool does essentially the same what your web-browser does, but makes it available offline for convenience.

To use it, you need [Nushell](https://www.nushell.sh/) because it's written 100% in Nu and [FFmpeg](https://ffmpeg.org/) to deal with videos.

## Features

- Dump all of your purchased courses.
- Store exercises in Obsidian's Markdown format.
- Download images and files.
- Download videos!
- Embed video thumbnails into video files.

### Missing features

- No support for resuming. (If you stopped the download, you'd need to start from the very beginning).
- Lack of checks for errors. It works on my test use cases, but may not work on yours.
- Anything else, not mentioned explicitly above.

## How to use

```nu
use gurucan
gurucan https://<subdomain>.gurucan.com
```
If you don't wont to enter credentials interactively, you can pass them via parameters:
```nu
gurucan https://<subdomain>.gurucan.com --login <your-email> --password <password>
```
