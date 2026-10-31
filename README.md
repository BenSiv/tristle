# tristle

Tristle (short for tri-whistle) is a 3D-printable chord whistle: one
mouthpiece, three windways, three chambers tuned to C5, E5 and G5. Every
blow sounds a three-note chord. Two finger holes per chamber shift each
voice by 0 to +4 semitones.

The three tubes are coiled into a compact, symmetric two-piece body,
about 78 × 41 × 178 mm, that prints without support. Modelled in [luametry](../luametry) (luam + Manifold).

## How it plays

Hold it like a pendant ocarina: holes facing away from you, hands coming
in from both sides, thumbs on the back. The holes form two columns of
three, **one chamber per finger row**:

```
            left hand   right hand
 index        G  ●       ●  G         G chamber (top row, 21 mm apart)
 middle      E  ●         ●  E        E chamber (25 mm)
 ring       C  ●           ●  C       C chamber (bottom row, 32 mm)
```

The rows widen going down. Each row's gap is the natural spacing of
that chamber's holes, which grows with chamber length, so every hole can
be a normal size (4 mm on the G row, 5 mm on the others).

The same rule applies on every row: **the right finger opens first**,
then the left. Half-holing gives the semitones in between:

| fingering (left right) | ●● | ●◐ | ●○ | ◐○ | ○○ |
|---|---|---|---|---|---|
| offset | root | +1 | +2 | +3 | +4 |
| G row | G | G# | A | A# | **B** |
| E row | E | F | F# | G | G# |
| C row | C | C# | D | D# | E |

**B is on the G row with both holes open.** All seven C-major triads are
playable, one note per chamber (C, Dm, Em, F, G, Am, Bdim), plus most
other major and minor triads. `luam tuning.lua` prints the chord and
fingering table.

## How the tubes are routed

Each chamber is one tube, from its labium to an open end on the flat
back face. Each tube runs across the front at its own finger row, with
both holes on that run. The rest winds behind:

1. down from the window,
2. (E and C only) a horizontal run across the free front space above the
   rows (E to the left, C to the right),
3. diagonally back to its own drop column,
4. down to its row, forward, and left to the row's entry,
5. across the front past both finger holes,
6. back, down a little, and out through the back face.

