#!/bin/bash
# Export every printable part as its own STL into out/.
#   out/head.stl            head, mouth end down
#   out/body.stl            body with finger holes, joint face down
#   out/body_calibrate.stl  body without finger holes (for calibration)
#   out/assembled.stl       whole instrument, playing orientation (preview)
set -e
cd "$(dirname "$0")"
LUAMETRY="${LUAMETRY:-luametry}"
if ! command -v "$LUAMETRY" > /dev/null; then
    LUAMETRY="$HOME/projects/luametry/bin/luametry"
fi
mkdir -p out
TRISTLE_PART=head "$LUAMETRY" run tristle.lua -o out/head.stl > /dev/null
TRISTLE_PART=body "$LUAMETRY" run tristle.lua -o out/body.stl > /dev/null
TRISTLE_PART=body TRISTLE_VIEW=calibrate "$LUAMETRY" run tristle.lua -o out/body_calibrate.stl > /dev/null
TRISTLE_VIEW=assembled "$LUAMETRY" run tristle.lua -o out/assembled.stl > /dev/null
rm -f out/*.manifest.json
ls -l out/head.stl out/body.stl out/body_calibrate.stl out/assembled.stl
