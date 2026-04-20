# Game Engine JS→Swift Port — Handoff

## Status

The original sim engine was a 5,522-line JS file (`gameEngine.bundle.js`) that
modeled each possession as a chain of **interactions** between specific players
(drive → help → pass → shot → rebound contest). A prior agent replaced it with
a flat Swift simulator that resolved a whole possession in one interaction,
picked shot types uniformly, and ignored most team context.

The JS reference was preserved at commit `e988ef4` and extracted to `/tmp/jsengine.js`:

```sh
git show e988ef4:Sources/CBBCoachCore/Resources/js/gameEngine.bundle.js > /tmp/jsengine.js
```

## What's already restored

### Earlier sessions (commits `4d2b3ad` and earlier)

- `NativeGameStateStore` with handle-based state, multi-team trackers
- `resolveInteraction` with weighted skill scores, mobility-size edge,
  logistic probability (matches JS lines ~729–758)
- `getRating` with fatigue, clutch, coaching, and home-court modifiers
  (JS ~632–665)
- Possession loop, shot-clock tracking, plus-minus, minutes/energy
- Assist picker (simple), rebound picker (simple), basic auto-substitutions
- Shot-type selection from player tendencies + court spot
  (`chooseShotFromTendencies`, `pickShooterSpot`) covering layup/dunk/hook/
  fadeaway/close/midrange/three
- Shot-type-specific `shotProfile` make probabilities matching JS ranges
- Corner vs up-top 3PT specialty
- Blocks on missed rim attempts
- `applyPreGameModifiers` in LeagueEngine sets `homeCourtMultiplier`,
  `offensiveCoachingModifier`, `defensiveCoachingModifier` on each player
  before sim

### This session

- **Play-type dispatcher** (`choosePlayType`, `resolvePlay`) — each possession
  now picks one of `dribbleDrive`, `postUp`, `pickAndRoll`, `pickAndPop`,
  `passAroundForShot` weighted by player + formation biases. Each branch
  picks its own shooter/defender/shot-type/spot and returns edge/make/foul
  bonuses and assist candidate indices. Drives rim-attack with foul bonus;
  post-up picks the best post-capable teammate and shoots hooks/fades/layups;
  P&R picks a screener, resolves screen effectiveness, then the roller may
  finish or the ball-handler keeps it; P&P has the screener pop for mid/3;
  pass-around finds the best open-shot teammate.
- **Directional rebounds** — `pickRebounderIndex` now takes the shot type and
  biases toward guards/speed on three-point misses and bigs/strength on rim
  misses.
- **Dead-ball subs + timeouts** — `runAutoSubstitutions` now only fires after
  made shots, turnovers, fouls, and bonus fouls (not every chunk). New
  `maybeCallTimeout` fires when trailing late in the game or when starters
  are gassed; a timeout decrements `team.timeouts` and restores energy to the
  on-court lineup.
- **Clutch sync** — `syncClutchTime` flips each on-court player's
  `condition.clutchTime` each chunk based on half + time + score margin
  (final 5:00, margin ≤ 8).
- **Team fouls + bonus FTs** — `teamFoulsInHalf` is tracked on the stored
  state; `registerDefensiveFoul` increments on every shooting/non-shooting
  foul. A new `maybeCallNonShootingFoul` hook runs on `setup` chunks and
  awards 1-and-1 at 7+ team fouls, double bonus at 10+. Team fouls reset at
  halftime and each overtime.
- **Halftime energy recovery** — `recoverAllPlayersForHalftime` restores 40
  energy to every roster player between halves and between overtimes.
- **Formation cycle** — `advanceOffensiveFormation` cycles
  `team.formation` through `team.formations` each possession.

Tests: 7/7 pass. CLI sample game produced a realistic 80-69 line.

### Follow-up slice (late-night continuation)

- **Game-state-aware play selection** — `choosePlayType` and the per-branch
  rating reads in `resolvePlay` (drive/post/screen/pop) now call `getRating`
  instead of `getBaseRating`, so fatigue, clutch, coaching, and home-court
  modifiers bite on play choice and shot selection. Hot-hand / tired-legs
  now swing what a ball-handler tries to do, not just whether the shot goes.
- **Take fouls** — `maybeCallNonShootingFoul` now has an intentional-foul
  branch: when the defense is trailing by 1–9 in the final period with ≤45s
  left, foul chance jumps to 35% (65% inside the last 20s). Still routes
  through the existing 1-and-1 / double-bonus logic, so take-fouls correctly
  put trailing-team opponents on the line and stop the clock.