`layout.lua` solves two slack dimensions per chamber: one sets the length
to the first finger hole (G's drop depth, E's and C's front-run length),
the other makes the tube end exactly on the back face. It also checks
that no two tubes come closer than `tube_gap`. View the routing with
`TRISTLE_VIEW=air`.

The outer shell is mirror-symmetric about the centre line, and so are the
windows, the hole grid and the joint. Inside, all three tubes enter their
rows from the left and leave on the right (that's what keeps "right
finger first" true on every row), so the routing itself can't be
mirrored.

## Files

| file | what |
|---|---|
| `config.lua` | every parameter: pitch, bore, fipple, grid, routing planes, joint, holes |
| `tuning.lua` | acoustics: chamber lengths, hole diameters, chord table, calibration |
| `layout.lua` | tube routing, slack solver, clearance check |
| `path.lua` | 3D polyline tubes with rounded corners, measured along the centreline |
| `tristle.lua` | luametry model (head + body, print layout) |
| `export.sh` | writes each printable part to its own STL in `out/` |

```bash
luam tuning.lua                     # lengths, holes, chords
luam layout.lua                     # routing and clearance report
./export.sh                         # out/head.stl, out/body.stl, out/body_calibrate.stl, out/assembled.stl
luametry run tristle.lua            # out/tristle.stl (both parts together)
TRISTLE_VIEW=assembled luametry run tristle.lua -o out/assembled.stl
TRISTLE_VIEW=air       luametry run tristle.lua -o out/air.stl
```

All lengths are measured along the tube centreline from the **labium
edge** (the sharp edge of the window).

## Acoustic model

Each chamber is treated as an open-open pipe:
`L = c / 2f − window correction − 0.61·r`. Holes are placed with a
lossless transfer-matrix model: plane-wave bore segments, each open hole
a shunt inertance, the foot an open end. The pitch of a fingering is
where that model resonates. `luam tuning.lua check` prints every
fingering's pitch in cents (0 after a fresh design; useful after editing
positions or sizes by hand). The simpler closed-form tone-hole formulas
put the two holes of a chamber too close together, by enough to be up to
18 cents out, so they're no longer used. Bends are assumed not to change
the acoustic length; calibration absorbs what's left.

The **window correction** (how much longer the fipple makes the pipe
sound) cannot be predicted well for a fipple. The default is an
orifice-model estimate. Calibrate it on a real print:

1. Print `out/head.stl` and `out/body_calibrate.stl` (a body **without
   finger holes**) from `./export.sh`.
2. Play it warmed up. Tape over two windways at a time and read each root
   on a tuner.
3. `luam tuning.lua calibrate C=521.8 E=657.0 G=781.3`
4. Put the reported value in `config.window_correction`, then print the
   real body. The tubes re-route automatically, and the head's windways
   and tenon don't change, so the head can be reused. The routing solves
   for corrections from about 26 to 36 mm (the estimate is 31); outside
   that, adjust `row_drop` and rerun `luam layout.lua`.

## Mouthpiece

One round inlet (8 mm) at the lips feeds all three chambers, so they
share exactly the same pressure. It ends in a small dome from which a
round channel runs to each chamber. The last few mm before each window
taper smoothly from round to a flat 7 × 1.1 mm jet aimed at the labium.

**Jet speed per chamber.** The pressure is shared, but a lower note wants
a slower jet. Pipe organs solve the same problem by narrowing each pipe's
foot hole ("toe regulation"). Here each lower chamber's channel starts
with a short narrow orifice that opens abruptly into the channel; the
expansion loses some pressure, so that jet comes out slower.

- `jet_match = 1` aims for jet speed in proportion to pitch: G open
  (5 mm), E orifice 3.1 mm (84 % jet speed), C 2.6 mm (67 %).
- Lower it toward 0 if the low chambers sound weak or breathy; set a
  single chamber with its own `orifice_d` (mm).

**Arched labium.** Each labium edge is an arc dipping 2.5 mm at its
centre, like a quena notch or an organ pipe's arched mouth. Printed
mouth-down it forms a self-supporting arch instead of a flat knife-edge
bridge. The 7 mm width makes it louder and easier to print cleanly.

Changing the window's size or shape changes the window correction, so a
new head needs a body computed for it (and a fresh calibration).

## Tuning slide

The head and body meet at a slip joint across the three straight drops
under the windows. Pulling the head out by 1 mm flattens C by about
5 cents and G by about 8 cents, so the whole chord shifts together.
Fine-tuning single notes: enlarging a hole raises its note; partly taping
it lowers it.

## Printing

Each part prints in the orientation that suits it, with no support:

- **Body (78 × 123 × 39 mm): flat on its front face**, finger holes on
  the bed. The front is completely flat (about 3600 mm² of contact) and
  the joint tenon lies on the bed with it. Channels that run across the
  bed have a raised roof on their back side ("up" on the printer, rising
  `print_roof` = 0.8 mm with 45-degree flanks); channels running up
  through the part stay round. Holes on the bed can come out a little
  small from first-layer squish; open them up to size when fine-tuning.
- **Head (58 × 36 × 61 mm): upright on its joint face**, mouth up. That
  face is the full cross-section with the socket recessed into it (about
  1450 mm² of contact). The channels are vertical or tilted at most 35
  degrees, the jet slits are vertical (their most accurate orientation),
  and the arched labium edges have material under them.
- **Joint:** the tenon is on the body and the socket in the head. The
  tenon tip is chamfered at 45 degrees around each bore, so the socket's
  inner end prints as cones instead of a flat ceiling.
  `TRISTLE_VIEW=fit` reports any head/body overlap (should be 0).
- Use a 0.4 mm nozzle and layers of 0.12 mm or less in the head.
- `joint_clearance` sets the slip fit. Print a test joint first if your
  printer runs tight or loose.

## Options

- `twin_holes = true`: recorder-style double holes. The small hole gives
  an exact semitone, so you don't have to judge a half-hole.
- `hole_target` (and a chamber's `hole_d`) set the hole size, and with it
  each row's gap. `row_pitch` sets the row spacing. `layout.lua` re-solves
  the routing and reports any clash or impossible length.
