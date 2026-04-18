# cbb-coach

College basketball coach simulation game.

## Engine status (v0)

A first simulation engine is in place in [`src/gameEngine.js`](./src/gameEngine.js), with gameplay resolved in **5-second chunks**.

Implemented:
- 20-minute halves, 30-second shot clock.
- Shot/game clock chunk progression.
- Shot-clock turnover when offense still has possession at 0.
- Shot-clock reset to 30 on possession change.
- Shot-clock reset to 30 on shot + offensive rebound.
- Possession setup chunk after changes of possession when not pressed.
- Offensive spots + formations (`5-out`, `4-out 1 post`, `high-low`, `triangle`, `motion`).
- Defenses (`man`, `2-3`, `3-2`, `1-3-1`, `pack-line`).
- Zone behavior:
  - on-ball defender is closest zone defender,
  - baseline zone help bonus,
  - distance-based zone disadvantage on actions starting far from defender,
  - disadvantage reduced by `burst`, `lateralQuickness`, `perimeterDefense`, `offballDefense`.
- Dynamic interaction model where every interaction re-rolls rating influence and slightly biases toward each player’s strongest relevant ratings.
- Beginner offensive actions:
  - `dribble_drive`: decisive/normal/tie/defensive-win branches, help-defense reactions, drive kick-outs, jump/paint finish options, and steal windows.
  - `pick_and_roll`: screen-quality model (screener strength/size + handler setup), dual-defender coverage tradeoffs, pass-IQ read logic, and roll-finisher contests.
  - `pick_and_pop`: shared screen logic with pick-and-roll, plus pop destination choice (elbow vs above-the-break three), shoot/reset decision, and contested pop jumpers.
  - `post_up`: spot-gated post initiation, positioning battle tiers, shoot/pass/give-up branches, and dominant-loss steal chance.
  - `pass_around_for_shot`: multi-pass (up to 4) swing action with moving off-ball teammates, pass-window reads (`passingVision`/`passingIQ`), delivery checks (`passingAccuracy` + receiver `hands` vs nearby defenders), scramble-driven temporary spacing advantage, and neutral reset when no window appears.
- Off-ball get-open interactions include location context: it is easier to create space beyond the arc than near the basket.
- Contested shot foul model:
  - foul chance based on offensive `drawFoul` vs defensive `defensiveControl`,
  - makes on fouls are reduced but still possible,
  - free throws resolved from shooter FT rating.
- Energy/fatigue model:
  - every on-court 5-second action drains player energy,
  - higher involvement in an action drains additional energy,
  - lower stamina players drain faster,
  - bench players recover energy each chunk,
  - halftime, timeouts, and free-throw dead-ball stretches restore energy.
- Substitutions and rotations:
  - lineup changes only occur at dead balls (`made basket`, `out of bounds`, `halftime`, `timeout`),
  - substitution decisions consider energy, relative player skill, and minute targets,
  - optional preset rotation support via `team.rotation.minuteTargets` keyed by player name,
  - if no rotation is provided and a roster has more than 5 players, default minute targets ensure everyone plays at least a little in an average game.
- Team pace profiles:
  - optional team-level `pace` setting (`very_slow`, `slow`, `slightly_slow`, `normal`, `slightly_fast`, `fast`, `very_fast`),
  - pace influences early/neutral-clock shot appetite,
  - late-game game-state adjustment: teams protecting a lead slow down while trailing teams speed up.
- Transition/fast-break flow:
  - only available after live-ball steals or defensive rebounds (never after dead-ball inbounds),
  - two transition chunks: `0-5s` primary break then `5-10s` secondary break,
  - primary break can create open rim runs (layup/dunk only) with optional lead-pass influence from passer accuracy + receiver hands,
  - missed primary-break finishes use trailer-weighted rebound chances,
  - secondary break uses normal shot mix but with potential openness when recovery is late.
- Full-court press / press-break flow:
  - press can trigger based on `tendencies.press` and late-game trailing urgency,
  - offense can break pressure by passing or dribbling over multiple setup chunks,
  - defense traps aggressively (double-team pressure), with trap success influenced by defender excess wingspan and ball-handler passing reads,
  - failure to advance in two setup chunks triggers a 10-second turnover,
  - clean press breaks can immediately flow into transition offense.
- Optional team tendency levers:
  - `tendencies.fastBreakOffense`,
  - `tendencies.crashBoardsOffense` vs `tendencies.defendFastBreakOffense`,
  - `tendencies.crashBoardsDefense` vs `tendencies.attemptFastBreakDefense`,
  - `tendencies.press` and `tendencies.trapRate`,
  - `tendencies.pressBreakPass` and `tendencies.pressBreakAttack`.
- Team coaching staffs:
  - each team has 1 `head_coach` and 4 `assistant` coaches,
  - coach skills include recruiting, player/position development, offense/defense coaching, scouting, and potential,
  - coaches include age, press aggressiveness, pace, default offensive/defensive sets, alma mater, and weighted pipeline state,
  - during games, coach `offensiveCoaching` / `defensiveCoaching` have a slight effect on player performance (head coach weighted most, optional `game prep` assistant weighted second),
  - set the game prep assistant with `coachingStaff.gamePrepAssistantIndex` (0-based into assistants) or `assistant.isGamePrep = true`.

## Quick run

```bash
node src/exampleGame.js
```

## API

Use either `src/gameEngine.js` directly or the barrel export in `src/index.js`.

```js
const {
  createPlayer,
  createCoach,
  createCoachingStaff,
  createTeam,
  simulateGame,
  OffensiveFormation,
  DefenseScheme,
  PaceProfile,
} = require("./src");
```

`createTeam(...)` now auto-generates a full coaching staff when one is not provided. You can pass partial inputs via `coachingStaff` (or `coaches`) and missing roles are filled in.

## Notes for next iteration

- Action selection is intentionally modular in `choosePlayType(...)` so we can add explicit team and lineup decision policy next.
- Rebounding uses a first-pass model for man/zone behavior and can be expanded with explicit boxer/boxed assignments.