### Full-list pass (this session)

All nine open items from the priority list are now ported. Short notes per
item; browse `GameEngine.swift` for the full implementations.

1. **Full interaction chains** (`zoneDistanceAdvantage`,
   `positionMatchedDefenderIndex`, drive-and-kick on help). Zone schemes now
   tilt shot make probability based on spot; kicked-out receivers are matched
   to a position-appropriate defender. `dribbleDrive` rolls a help-defender
   chance that converts the drive into a kickout via `evaluatePassTarget`.
2. **Full P&R/P&P dynamics** (`chooseScreenNavigation`,
   `resolvePickAndRollOutcome`, `choosePopDestination`). The defender
   picks over/under/switch/ice against each screen; each outcome spawns a
   different `PlayOutcome` (driver finish, roller dunk, pull-up 3,
   post-mismatch, reset). Pick-and-pop compares expected midrange vs
   three value to pick the destination.
3. **Directional rebounds** (`reboundZone`, `positionProximity`,
   extended `pickRebounderIndex`). Each miss maps to a zone by shot+spot;
   rebounder weights multiply a zone bias by positional proximity and an
   opposing-team boxout resistance factor.
4. **Pass delivery** (`resolvePassInterception`). Whenever the shooter
   differs from the ball handler, a per-defender interception roll happens
   up front; success credits the stealer and seeds a steal-source
   transition.
5. **Rotation-target subs** (`computeTargetMinutesMap`,
   `rankSubCandidates`, rewritten `runAutoSubstitutions`). Roster-wide
   ranking by `skill*0.62 + energy*0.3 + rotationNeed*1.9` with forced
   bench on foul trouble (4+ fouls pre-clutch, 5 always), per-team
   25-second sub-cooldown via `lastSubElapsedGameSeconds`.
6. **Fast break + transition window** (`maybeResolveFastBreak`,
   `pickTransitionRunnerIndex`, `pickTransitionPointDefenderIndex`,
   `chooseFastBreakFinish`). `StoredState.pendingTransition` is seeded by
   defensive rebounds and steals; at the top of a chunk the transition
   resolves push → race → finish or reverts to half-court. Made finishes
   return `made_shot`; missed trigger a rebound contest with
   transition-favorable defense rebounding.
7. **Press defense** (`shouldApplyPress`, `maybeResolvePress`). Defense's
   `tendencies.press` or late-game trailing triggers a press roll. Outcomes:
   trap steal (turnover + steal-source transition), survived press break
   that may seed a `press_break`-source transition, or fall-through to
   half-court.
8. **Off-ball relocation** (`evaluatePassTarget`). `passAroundForShot` and
   drive-and-kick both use a scorer that blends expected shot EV, off-ball
   movement vs matched defender, and pass-perception risk.
9. **Foul variety**: offensive charges on drives (via `play.isDrive`),
   loose-ball fouls in rebound contests, and `maybeCallTechnicalFoul`
   firing on dead balls (~0.3% rate; 1 FT awarded to the opposing team's
   best free-throw shooter).

Verification: `swift build`, `swift test` (7/7), and `swift run CBBCoachCLI`
all green. Sample box scores show healthy AST/REB/STL/BLK distribution.
The CLI also prints per-team FG/3PT/AST/REB/STL/BLK/TO/PF totals for
quick hand-eye.

## What still needs to be ported, in priority order

Each item points to the relevant JS line range in `/tmp/jsengine.js`.

### 1. Full interaction chains — HIGH IMPACT (JS 3882–5367)

The current play-type dispatcher is simplified: it picks a shooter and fires a
single shot interaction with per-play edge/make/foul bonuses. The JS version
chains multiple interactions (drive → help defender → pass → shot) with each
stage possibly kicking the ball to another branch. To get there we'd need:

- `assignOffensiveSpots` (JS 853–868) to place each offensive player at a
  spot for the possession
- `getOnBallDefender` (JS 870–903) for proper defender matching by position
- `zoneDistanceAdvantage` (JS 1095–1108) to modify spot shooting efficacy
  based on defense scheme
- Stage-specific `resolveDriveInteraction`, `resolveHelpInteraction`,
  `resolvePostControlInteraction` that each return a branch decision

### 2. Full pick-and-roll/pick-and-pop dynamics (JS 1219–1423)

Current P&R/P&P uses a simplified `screenEffectiveness` helper.
The JS version computes separate `screenProfile`, `ballHandlerAssist`,
`defenseNavigation`, roller/pop threats, and picks a short-roll pass option.
`choosePopDestination` selects elbow vs top-of-key 3 via expected shot value.

