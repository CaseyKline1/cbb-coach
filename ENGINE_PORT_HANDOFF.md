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

## What's already restored (commit `4d2b3ad` and earlier)

- `NativeGameStateStore` with handle-based state, multi-team trackers
- `resolveInteraction` with weighted skill scores, mobility-size edge,
  logistic probability (matches JS lines ~729–758)
- `getRating` with fatigue, clutch, coaching, and home-court modifiers
  (JS ~632–665)
- Possession loop, shot-clock tracking, plus-minus, minutes/energy
- Assist picker (simple), rebound picker (simple, not directional), basic
  auto-substitutions, clamp/logistic/average utilities
- Shot-type selection from player tendencies + court spot
  (`chooseShotFromTendencies`, `pickShooterSpot`) covering layup/dunk/hook/
  fadeaway/close/midrange/three
- Shot-type-specific `shotProfile` make probabilities matching JS ranges
- Corner vs up-top 3PT specialty
- Blocks on missed rim attempts
- `applyPreGameModifiers` in LeagueEngine sets `homeCourtMultiplier`,
  `offensiveCoachingModifier`, `defensiveCoachingModifier` on each player
  before sim — so the existing rating pipeline actually uses them

## What still needs to be ported, in priority order

Each item points to the relevant JS line range in `/tmp/jsengine.js`.

### 1. Play-type dispatcher — HIGH IMPACT (JS 1128–1217, 3882–5367)
The core of the JS possession model. `choosePlayType` weighs player tendencies
and team tendencies, then dispatches one of five branches inside
`resolveActionChunk`:
- `dribble_drive` (JS 3971–4250): drive → help defender → pass/shot
- `pick_and_roll` (JS ~4250–4650): screener dynamics, roller shot, ball-
  handler shot, short-roll pass
- `pick_and_pop` (JS ~4650–4920): screener pops to elbow/3, spot selection
- `pass_around_for_shot` (JS ~4920–5200): ball movement, pass receiver
  open-shot evaluation, `maybeRelocateOffBallPlayers`
- `post_up` (JS ~5200–5367): post control interaction, hook/fadeaway/layup/
  dunk shot tiers

Pre-reqs: `assignOffensiveSpots` (JS 853–868), `getOnBallDefender`
(JS 870–903), `zoneDistanceAdvantage` (JS 1095–1108).

### 2. Pick-and-roll / screen dynamics (JS 1219–1423)
`pickScreenerIndex`, `choosePopDestination`, `resolvePickActionDynamics` —
computes screen effectiveness, ball-handler pressure, screener pressure,
drive-focus splits. Needed by the pick_and_roll/pick_and_pop branches.

### 3. Directional rebound system (JS 969–1108, 2600–2900)
`pickReboundDirection`, `buildReboundLandingSpot`, `resolveBoxoutPositioning`,
`collectReboundCandidates`. The current Swift rebounder pick is a simple
weighted draw; the JS version places a landing coordinate based on shot
location + shot type (long rebounds on threes), then picks from candidates
within radius whose boxout multipliers weight the outcome.

### 4. Pass delivery chain (JS 1657–1676, 2050–2350)
`resolvePass`, `resolvePassDelivery`, `evaluatePassTarget`. Multi-defender
interception model with wingspan bonus, loose-ball branch. Currently the
Swift engine has no real pass resolution — passes are implicit in "possession
continues".

### 5. Substitutions with rotation targets + timeouts (JS 384–581)
`getTargetMinutesMap`, `rankLineupCandidates`, `runDeadBallSubstitutions`,
`maybeTakeTimeout`. Existing Swift `runAutoSubstitutions` is minute-/energy-
driven but doesn't respect explicit `team.rotation.minuteTargets`, doesn't
force out fouled-out players at dead balls, and never calls timeouts.
Dead-ball subs should fire on made shots and free throws, not every chunk.

### 6. Fast break + transition window (JS 2850–3350)
`pickTransitionRunner`, `chooseFastBreakFinishType`, `resolveFastBreakWindow`,
`resolveTransitionMissRebound`. Triggered by `state.pendingTransition` set by
defensive rebounds/steals. Currently every possession is half-court.

### 7. Press defense + backcourt (JS 3350–3742)
`shouldApplyPressThisPossession`, `pickPressTrapDefenders`, `pickPressReceiver`,
`pickPressStealer`, `resolveBackcourtLooseBallRecovery`,
`resolvePressTrapInteraction`, `resolvePressBreakWindow`. Driven by
`team.tendencies.press` and `trapRate`. Currently no press logic.

### 8. Clutch sync + energy recovery hooks (JS 205–355)
`syncClutchTimeState` — already effectively in Swift via
`player.condition.clutchTime`, but isn't toggled each chunk based on game
state. `recoverAllPlayers` at halftime/timeout also not wired.

### 9. Formation cycle advance (JS 766–805)
`normalizeFormationCycle`, `advanceTeamOffensiveFormation`,
`getCurrentOffensiveFormation`. Each possession in JS uses the team's current
formation in a cycle; Swift currently ignores `team.formations`.

### 10. Non-shooting fouls + bonus free throws (JS ~1900–2100)
Currently only shooting fouls draw FTs in Swift. JS tracks team fouls per
half and awards bonus FTs on 7+ team fouls.

## Architectural notes for the follow-up

- `NativeGameStateStore` works fine, but its `activeLineup` uses value copies.
  To match JS "same reference" semantics for `pendingAssist`/`pendingTransition`,
  track players by `(teamId, rosterIndex)` pairs, not by `Player` equality.
- `getRating` already applies fatigue/clutch/coaching/home-court correctly.
  New logic should call `getRating` (not `getBaseRating`) for any computation
  that should respect game state.
- `condition.possessionRole` is toggled each chunk by `syncPossessionRoles`.
  Keep this invariant so the coaching modifier hits the right side.
- The JS engine uses `Map<Player, T>` keyed on object identity for
  involvement/box-score lookups. In Swift use `(teamId, rosterIndex)` tuples
  or small int maps instead — `Player` is a struct and `==` is deep-equal.

## Public API that must stay stable

`iOSApp/ContentView.swift` reads `result.boxScore[].players[].*`,
`homeScore`, `awayScore`, `wentToOvertime`, and expects
`SimulatedGameResult.playByPlay` events with `half` set. `LeagueEngine.swift`
calls `simulateGame(homeTeam:awayTeam:random:)`. These shapes must be
preserved.

## Verification

```sh
swift build
swift test                # 7 smoke tests must pass
swift run CBBCoachCLI     # hand-eye check sim output
```

Box-score sanity targets for a typical game: ~60–80 points/team, roughly
30–40% 3PT, 40–50% overall FG, 8–14 turnovers, 6–12 blocks combined,
non-starters with >0 minutes.
