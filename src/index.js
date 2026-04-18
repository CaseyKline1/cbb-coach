const player = require("./player");
const gameEngine = require("./gameEngine");
const coach = require("./coach");
const leagueEngine = require("./leagueEngine");

module.exports = {
  ...player,
  ...coach,
  ...gameEngine,
  ...leagueEngine,
};
