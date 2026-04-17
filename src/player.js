const POSITIONS = ["PG", "SG", "SF", "PF", "C", "CG", "Wing", "F", "Big"];
const YEARS = ["HS", "FR", "SO", "JR", "SR", "Graduated"];

const createPlayer = () => ({
  bio: {
    name: "",
    position: "PG",
    home: "",
    year: "HS",
    redshirtUsed: false,
    potential: 1,
  },

  athleticism: {
    speed: 1,
    agility: 1,
    burst: 1,
    strength: 1,
    vertical: 1,
    stamina: 1,
    durability: 1,
  },

  shooting: {
    layups: 1,
    dunks: 1,
    closeShot: 1,
    midrangeShot: 1,
    threePointShooting: 1,
    cornerThrees: 1,
    upTopThrees: 1,
    drawFoul: 1,
    freeThrows: 1,
  },

  postGame: {
    postControl: 1,
    postFadeaways: 1,
    postHooks: 1,
  },

  skills: {
    ballHandling: 1,
    ballSafety: 1,
    passingAccuracy: 1,
    passingVision: 1,
    passingIQ: 1,
    shotIQ: 1,
    offballOffense: 1,
    hands: 1,
    hustle: 1,
    clutch: 1,
  },

  defense: {
    perimeterDefense: 1,
    postDefense: 1,
    shotBlocking: 1,
    shotContest: 1,
    steals: 1,
    lateralQuickness: 1,
    offballDefense: 1,
    passPerception: 1,
    defensiveControl: 1,
  },

  rebounding: {
    offensiveRebounding: 1,
    defensiveRebound: 1,
    boxouts: 1,
  },

  tendencies: {
    post: 1,
    inside: 1,
    midrange: 1,
    threePoint: 1,
    drive: 1,
    shootVsPass: 1,
  },

  size: {
    height: "",
    weight: "",
    wingspan: "",
  },

  condition: {
    energy: 100,
  },
});

module.exports = {
  POSITIONS,
  YEARS,
  createPlayer,
};
