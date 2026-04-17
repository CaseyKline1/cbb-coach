const player = require("./player");
const gameEngine = require("./gameEngine");

module.exports = {
  ...player,
  ...gameEngine,
};