### 3. Full directional rebound system (JS 969–1108, 2600–2900)

Current Swift rebounder weights by shot type but doesn't compute a landing
spot. JS `pickReboundDirection`, `buildReboundLandingSpot`,
`resolveBoxoutPositioning`, `collectReboundCandidates` place a coordinate and
pick from candidates within a radius weighted by boxout multipliers.

### 4. Pass delivery chain (JS 1657–1676, 2050–2350)

`resolvePass`, `resolvePassDelivery`, `evaluatePassTarget`. Multi-defender
interception model with wingspan bonus, loose-ball branch. Currently Swift
has no pass resolution — passes are implicit. Would enable realistic
assist-turnover counts and deflection plays.

### 5. Rotation-target-driven substitutions (JS 384–581)

`runAutoSubstitutions` fires on dead balls now, but it still uses a simple
"compare energy + current minutes vs target" heuristic. JS
`getTargetMinutesMap`, `rankLineupCandidates`, `runDeadBallSubstitutions`
build a weighted ranking against coach-preferred rotation patterns, respect
foul trouble (4+ fouls late, 5 = out), and dynamically adjust targets based
on game script.

### 6. Fast break + transition window (JS 2850–3350)

`pickTransitionRunner`, `chooseFastBreakFinishType`, `resolveFastBreakWindow`,
`resolveTransitionMissRebound`. Triggered by `state.pendingTransition` set by
defensive rebounds/steals. Currently every possession is half-court — no
transition bonus for defensive rebound or steal.

### 7. Press defense + backcourt (JS 3350–3742)

`shouldApplyPressThisPossession`, `pickPressTrapDefenders`,
`pickPressReceiver`, `pickPressStealer`,
`resolveBackcourtLooseBallRecovery`, `resolvePressTrapInteraction`,
`resolvePressBreakWindow`. Driven by `team.tendencies.press` and `trapRate`.
Currently no press logic.

### 8. Off-ball movement + open-shot relocation (JS 4920–5200)

`maybeRelocateOffBallPlayers` repositions off-ball offensive players based on
ball position and formation, then `evaluatePassTarget` scores pass options.
Currently `passAroundForShot` just picks the single-best open-shot teammate.

### 9. Non-shooting fouls (more variety)

Current hook only fires on `setup` chunks at a flat 4%. JS has loose-ball
fouls, offensive charges, take fouls late in game (intentional foul when
trailing), and technicals. All currently missing.

## Architectural notes for the follow-up

- `NativeGameStateStore` works fine, but its `activeLineup` uses value copies.
  To match JS "same reference" semantics for `pendingAssist`/`pendingTransition`,
  track players by `(teamId, rosterIndex)` pairs, not by `Player` equality.
- `getRating` already applies fatigue/clutch/coaching/home-court correctly.
  New logic should call `getRating` (not `getBaseRating`) for any computation
  that should respect game state — note that much of the play-type dispatcher
  added this session uses `getBaseRating` for simplicity; upgrading those
  call sites to `getRating` would make fatigue/clutch bite on play selection.
- `condition.possessionRole` is toggled each chunk by `syncPossessionRoles`.
  `condition.clutchTime` is toggled each chunk by `syncClutchTime`.
- The JS engine uses `Map<Player, T>` keyed on object identity for
  involvement/box-score lookups. In Swift use `(teamId, rosterIndex)` tuples
  or small int maps instead — `Player` is a struct and `==` is deep-equal.
- New state fields on `StoredState`:
  - `teamFoulsInHalf: [Int]` — resets each half/OT
  - `formationCycleIndex: [Int]` — rotates through `team.formations`

## Public API that must stay stable

`iOSApp/ContentView.swift` reads `result.boxScore[].players[].*`,
`homeScore`, `awayScore`, `wentToOvertime`, and expects
`SimulatedGameResult.playByPlay` events with `half` set. `LeagueEngine.swift`
calls `simulateGame(homeTeam:awayTeam:random:)`. These shapes must be
preserved.

New event types added this session: `non_shooting_foul`, `bonus_foul`.

## Verification

```sh
swift build
swift test                # 7 smoke tests must pass
swift run CBBCoachCLI     # hand-eye check sim output
```

Box-score sanity targets for a typical game: ~60–80 points/team, roughly
30–40% 3PT, 40–50% overall FG, 8–14 turnovers, 6–12 blocks combined,
non-starters with >0 minutes.
