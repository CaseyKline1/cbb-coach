const { createPlayer } = require("./player");
const {
  createTeam,
  simulateGame,
  OffensiveFormation,
  DefenseScheme,
  PaceProfile,
} = require("./gameEngine");
const ALL_FORMATIONS = Object.values(OffensiveFormation);

function seededRandom(seed) {
  let state = seed >>> 0;
  return () => {
    state = (1664525 * state + 1013904223) >>> 0;
    return state / 4294967296;
  };
}

function hashString(input) {
  let h = 2166136261;
  for (let i = 0; i < input.length; i += 1) {
    h ^= input.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

const BASE_RATINGS = {
  athleticism: {
    speed: 63,
    agility: 62,
    burst: 61,
    strength: 60,
    vertical: 61,
    stamina: 66,
    durability: 65,
  },
  shooting: {
    layups: 62,
    dunks: 56,
    closeShot: 62,
    midrangeShot: 60,
    threePointShooting: 58,
    cornerThrees: 58,
    upTopThrees: 57,
    drawFoul: 60,
    freeThrows: 66,
  },
  postGame: {
    postControl: 55,
    postFadeaways: 54,
    postHooks: 54,
  },
  skills: {
    ballHandling: 60,
    ballSafety: 60,
    passingAccuracy: 60,
    passingVision: 59,
    passingIQ: 60,
    shotIQ: 60,
    offballOffense: 60,
    hands: 61,
    hustle: 62,
    clutch: 58,
  },
  defense: {
    perimeterDefense: 61,
    postDefense: 58,
    shotBlocking: 56,
    shotContest: 60,
    steals: 58,
    lateralQuickness: 60,
    offballDefense: 60,
    passPerception: 60,
    defensiveControl: 60,
  },
  rebounding: {
    offensiveRebounding: 58,
    defensiveRebound: 60,
    boxouts: 60,
  },
  tendencies: {
    post: 50,
    inside: 52,
    midrange: 50,
    threePoint: 50,
    drive: 52,
    pickAndRoll: 50,
    pickAndPop: 50,
    shootVsPass: 50,
  },
};

const POSITION_ADJUSTMENTS = {
  PG: {
    "athleticism.speed": 8,
    "athleticism.agility": 8,
    "athleticism.burst": 6,
    "skills.ballHandling": 14,
    "skills.ballSafety": 10,
    "skills.passingAccuracy": 13,
    "skills.passingVision": 14,
    "skills.passingIQ": 10,
    "defense.perimeterDefense": 5,
    "defense.lateralQuickness": 7,
    "defense.steals": 6,
    "postGame.postControl": -8,
    "postGame.postHooks": -8,
    "rebounding.offensiveRebounding": -8,
    "rebounding.defensiveRebound": -8,
    "tendencies.drive": 8,
    "tendencies.pickAndRoll": 10,
    "tendencies.pickAndPop": 4,
    "tendencies.post": -12,
  },
  SG: {
    "shooting.threePointShooting": 10,
    "shooting.cornerThrees": 9,
    "shooting.upTopThrees": 10,
    "shooting.midrangeShot": 6,
    "skills.offballOffense": 8,
    "defense.perimeterDefense": 5,
    "defense.shotContest": 4,
    "postGame.postControl": -6,
    "postGame.postHooks": -6,
    "tendencies.threePoint": 10,
    "tendencies.pickAndPop": 8,
    "tendencies.post": -10,
  },
  SF: {
    "athleticism.strength": 4,
    "shooting.layups": 6,
    "shooting.midrangeShot": 5,
    "skills.offballOffense": 6,
    "defense.perimeterDefense": 5,
    "defense.offballDefense": 6,
    "rebounding.defensiveRebound": 4,
    "tendencies.inside": 4,
    "tendencies.drive": 4,
    "tendencies.pickAndRoll": 3,
    "tendencies.pickAndPop": 4,
  },
  PF: {
    "athleticism.strength": 8,
    "shooting.closeShot": 8,
    "postGame.postControl": 11,
    "postGame.postFadeaways": 6,
    "postGame.postHooks": 9,
    "defense.postDefense": 9,
    "defense.shotBlocking": 6,
    "rebounding.offensiveRebounding": 9,
    "rebounding.defensiveRebound": 9,
    "rebounding.boxouts": 9,
    "tendencies.post": 14,
    "tendencies.pickAndRoll": 6,
    "tendencies.pickAndPop": 2,
    "tendencies.threePoint": -8,
  },
  C: {
    "athleticism.strength": 12,
    "athleticism.vertical": 5,
    "shooting.closeShot": 10,
    "shooting.threePointShooting": -10,
    "postGame.postControl": 14,
    "postGame.postHooks": 13,
    "postGame.postFadeaways": 7,
    "defense.postDefense": 12,
    "defense.shotBlocking": 12,
    "defense.perimeterDefense": -8,
    "rebounding.offensiveRebounding": 13,
    "rebounding.defensiveRebound": 13,
    "rebounding.boxouts": 12,
    "tendencies.post": 16,
    "tendencies.pickAndRoll": 8,
    "tendencies.pickAndPop": -6,
    "tendencies.threePoint": -12,
    "tendencies.drive": -10,
  },
  CG: {
    "athleticism.speed": 6,
    "athleticism.agility": 6,
    "skills.ballHandling": 10,
    "skills.passingAccuracy": 8,
    "skills.passingVision": 8,
    "shooting.threePointShooting": 7,
    "shooting.upTopThrees": 6,
    "defense.perimeterDefense": 4,
    "defense.lateralQuickness": 5,
    "postGame.postControl": -7,
    "tendencies.drive": 6,
    "tendencies.pickAndRoll": 8,
    "tendencies.pickAndPop": 5,
    "tendencies.post": -10,
  },
  Wing: {
    "athleticism.speed": 4,
    "athleticism.agility": 4,
    "shooting.threePointShooting": 8,
    "shooting.cornerThrees": 9,
    "skills.offballOffense": 8,
    "defense.perimeterDefense": 6,
    "defense.offballDefense": 7,
    "rebounding.defensiveRebound": 4,
    "tendencies.threePoint": 8,
    "tendencies.pickAndPop": 7,
    "tendencies.post": -8,
  },
  F: {
    "athleticism.strength": 6,
    "shooting.closeShot": 6,
    "shooting.midrangeShot": 5,
    "postGame.postControl": 7,
    "postGame.postFadeaways": 5,
    "defense.postDefense": 7,
    "defense.shotContest": 5,
    "rebounding.offensiveRebounding": 7,
    "rebounding.defensiveRebound": 8,
    "rebounding.boxouts": 8,
    "tendencies.pickAndRoll": 5,
    "tendencies.pickAndPop": 2,
    "tendencies.post": 8,
  },
  Big: {
    "athleticism.strength": 10,
    "shooting.closeShot": 8,
    "postGame.postControl": 12,
    "postGame.postHooks": 10,
    "defense.postDefense": 10,
    "defense.shotBlocking": 9,
    "rebounding.offensiveRebounding": 11,
    "rebounding.defensiveRebound": 11,
    "rebounding.boxouts": 10,
    "tendencies.pickAndRoll": 7,
    "tendencies.pickAndPop": -6,
    "tendencies.post": 14,
    "tendencies.threePoint": -10,
  },
};

function applyReasonableBaseline(player, name, position) {
  const adjustments = POSITION_ADJUSTMENTS[position] || {};
  const random = seededRandom(hashString(`${name}:${position}`));

  Object.entries(BASE_RATINGS).forEach(([group, ratings]) => {
    Object.entries(ratings).forEach(([key, baseValue]) => {
      const path = `${group}.${key}`;
      const posAdjust = adjustments[path] || 0;
      const jitter = Math.round((random() - 0.5) * 8);
      const min = group === "tendencies" ? 20 : 40;
      const max = group === "tendencies" ? 95 : 92;
      player[group][key] = clamp(baseValue + posAdjust + jitter, min, max);
    });
  });
}

function makePlayer(name, position, size, tweaks = {}) {
  const p = createPlayer();
  p.bio.name = name;
  p.bio.position = position;
  p.size.height = size.height;
  p.size.weight = size.weight;
  p.size.wingspan = size.wingspan;
  applyReasonableBaseline(p, name, position);

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
