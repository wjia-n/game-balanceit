# Balance It — RULES.md
_Workshop Balance edition · v2.0.0 · Authoritative rules. The engine enforces
this document; if implementation conflicts, fix the implementation._

## 1. Objective
Keep the ball on the beam. Drag anywhere to tilt the beam under the ball.
Survive the mode's timer to win (survive tiers + Score Attack), or last as
long as possible (Endless). If the ball rolls off either end, the run ends.

## 2. Setup
- One player (renameable profile, persisted).
- Before each run the player picks a mode: Calm, Breezy, Stormy (PRO),
  Endless, or Score Attack.
- A run begins from the ready phase. The first drag anywhere starts a
  3-2-1-GO countdown, after which physics begins.

## 3. Turn order
Single-player continuous play; there are no turns. The engine owns one
phase machine: `ready → countdown → playing → over`, plus `paused`
whenever the player (or the OS lifecycle) pauses. The watchdog re-arms any
phase found without a live timer.

## 4. Legal moves
- Drag anywhere on the play area: the beam tilts toward the finger.
  Finger left-of-center tilts the left side down; right-of-center tilts
  the right side down.
- Tilt input is legal during `countdown` (pre-aiming) and `playing`.
- Pausing mid-run is legal at any time; resume continues the same run.

## 5. Illegal moves
- No input is accepted during `paused` or `over` (input is ignored, never
  queued).
- There is no way to move the ball directly — only the beam tilts.

## 6. Captures
Not applicable (no opponents, no pieces).

## 7. Special rules
- **Gusts.** At scheduled intervals a gust of wind shoves the ball left or
  right. Strong gusts are announced 0.8s early ("Gust from the left! 💨")
  with a rising warning tone and flashing chevrons.
- **Difficulty ramp.** The longer a run lasts, the stronger and more
  frequent gusts become (up to +80%), and in Endless the beam also gets
  slightly more responsive to tilt (+35% tilt gain). This is the
  speed/complexity progression.
- **Sweet zone (Score Attack only).** The golden band in the middle of the
  beam (|ball| < 0.35) scores 10 pts/s; anywhere else on the beam scores
  4 pts/s. Recovering from the danger zone (|ball| > 0.8) back under 0.5
  scores a +5 "Close call!" bonus.
- **Danger zone.** |ball| > 0.8 triggers a warning ("Careful!! ⚠️") and a
  soft tick sound. It is a warning only — the run ends only at the beam end.

## 8. Scoring
- **Survive tiers (Calm/Breezy/Stormy):** no points; the score is survival
  time. Winning sets a personal best time per tier.
- **Endless:** no points; the score is survival time. Every run, win or
  lose, can set the Endless best.
- **Score Attack:** points as in §7 over a fixed 90s window. If the ball
  falls, the run ends with the score so far. Best score persists.

## 9. Winning conditions
- Calm: survive 45s. Breezy: survive 60s. Stormy: survive 90s.
- Score Attack: survive the 90s window (score is final at the whistle).
- Endless has no win condition — only a best time.

## 10. Draw conditions
Not applicable.

## 11. AI strategy
Not applicable (no opponents). Gust scheduling is random within the
per-mode bounds of §5 in the engine's `DifficultySpec`.

## 12. Edge cases
- Ball exactly at the beam end (|ball| = 1.02): the run ends (lost).
- Ball at |ball| = 1.0 is still alive; only beyond 1.02 ends the run.
- Pause during `countdown` resumes the countdown; pause during `playing`
  resumes physics exactly where it froze.
- App backgrounding auto-pauses the run; the audio pauses and resumes.
- Score Attack: if the ball falls at 89.9s, the score stands (no
  retroactive zeroing).
- A run can never be "stuck": the engine's watchdog re-arms any phase
  found without a live timer within 3 seconds.

## 13. Test cases
1. Drag left → beam tilts left, ball rolls left. Drag right → mirrored.
2. Release finger → beam eases back toward level (target tilt persists at
   last finger position; ball keeps momentum with damping).
3. Do nothing: the ball eventually drifts and falls → lose screen with
   survival time.
4. Survive a full Calm timer → win screen, best time recorded.
5. Gust arrives: warning banner + tone precede strong gusts; chevrons show
   direction while active.
6. Ball crosses 0.8 → "Careful!!" + tick. Recover under 0.5 → narration
   (and +5 in Score Attack).
7. Pause mid-run → beam freezes; resume → continues identically.
8. Background the app mid-run → auto-pause + music pause; foreground →
   music resumes, run still paused until the player resumes.
9. Score Attack: 90s elapse → win screen with final score; golden-zone
   time visibly outscores edge time.
10. Restart from the pause overlay and from the game-over dialog → fresh
    run in `ready` with zeroed state.
11. Stormy mode locked without PRO → tapping it opens the PRO screen.
12. Kill the physics timer (watchdog path): within 3s the run continues
    with no stuck state.
