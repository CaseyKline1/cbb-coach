const { createPlayer } = require("./player");
const {
  createTeam,
  simulateGame,
  OffensiveFormation,
  DefenseScheme,
} = require("./gameEngine");

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function makePlayer(name, position, size, tweaks = {}) {
  const p = createPlayer();
  p.bio.name = name;
  p.bio.position = position;
  p.size.height = size.height;
  p.size.weight = size.weight;
  p.size.wingspan = size.wingspan;

  Object.entries(tweaks).forEach(([path, value]) => {
    const [group, key] = path.split(".");
    if (!p[group]) p[group] = {};
    p[group][key] = value;
  });

  return p;
}

function formatPct(made, attempts) {
  if (!attempts) return "0.0%";
  return `${((made / attempts) * 100).toFixed(1)}%`;
}

function pad(value, width) {
  return String(value).padStart(width, " ");
}

function summarizeTeam(teamBox) {
  const total = {
    points: 0,
    fgMade: 0,
    fgAttempts: 0,
    threeMade: 0,
    threeAttempts: 0,
    ftMade: 0,
    ftAttempts: 0,
    offensiveRebounds: 0,
    defensiveRebounds: 0,
    rebounds: 0,
    assists: 0,
    steals: 0,
    blocks: 0,
    turnovers: teamBox.teamExtras.turnovers || 0,
    fouls: 0,
  };

  teamBox.players.forEach((p) => {
    total.points += p.points;
    total.fgMade += p.fgMade;
    total.fgAttempts += p.fgAttempts;
    total.threeMade += p.threeMade;
    total.threeAttempts += p.threeAttempts;
    total.ftMade += p.ftMade;
    total.ftAttempts += p.ftAttempts;
    total.offensiveRebounds += p.offensiveRebounds;
    total.defensiveRebounds += p.defensiveRebounds;
    total.rebounds += p.rebounds;
    total.assists += p.assists;
    total.steals += p.steals;
    total.blocks += p.blocks;
    total.turnovers += p.turnovers;
    total.fouls += p.fouls;
  });

  return total;
}

function printTeamBoxScore(teamName, teamBox) {
  const widths = {
    player: 18,
    pos: 4,
    min: 3,
    pts: 3,
    fg: 6,
    three: 6,
    ft: 6,
    oreb: 4,
    dreb: 4,
    reb: 3,
    ast: 3,
    stl: 3,
    blk: 3,
    to: 3,
    pf: 3,
  };
  const fmtRow = (row) =>
    [
      String(row.player).padEnd(widths.player, " "),
      String(row.pos).padEnd(widths.pos, " "),
      pad(row.min, widths.min),
      pad(row.pts, widths.pts),
      pad(row.fg, widths.fg),
      pad(row.three, widths.three),
      pad(row.ft, widths.ft),
      pad(row.oreb, widths.oreb),
      pad(row.dreb, widths.dreb),
      pad(row.reb, widths.reb),
      pad(row.ast, widths.ast),
      pad(row.stl, widths.stl),
      pad(row.blk, widths.blk),
      pad(row.to, widths.to),
      pad(row.pf, widths.pf),
    ].join(" | ");

  const header = fmtRow({
    player: "PLAYER",
    pos: "POS",
    min: "MIN",
    pts: "PTS",
    fg: "FG",
    three: "3PT",
    ft: "FT",
    oreb: "OREB",
    dreb: "DREB",
    reb: "REB",
    ast: "AST",
    stl: "STL",
    blk: "BLK",
    to: "TO",
    pf: "PF",
  });
  console.log(`\n${teamName}`);
  console.log(header);
  console.log("-".repeat(header.length));

  teamBox.players.forEach((p) => {
    const displayMinutes = Math.round(Number(p.minutes) || 0);
    const fg = `${p.fgMade}-${p.fgAttempts}`;
    const three = `${p.threeMade}-${p.threeAttempts}`;
    const ft = `${p.ftMade}-${p.ftAttempts}`;
    console.log(
      fmtRow({
        player: p.playerName.slice(0, widths.player),
        pos: p.position.slice(0, widths.pos),
        min: displayMinutes,
        pts: p.points,
        fg,
        three,
        ft,
        oreb: p.offensiveRebounds,
        dreb: p.defensiveRebounds,
        reb: p.rebounds,
        ast: p.assists,
        stl: p.steals,
        blk: p.blocks,
        to: p.turnovers,
        pf: p.fouls,
      }),
    );
  });

  const total = summarizeTeam(teamBox);
  console.log("-".repeat(header.length));
  console.log(
    fmtRow({
      player: "TEAM TOTALS",
      pos: "---",
      min: "---",
      pts: total.points,
      fg: `${total.fgMade}-${total.fgAttempts}`,
      three: `${total.threeMade}-${total.threeAttempts}`,
      ft: `${total.ftMade}-${total.ftAttempts}`,
      oreb: total.offensiveRebounds,
      dreb: total.defensiveRebounds,
      reb: total.rebounds,
      ast: total.assists,
      stl: total.steals,
      blk: total.blocks,
      to: total.turnovers,
      pf: total.fouls,
    }),
  );
  console.log(
    `Shooting splits: FG ${formatPct(total.fgMade, total.fgAttempts)}, 3PT ${formatPct(total.threeMade, total.threeAttempts)}, FT ${formatPct(total.ftMade, total.ftAttempts)}`,
  );
}

