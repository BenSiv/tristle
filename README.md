# tri-whistle

A 3D-printable chord whistle: one mouthpiece, three windways, three
chambers tuned to C5, E5 and G5. Every blow sounds a three-note chord. Two
finger holes per chamber shift each voice by 0 to +4 semitones.

Modelled in [luametry](../luametry) (luam + Manifold).

## How it plays

Each chamber has two holes: **h1** (lower, opened first) and **h2**
(upper). Half-holing gives the semitones in between:

| fingering (h2 h1) | ●● | ●◐ | ●○ | ◐○ | ○○ |
|---|---|---|---|---|---|
| offset | root | +1 | +2 | +3 | +4 |
| C chamber | C | C# | D | D# | E |
| E chamber | E | F | F# | G | G# |
| G chamber | G | G# | A | A# | **B** |

**The missing B is already there.** Two holes give five states, not four.
With both holes fully open, the G chamber plays B (G + 4 semitones). So
all seven C-major triads are playable, one note per chamber: C, Dm, Em, F,
G, Am and Bdim. So are 11 of the 12 major and 11 of the 12 minor triads.
`luam tuning.lua` prints the full chord and fingering table.

Hole layout, top to bottom, held like a recorder with the holes facing
away from you:

```
 left hand    index  -> G.h2      (G chamber is on your left)
              middle -> G.h1
              ring   -> E.h2
 right hand   index  -> E.h1      (hand break: 28 mm gap)
              middle -> C.h2
              ring   -> C.h1      (C chamber is on your right)
```

## Files

| file | what |
|---|---|
| `config.lua` | every parameter: pitch, bore, fipple, joint, hole positions |
| `tuning.lua` | acoustics: chamber lengths, hole diameters, chord table, calibration |
| `optimize.lua` | searches hole positions for ideal finger spacing; paste results into config |
| `tri_whistle.lua` | luametry model (head + body, print layout) |

```bash
luam tuning.lua                     # lengths, holes, chords
luam optimize.lua                   # re-place holes after changing config
luametry run tri_whistle.lua        # out/tri_whistle.stl (print layout)
TRI_WHISTLE_VIEW=assembled luametry run tri_whistle.lua -o out/assembled.stl
```

All lengths are measured from the **labium edge** (the sharp edge of the
window), not from the lips.

## Acoustic model

Each chamber is treated as an open-open pipe:
`L = c / 2f − window correction − 0.61·r`. Hole sizes come from the
Benade/Flutomat tone-hole formula. Holes are placed for the fingers first
(`optimize.lua`), then each diameter is solved to hit its note.

The **window correction** (how much longer the fipple makes the pipe
sound) cannot be predicted well for a fipple. The default is an
orifice-model estimate. Calibrate it on a real print:

1. `TRI_WHISTLE_VIEW=calibrate luametry run tri_whistle.lua -o out/calibrate.stl`
   gives the head and a body **without finger holes**.
2. Play it warmed up. Tape over two windways at a time and read each root
   on a tuner.
3. `luam tuning.lua calibrate C=521.8 E=657.0 G=781.3`
4. Put the reported value in `config.window_correction`, then print the
   real body. The head is unchanged, so keep it.

Fine-tuning afterwards: enlarging a hole raises its note; partly taping
it lowers it.

## Printing

- Head about 135 mm tall: print it standing on its tenon. The windway is
  then a vertical channel, which is the most accurate orientation.
- Body about 216 mm tall: print it upside down, socket end on the bed.
- Use a 0.4 mm nozzle and layers of 0.12 mm or less around the windway.
  The labium edge needs to be as sharp as the printer allows.
- `joint_clearance` sets the slip fit. Print a test joint first if your
  printer runs tight or loose.

## Options

- `twin_holes = true`: recorder-style double holes. The small hole gives
  an exact semitone, so you don't have to judge a half-hole. The cost is a
  wider finger spread (rerun `optimize.lua`).
- Change `root`s in config to retune, for example a G-B-D chamber set.
