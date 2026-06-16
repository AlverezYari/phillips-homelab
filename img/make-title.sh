#!/usr/bin/env bash
# Stamp the "ADVENTURES IN THE HOMELAB / <YEAR> EDITION" pulp title onto cover art.
# Usage: ./make-title.sh <input-art.png> <output.png> [YEAR]
# Font:  set FONT=/path/to/Cinzel-Bold.ttf to override (Trajan/Cinzel-style display serif).
#        Cinzel Bold: https://github.com/google/fonts/raw/main/ofl/cinzel/static/Cinzel-Bold.ttf
# Subtitle override: set SUBTITLE="..." to replace the default "<YEAR> EDITION".
#
# Current cover (img/homelab.png) was produced from img/homelab-2026-art.png with:
#   SUBTITLE="2026 UPDATED EDITION" ./img/make-title.sh img/homelab-2026-art.png img/homelab.png
set -euo pipefail

INPUT="${1:?input art path required}"
OUTPUT="${2:?output path required}"
YEAR="${3:-2026}"
FONT="${FONT:-/tmp/hl-fonts/Cinzel-Bold.ttf}"
SUBTITLE="${SUBTITLE:-${YEAR} EDITION}"

GOLD="#F4C84E"     # bright warm gold title fill
DARK="#1f1103"     # dark outline
SHADOW="#000000D9" # strong drop shadow

W=$(magick identify -format '%w' "$INPUT")

magick "$INPUT" \
  -gravity north -font "$FONT" -kerning 10 \
  -fill "$SHADOW" -stroke none \
    -pointsize 100 -annotate +10+98 "ADVENTURES" \
    -pointsize 56  -annotate +10+218 "IN THE" \
    -pointsize 140 -annotate +10+281 "HOMELAB" \
  -fill "$GOLD" -stroke "$DARK" -strokewidth 4 \
    -pointsize 100 -annotate +0+88  "ADVENTURES" \
    -pointsize 56  -annotate +0+208 "IN THE" \
    -pointsize 140 -annotate +0+271 "HOMELAB" \
  \( -size "${W}x200" xc:none -gravity south -font "$FONT" -kerning 6 \
       -fill black -pointsize 56 -annotate +0+54 "$SUBTITLE" \
       -fill black -pointsize 56 -annotate +0+54 "$SUBTITLE" \
       -fill black -pointsize 56 -annotate +0+54 "$SUBTITLE" \
       -blur 0x7 \) \
    -gravity south -geometry +0+0 -composite \
  -gravity south -kerning 6 \
  -fill "$GOLD" -stroke black -strokewidth 5 \
    -pointsize 56 -annotate +0+54 "$SUBTITLE" \
  -fill "$GOLD" -stroke none \
    -pointsize 56 -annotate +0+54 "$SUBTITLE" \
  "$OUTPUT"

echo "wrote $OUTPUT"
