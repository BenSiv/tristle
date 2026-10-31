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

# luametry exits 0 even when the script fails, so check its output
run() {
    out="$1"; shift
    log=$(env "$@" "$LUAMETRY" run tristle.lua -o "$out" 2>&1)
    if echo "$log" | grep -q "ERROR"; then
        echo "$log" >&2
        exit 1
    fi
}
run out/head.stl TRISTLE_PART=head
run out/body.stl TRISTLE_PART=body
run out/body_calibrate.stl TRISTLE_PART=body TRISTLE_VIEW=calibrate
run out/assembled.stl TRISTLE_VIEW=assembled
rm -f out/*.manifest.json
ls -l out/head.stl out/body.stl out/body_calibrate.stl out/assembled.stl
