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

## What Is Still Not Fully Interaction-Based
These are the highest-impact remaining pockets:

1. Set-piece selection randomness and weighted picks
- `choosePlayType` weighted random selection
- `pickShooterSpot` weighted/random location picks
- `chooseShotFromTendencies` weighted branch picks
- Various branch-level random shot-type/spot tie-breakers

2. Fast-break continuation formulas
- `madeProb` in fast break still uses formula blend after finish interaction
- Could become a direct interaction-derived terminal resolution (or stronger mapping)

3. Free-throw resolution remains attribute-only random roll
- FT events currently do not use direct shooter-vs-context interactions
- This may be acceptable by design, but if strict interaction-only is required, add:
  - `free_throw_focus` (shooter vs pressure context)

4. Timeout and rotation management (non-play simulation logic)
- `maybeCallTimeout`, substitution scoring, minute targets
- Not really "player duel" mechanics, but still probabilistic/heuristic subsystems

5. Misc event randomness
- technical/no-tech selection still has stochastic weighting (now interaction-informed)
- loose-ball foul branch is still a direct rare-event roll

## Recommended Next Order
1. Replace `choosePlayType` and shot/spot selectors with interaction-driven tactical contests.
2. Tighten fast-break finish mapping so make/fail is more directly interaction-determined.
3. Decide policy for FTs:
- keep attribute-only as intentional model simplification, or
- move to interaction-informed pressure model.
4. If strict interpretation includes management systems, interactionize timeout/sub logic too.

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
