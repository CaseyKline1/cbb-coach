const fs = require("fs");
const path = require("path");
const { createRequire } = require("module");

function loadConcatenatedModule({ fromFile, chunksDir, chunkNames = null }) {
  if (!fromFile || !chunksDir) {
    throw new Error("`fromFile` and `chunksDir` are required.");
  }

  const absoluteChunksDir = path.isAbsolute(chunksDir)
    ? chunksDir
    : path.resolve(path.dirname(fromFile), chunksDir);

  const orderedChunks = Array.isArray(chunkNames) && chunkNames.length
    ? chunkNames
    : fs
        .readdirSync(absoluteChunksDir)
        .filter((name) => name.endsWith(".js"))
        .sort((a, b) => a.localeCompare(b));

  if (!orderedChunks.length) {
    throw new Error(`No chunk files found in ${absoluteChunksDir}`);
  }

  const source = orderedChunks
    .map((name) => fs.readFileSync(path.join(absoluteChunksDir, name), "utf8"))
    .join("\n");

  const moduleShim = { exports: {} };
  const localRequire = createRequire(fromFile);
  const evaluate = new Function("require", "module", "exports", source);
  evaluate(localRequire, moduleShim, moduleShim.exports);

  return moduleShim.exports;
}

module.exports = {
  loadConcatenatedModule,
};
