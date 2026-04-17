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

## Quick run

```bash
node src/exampleGame.js
```

## API

Use either `src/gameEngine.js` directly or the barrel export in `src/index.js`.

```js
const { createPlayer, createTeam, simulateGame, OffensiveFormation, DefenseScheme } = require("./src");
```

## Notes for next iteration

- Action selection is intentionally modular in `choosePlayType(...)` so we can add explicit team and lineup decision policy next.
- Press and press-break flow is stubbed by checking `defense.tendencies.press`; detailed press mechanics are still to be defined.
- Rebounding uses a first-pass model for man/zone behavior and can be expanded with explicit boxer/boxed assignments.
