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
- Converted remaining `resolvePlay` branch gates to interaction-driven decisions:
  - `post_up_advantage`
  - `pick_pop_read`, `pop_destination`
  - `pass_around_creation`
- Converted `maybeResolvePress` to interaction-driven chain:
  - `press_setup`
  - `trap_ball_security`
  - `break_advantage`
- Converted foul triggers to interaction-driven gates:
  - `non_shooting_foul_pressure`
  - `technical_temper`
- Converted possession action gate to interaction-driven contest:
  - `possession_advantage`

## Current interaction backbone (already in place)
- Core interaction function: `resolveInteraction(...)`
- Traced wrapper: `resolveInteractionWithTrace(...)`
- Active usage sites:
  - Turnover check
  - Half-court shot contest
  - Fast-break finish contest

## Remaining non-interaction areas (priority order)

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
1. Calibration and balancing pass for event rates (TO, foul, transition, shot mix) now that all major gates are interaction-driven.
2. Expand QA trace tooling/reporting to summarize interaction label distributions by game/season.
