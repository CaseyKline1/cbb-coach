const player = require("./player");
const gameEngine = require("./gameEngine");
const coach = require("./coach");

module.exports = {
  ...player,
  ...coach,
  ...gameEngine,
};
