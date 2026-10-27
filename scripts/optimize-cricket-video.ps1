param([string]$FFmpeg = 'ffmpeg')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$public = Join-Path $projectRoot 'frontend/public'
$source = Join-Path $public 'cricket_hero.mp4'
# 24fps source: six-frame GOP bounds the keyframe interval to 250ms.
& $FFmpeg -hide_banner -i $source -an -vf 'scale=1280:-2' -c:v libx264 -preset fast -crf 21 -g 6 -keyint_min 6 -sc_threshold 0 -pix_fmt yuv420p -movflags +faststart -y (Join-Path $public 'cricket-scroll.mp4')
if ($LASTEXITCODE -ne 0) { throw 'Video encoding failed' }
& $FFmpeg -hide_banner -ss 0 -i $source -frames:v 1 -q:v 2 -update 1 -y (Join-Path $public 'cricket-poster.jpg')
if ($LASTEXITCODE -ne 0) { throw 'Poster extraction failed' }

