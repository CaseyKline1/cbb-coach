# Interaction-Only Engine Handoff

## Objective
Finish migrating `GameEngine` so outcomes are decided by explicit player-vs-player (or player-vs-group) interactions, not global probability shortcuts.

## Completed in this pass
- Removed `teamEdge` from possession resolution.
- Removed team-strength helper functions (`compute*OffenseStrength`, `compute*DefenseStrength`).
- Replaced turnover base adjustment with on-ball handler-control vs defender-pressure signal.
- Shot make probability no longer receives global team-strength bonus.
- Rebounds are already interaction-based from prior pass (`resolveReboundOutcome`).
- Converted `resolvePassInterception` to interaction-driven lane contests (`pass_interception_lane` traces).
- Converted core drive/PnR branch gates in `resolvePlay` to interaction-driven decisions:
  - `drive_advantage`, `drive_strip`, `help_rotation`
  - `screen_navigation_point`, `screen_navigation_big`
  - `roller_seal`, `pnr_handler_read`

## Current interaction backbone (already in place)
- Core interaction function: `resolveInteraction(...)`
- Traced wrapper: `resolveInteractionWithTrace(...)`
- Active usage sites:
  - Turnover check
  - Half-court shot contest
  - Fast-break finish contest

## Remaining non-interaction areas (priority order)

### 1) Play-branch decisions in `resolvePlay`
Partially completed (drive + pick-and-roll done). Remaining branches still use direct probability gates and heuristic thresholds.

Targets:
- Pick-and-pop branch gates
- Post-up branch gates
- Pass-around branch gates
- Pop destination / shot type branch heuristics

Recommended approach:
- Introduce explicit interaction labels for each tactical battle, e.g.:
  - `drive_advantage`
  - `help_rotation`
  - `screen_navigation`
  - `roller_seal`
  - `pop_closeout`
- Convert branch decisions from hardcoded thresholds into interaction outcomes.

### 2) Press subsystem (`maybeResolvePress`)
Press currently uses derived chances from aggregate formulas.

Targets:
- Trigger probability
- Trap steal chance
- Attack-after-break trigger

Recommended approach:
- Model as chained interactions:
  - `press_setup` (team context can influence via players on floor)
  - `trap_ball_security` (receiver vs top trap defenders)
  - `break_advantage` (decision to attack)

### 3) Non-shooting/technical foul randomness
`maybeCallTechnicalFoul` and `maybeCallNonShootingFoul` contain global random gates.

Recommended approach:
- Keep rare-event ceilings, but gate with interaction context:
  - defender discipline vs ball-handler control
  - fatigue/hustle/defensiveControl interactions
- Technical fouls can remain partly stochastic but should include frustration proxies (clutch/discipline/foul load).

### 4) Action attempt gate (`willAttemptAction`)
Current possession-level shot/action attempt is formula based.

Recommended approach:
- Add `possession_advantage` interaction between ball-handler and primary defense shell.
- Blend with shot clock pressure so late-clock force still works.

## Guardrails for remaining work
- Keep existing event/stat outputs stable (`eventType`, possession switching, stat increments).
- Add interaction traces for every new interaction label to keep QA transparent.
- Avoid introducing new team-wide scalar shortcuts (the same anti-pattern as `teamEdge`).
- If a team-level tendency is needed, use it as a mild modifier to interaction inputs, not as a direct outcome probability.

## Validation checklist
- `swift build`
- `swift test` (note long/flaky tournament test; rerun isolated failures)
- Sim 10+ games and inspect:
  - realistic TO%, AST%, FTR, OREB/DREB splits
  - no extreme event spikes (e.g., trap steals or non-shooting fouls)
  - play-by-play still coherent

## Suggested next implementation sequence
1. Finish remaining `resolvePlay` branches (pick-and-pop, post-up, pass-around).
2. Convert `maybeResolvePress` chain.
3. Convert foul gates.
4. Convert possession action gate last (hardest to tune globally).