const ridgeCityPlayers = [
  makePlayer("Jalen Price", "PG", { height: "6-2", weight: 188, wingspan: "6-5" }, {
    "athleticism.speed": 86,
    "athleticism.agility": 84,
    "skills.ballHandling": 88,
    "skills.passingVision": 84,
    "skills.passingAccuracy": 82,
    "shooting.threePointShooting": 79,
    "shooting.freeThrows": 82,
    "tendencies.drive": 78,
    "tendencies.shootVsPass": 48,
  }),
  makePlayer("Milo Grant", "SG", { height: "6-5", weight: 200, wingspan: "6-8" }, {
    "shooting.threePointShooting": 86,
    "shooting.upTopThrees": 84,
    "shooting.freeThrows": 88,
    "skills.offballOffense": 83,
    "defense.shotContest": 71,
    "tendencies.threePoint": 86,
  }),
  makePlayer("Noah Banks", "SF", { height: "6-7", weight: 212, wingspan: "6-10" }, {
    "athleticism.burst": 84,
    "shooting.layups": 80,
    "shooting.midrangeShot": 73,
    "defense.perimeterDefense": 77,
    "defense.offballDefense": 79,
    "skills.hustle": 82,
    "tendencies.drive": 81,
  }),
  makePlayer("Dre Coleman", "PF", { height: "6-9", weight: 234, wingspan: "7-1" }, {
    "postGame.postControl": 78,
    "postGame.postFadeaways": 72,
    "rebounding.defensiveRebound": 81,
    "rebounding.boxouts": 79,
    "defense.postDefense": 76,
    "shooting.closeShot": 75,
  }),
  makePlayer("Tariq Mason", "C", { height: "7-0", weight: 252, wingspan: "7-4" }, {
    "postGame.postControl": 84,
    "postGame.postHooks": 80,
    "rebounding.offensiveRebounding": 86,
    "rebounding.defensiveRebound": 84,
    "defense.shotBlocking": 83,
    "defense.postDefense": 82,
    "shooting.closeShot": 78,
    "shooting.freeThrows": 69,
  }),
  makePlayer("Aiden Cross", "G", { height: "6-3", weight: 192, wingspan: "6-6" }, {
    "athleticism.speed": 82,
    "skills.ballHandling": 80,
    "skills.passingVision": 76,
    "shooting.threePointShooting": 75,
    "defense.perimeterDefense": 74,
    "skills.hustle": 79,
  }),
  makePlayer("Cal Wright", "Wing", { height: "6-6", weight: 208, wingspan: "6-9" }, {
    "shooting.threePointShooting": 78,
    "shooting.upTopThrees": 77,
    "defense.offballDefense": 76,
    "defense.shotContest": 75,
    "skills.offballOffense": 77,
  }),
  makePlayer("Jace Holloway", "F", { height: "6-8", weight: 224, wingspan: "7-0" }, {
    "shooting.midrangeShot": 74,
    "shooting.closeShot": 74,
    "rebounding.defensiveRebound": 76,
    "defense.postDefense": 75,
    "skills.hustle": 80,
  }),
  makePlayer("Brandon Fisk", "Big", { height: "6-10", weight: 245, wingspan: "7-3" }, {
    "postGame.postControl": 76,
    "postGame.postHooks": 73,
    "rebounding.offensiveRebounding": 80,
    "rebounding.boxouts": 78,
    "defense.shotBlocking": 77,
  }),
  makePlayer("Luca Meyer", "CG", { height: "6-4", weight: 196, wingspan: "6-7" }, {
    "skills.ballHandling": 79,
    "skills.passingIQ": 77,
    "shooting.threePointShooting": 77,
    "shooting.freeThrows": 81,
    "defense.perimeterDefense": 73,
  }),
];

