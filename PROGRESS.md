# Gauntlet progress — dodge-test
Bar: official Godot demo `_reference/2d/dodge_the_creeps` (real frames via `tools/capture.sh`).
Rig: Movie Maker frame capture, same input driver for both games, blind A/B critic.

| Round | Builder change | Critic verdict (blind A/B) | Biggest gap |
|---|---|---|---|
| 0 | rect prototype | — | — |
| 1 | "Deep Glow" rebuild: deep-sea identity (gradient + light shafts + parallax marine snow + seabed + shader vignette, HDR 2D glow); Lumi squid player (vector, faces motion, eased accel, tentacle wiggle, trail, bubbles); 3 code-drawn creatures (pulsing jelly, spinning urchin, telegraphed dart w/ edge warning) with eyes tracking player + colour trails; pearls (+50), close-call bonus (+20); 3 lives w/ i-frames, hit-stop, shake, flash, particle bursts, popups; title w/ attract mode + "DIVE IN" button, READY?/SWIM!, GAME OVER + best; Quicksand (OFL) font; stdlib-synth music + 6 sfx. Frames: see `screenshots/` | **WIN: ours picked over official demo** (blind, labels shuffled; key revealed after verdict) | Critic flagged clipped GAME OVER at f400, a false positive: the text is mid zoom-in and settles clean by f449. Valid leftovers: magenta hit flash too strong (f80), player vs pearl glows look alike, dart can pass over the lives HUD. |

**Status:** exit condition met after round 1 (ours beats the bar in blind A/B). Leftover polish items are in the row above.
