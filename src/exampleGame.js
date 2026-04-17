const { createPlayer } = require("./player");
const {
  createTeam,
  simulateGame,
  OffensiveFormation,
  DefenseScheme,
} = require("./gameEngine");

function makePlayer(name, tweaks = {}) {
  const p = createPlayer();
  p.bio.name = name;

  Object.entries(tweaks).forEach(([path, value]) => {
    const [group, key] = path.split(".");
    if (!p[group]) p[group] = {};
    p[group][key] = value;
  });

  return p;
}

const homePlayers = [
  makePlayer("Lead Guard", {
    "skills.ballHandling": 82,
    "skills.passingVision": 78,
    "shooting.threePointShooting": 76,
    "tendencies.drive": 72,
    "tendencies.shootVsPass": 58,
  }),
  makePlayer("Shooter Wing", {
    "shooting.threePointShooting": 84,
    "shooting.upTopThrees": 81,
    "skills.offballOffense": 79,
    "tendencies.threePoint": 82,
  }),
  makePlayer("Slasher Wing", {
    "athleticism.burst": 80,
    "shooting.layups": 77,
    "skills.ballHandling": 74,
    "tendencies.drive": 80,
  }),
  makePlayer("Stretch Four", {
    "shooting.threePointShooting": 75,
    "rebounding.defensiveRebound": 73,
  }),
  makePlayer("Rim Big", {
    "postGame.postControl": 80,
    "postGame.postHooks": 77,
    "rebounding.offensiveRebounding": 82,
    "defense.postDefense": 78,
  }),
];

const awayPlayers = [
  makePlayer("Point Stopper", {
    "defense.perimeterDefense": 82,
    "defense.lateralQuickness": 81,
    "defense.steals": 77,
  }),
  makePlayer("3-and-D Wing", {
    "defense.offballDefense": 79,
    "defense.shotContest": 75,
    "shooting.threePointShooting": 77,
  }),
  makePlayer("Athletic Wing", {
    "athleticism.burst": 79,
    "defense.passPerception": 75,
    "skills.hustle": 80,
  }),
  makePlayer("Mobile Four", {
    "defense.shotContest": 76,
    "rebounding.defensiveRebound": 77,
  }),
  makePlayer("Anchor Five", {
    "defense.postDefense": 83,
    "defense.shotBlocking": 80,
    "rebounding.defensiveRebound": 84,
  }),
];

const home = createTeam({
  name: "Home U",
  lineup: homePlayers,
  formation: OffensiveFormation.FIVE_OUT,
  defenseScheme: DefenseScheme.MAN_TO_MAN,
  tendencies: {
    drive: 1.2,
    post: 0.8,
    ballMovement: 1.15,
    press: 1,
  },
});

const away = createTeam({
  name: "Away State",
  lineup: awayPlayers,
  formation: OffensiveFormation.HIGH_LOW,
  defenseScheme: DefenseScheme.ZONE_2_3,
  tendencies: {
    drive: 0.95,
    post: 1.1,
    ballMovement: 1.0,
    press: 1,
  },
});

const result = simulateGame(home, away);

console.log(`${result.away.name} ${result.away.score} - ${result.home.name} ${result.home.score}`);
console.log(`Winner: ${result.winner || "Tie"}`);
console.log("Recent events:");
result.playByPlay.slice(-10).forEach((event) => {
  console.log(
    `[H${event.half} ${String(event.elapsedSecondsInHalf).padStart(4, "0")}s] ${event.type}`,
  );
});
