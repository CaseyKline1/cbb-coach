# Interaction Subsystem Handoff

## Current Status
The engine is now largely interaction-driven for possession flow, play branches, press, rebounds, pass interceptions, fouls, and fast-break initiation.

## Newly Completed In This Pass
1. Fast-break gating converted to interactions:
- `fast_break_push`
- `fast_break_race`

2. Shot-contact micro-events converted to interactions:
- `charge_call`
- `rim_block_attempt`
- `and_one_contact`
- `shooting_foul_contact`

3. Fast-break finish continuation converted to interaction-driven quality gate:
- `fast_break_finish_quality`

4. Free-throw makes converted to interaction-informed focus model:
- `free_throw_focus_and_one`
- `free_throw_focus_shooting_foul`
- `free_throw_focus_bonus`
- `free_throw_focus_one_and_one`
- `free_throw_focus_technical`

5. Loose-ball foul trigger converted to interaction-driven scramble gate:
- `loose_ball_scramble`

6. Set-piece selectors converted to interaction-driven decisions:
- `play_type_*` labels in play selection
- `shot_spot_selection`
- `shot_type_selection`

7. Timeout and rotation management interactionized:
- `timeout_pressure`
- `rotation_swap`

8. Technical/no-tech selection moved to interaction-determined offender selection (no stochastic chooser layer).

## What Is Still Not Fully Interaction-Based
No major subsystem-level backlog items remain from this handoff list.

Remaining work is calibration-oriented:
- tune event-rate distributions after the expanded interaction graph
- decide whether to retain minor utility randomness in tie-breakers/selectors for variety

## Recommended Next Order
1. Run calibration pass (TO%, foul rate, block rate, transition frequency, FT rate).
2. Add QA report tooling for interaction label frequency / edge distributions.

## Guardrails
- Keep output semantics stable (`eventType`, possession switch, stat deltas).
- Keep trace labels compact and consistent for QA aggregation.
- Recalibrate after each subsystem pass to avoid unrealistic spikes in:
  - foul rate
  - block rate
  - turnover rate
  - transition points

## Quick Validation Script
After each change batch:
1. `swift build`
2. `swift test` (known flaky long test may require rerun)
3. Run small game samples and compare distributions vs prior baseline.
