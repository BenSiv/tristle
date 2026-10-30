# tristle

Tristle (short for tri-whistle) is a 3D-printable chord whistle: one
mouthpiece, three windways, three chambers tuned to C5, E5 and G5. Every
blow sounds a three-note chord. Two finger holes per chamber shift each
voice by 0 to +4 semitones.

The three tubes are coiled into a compact two-piece body, about
86 × 42 × 151 mm. Modelled in [luametry](../luametry) (luam + Manifold).

## How it plays

Hold it like a pendant ocarina: holes facing away from you, hands coming
in from both sides, thumbs on the back. The holes form two columns of
three, **one chamber per finger row**:

```
            left hand   right hand
 index        C  ●         ●  C      C chamber (top row)
 middle       E  ●         ●  E      E chamber
 ring         G  ●         ●  G      G chamber (bottom row)
```

The same rule applies on every row: **the right finger opens first**,
then the left. Half-holing gives the semitones in between:

| fingering (left right) | ●● | ●◐ | ●○ | ◐○ | ○○ |
|---|---|---|---|---|---|
| offset | root | +1 | +2 | +3 | +4 |
| C row | C | C# | D | D# | E |
| E row | E | F | F# | G | G# |
| G row | G | G# | A | A# | **B** |

**B is on the G row with both holes open.** All seven C-major triads are
playable, one note per chamber (C, Dm, Em, F, G, Am, Bdim), plus most
other major and minor triads. `luam tuning.lua` prints the chord and
fingering table.

## How the tubes are routed

Each chamber is one tube, from its labium down to an open end. Each tube
runs across the front at its own finger row, with both holes on that run.
The rest of the tube winds behind or beside the rows:

- **C (top row)**: drops behind the rows, then curls down over the E
  level toward G and comes back up (the U-curl) before turning onto its
  row.
- **E (middle row)**: drops behind, comes forward, and dips slightly on
  its way to its row.
- **G (bottom row)**: jogs left in front of everything and drops down
  the left side to its row.
- **The tube ends face down** into an open skirt under the rows. The skirt
  lets each tube end exactly where tuning needs it, without reaching the
  outer surface.

`layout.lua` solves one slack dimension per chamber (C's U-curl width,
E's dip depth, G's drop position) so that the length along the tube to
the first hole matches tuning. It also checks that no two tubes come
closer than `tube_gap`. View the coil itself with `TRISTLE_VIEW=air`.

## Files

| file | what |
|---|---|
| `config.lua` | every parameter: pitch, bore, fipple, grid, routing planes, joint, holes |
| `tuning.lua` | acoustics: chamber lengths, hole diameters, chord table, calibration |
| `layout.lua` | tube routing, slack solver, clearance check |
| `path.lua` | 3D polyline tubes with rounded corners, measured along the centreline |
| `tristle.lua` | luametry model (head + body, print layout) |

```bash
luam tuning.lua                     # lengths, holes, chords
luam layout.lua                     # routing and clearance report
luametry run tristle.lua            # out/tristle.stl (print layout)
TRISTLE_VIEW=assembled luametry run tristle.lua -o out/assembled.stl
TRISTLE_VIEW=air       luametry run tristle.lua -o out/air.stl
```

All lengths are measured along the tube centreline from the **labium
edge** (the sharp edge of the window).

## Acoustic model

Each chamber is treated as an open-open pipe:
`L = c / 2f − window correction − 0.61·r`. Hole sizes come from the
Benade/Flutomat tone-hole formula. Bends are assumed not to change the
acoustic length, which holds well for gentle bends like these;
calibration absorbs what's left.

The **window correction** (how much longer the fipple makes the pipe
sound) cannot be predicted well for a fipple. The default is an
orifice-model estimate. Calibrate it on a real print:

1. `TRISTLE_VIEW=calibrate luametry run tristle.lua -o out/calibrate.stl`
   gives the head and a body **without finger holes**.
2. Play it warmed up. Tape over two windways at a time and read each root
   on a tuner.
3. `luam tuning.lua calibrate C=521.8 E=657.0 G=781.3`
4. Put the reported value in `config.window_correction`, then print the
   real body. The tubes re-route automatically, and the head's windways
   and tenon don't change, so the head can be reused.

## Tuning slide

The head and body meet at a slip joint across the three straight drops
under the windows. Pulling the head out by 1 mm flattens C by about
5 cents and G by about 8 cents, so the whole chord shifts together.
Fine-tuning single notes: enlarging a hole raises its note; partly taping
it lowers it.

## Printing

- Head (about 57 mm): print it standing on its tenon. The windways are
  then vertical channels, which is the most accurate orientation.
- Body (about 102 mm): print it upside down, joint face on the bed, so
  the skirt opens upward. The internal tubes print as unsupported
  horizontal channels, which is fine at 11 mm on most printers.
- Use a 0.4 mm nozzle and layers of 0.12 mm or less in the head. The
  labium edges need to be as sharp as the printer allows.
- `joint_clearance` sets the slip fit. Print a test joint first if your
  printer runs tight or loose.

## Options

- `twin_holes = true`: recorder-style double holes. The small hole gives
  an exact semitone, so you don't have to judge a half-hole.
- `column_gap` and `row_pitch` set the finger grid. `layout.lua` re-solves
  the routing and reports any clash.