const harborTechPlayers = [
  makePlayer("Evan Cole", "PG", { height: "6-1", weight: 182, wingspan: "6-4" }, {
    "athleticism.speed": 85,
    "defense.perimeterDefense": 82,
    "defense.steals": 81,
    "skills.ballHandling": 81,
    "skills.passingVision": 79,
    "shooting.threePointShooting": 74,
    "tendencies.drive": 76,
    "tendencies.shootVsPass": 54,
  }),
  makePlayer("Kobe Ramsey", "SG", { height: "6-4", weight: 198, wingspan: "6-7" }, {
    "shooting.threePointShooting": 81,
    "shooting.upTopThrees": 79,
    "defense.shotContest": 77,
    "defense.offballDefense": 80,
    "skills.offballOffense": 78,
    "tendencies.threePoint": 82,
  }),
  makePlayer("Roman Scott", "SF", { height: "6-8", weight: 220, wingspan: "6-11" }, {
    "athleticism.burst": 82,
    "athleticism.strength": 77,
    "shooting.layups": 79,
    "defense.perimeterDefense": 78,
    "defense.passPerception": 76,
    "skills.hustle": 81,
  }),
  makePlayer("Cam Fuller", "PF", { height: "6-9", weight: 238, wingspan: "7-1" }, {
    "postGame.postControl": 80,
    "postGame.postHooks": 76,
    "rebounding.defensiveRebound": 82,
    "rebounding.boxouts": 80,
    "defense.postDefense": 79,
    "defense.shotContest": 74,
  }),
  makePlayer("Leo Patterson", "C", { height: "7-1", weight: 258, wingspan: "7-5" }, {
    "postGame.postControl": 83,
    "postGame.postHooks": 78,
    "rebounding.offensiveRebounding": 84,
    "rebounding.defensiveRebound": 86,
    "defense.shotBlocking": 85,
    "defense.postDefense": 84,
    "shooting.closeShot": 76,
    "shooting.freeThrows": 66,
  }),
  makePlayer("Ty Reese", "G", { height: "6-2", weight: 187, wingspan: "6-5" }, {
    "athleticism.speed": 83,
    "skills.ballHandling": 80,
    "skills.passingVision": 77,
    "shooting.threePointShooting": 76,
    "defense.steals": 75,
  }),
  makePlayer("Darius Kent", "Wing", { height: "6-6", weight: 210, wingspan: "6-10" }, {
    "shooting.threePointShooting": 79,
    "shooting.cornerThrees": 81,
    "defense.offballDefense": 77,
    "skills.offballOffense": 76,
    "skills.hustle": 79,
  }),
  makePlayer("Owen Blake", "F", { height: "6-8", weight: 228, wingspan: "7-0" }, {
    "postGame.postFadeaways": 74,
    "shooting.midrangeShot": 72,
    "rebounding.defensiveRebound": 78,
    "defense.postDefense": 76,
    "defense.shotContest": 75,
  }),
  makePlayer("Quentin Hale", "Big", { height: "6-11", weight: 248, wingspan: "7-3" }, {
    "postGame.postControl": 78,
    "rebounding.offensiveRebounding": 82,
    "rebounding.boxouts": 79,
    "defense.shotBlocking": 79,
    "defense.postDefense": 78,
  }),
  makePlayer("Nico Vega", "CG", { height: "6-4", weight: 194, wingspan: "6-8" }, {
    "skills.ballHandling": 78,
    "skills.passingAccuracy": 77,
    "shooting.threePointShooting": 78,
    "shooting.freeThrows": 80,
    "defense.perimeterDefense": 74,
  }),
];

const home = createTeam({
  name: "Ridge City Ravens",
  players: ridgeCityPlayers,
  lineup: ridgeCityPlayers.slice(0, 5),
  formation: OffensiveFormation.FIVE_OUT,
  defenseScheme: DefenseScheme.MAN_TO_MAN,
  tendencies: {
    drive: 1.15,
    post: 0.95,
    ballMovement: 1.12,
    press: 1,
  },
  rotation: {
    minuteTargets: {
      "Jalen Price": 31,
      "Milo Grant": 30,
      "Noah Banks": 28,
      "Dre Coleman": 27,
      "Tariq Mason": 26,
      "Aiden Cross": 13,
      "Cal Wright": 14,
      "Jace Holloway": 11,
      "Brandon Fisk": 10,
      "Luca Meyer": 10,
    },
  },
});

const away = createTeam({
  name: "Harbor Tech Tritons",
  players: harborTechPlayers,
  lineup: harborTechPlayers.slice(0, 5),
  formation: OffensiveFormation.HIGH_LOW,
  defenseScheme: DefenseScheme.ZONE_2_3,
  tendencies: {
    drive: 0.98,
    post: 1.08,
    ballMovement: 1.04,
    press: 1,
  },
  rotation: {
    minuteTargets: {
      "Evan Cole": 30,
      "Kobe Ramsey": 29,
      "Roman Scott": 28,
      "Cam Fuller": 27,
      "Leo Patterson": 27,
      "Ty Reese": 12,
      "Darius Kent": 13,
      "Owen Blake": 11,
      "Quentin Hale": 12,
      "Nico Vega": 11,
    },
  },
});

const result = simulateGame(home, away, {
  random: seededRandom(20260417),
});

console.log(`${result.away.name} ${result.away.score} - ${result.home.name} ${result.home.score}`);
console.log(`Winner: ${result.winner || "Tie"}`);

printTeamBoxScore(result.away.name, result.away.boxScore);
printTeamBoxScore(result.home.name, result.home.boxScore);
