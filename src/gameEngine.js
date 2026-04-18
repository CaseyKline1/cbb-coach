const path = require("path");
const { loadConcatenatedModule } = require("./utils/loadConcatenatedModule");

module.exports = loadConcatenatedModule({
  fromFile: __filename,
  chunksDir: path.join(__dirname, "gameEngine", "chunks"),
});
