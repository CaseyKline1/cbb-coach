const {
  createD1League,
  autoFillUserNonConferenceOpponents,
  generateSeasonSchedule,
  advanceToNextUserGame,
  getLeagueSummary,
  saveLeagueState,
  loadLeagueState,
} = require("./index");

const SAVE_PATH = "./tmp/demo-league-state.json";

const league = createD1League({
  userTeamName: "Duke",
  seed: "persistence-demo-2026",
});

autoFillUserNonConferenceOpponents(league);
generateSeasonSchedule(league);

for (let i = 0; i < 3; i += 1) {
  const game = advanceToNextUserGame(league);
  if (game.done) break;
}

const saveMeta = saveLeagueState(league, SAVE_PATH);
console.log("Saved:", saveMeta);
console.log("Summary before load:", getLeagueSummary(league));

const loadedLeague = loadLeagueState(SAVE_PATH);
console.log("Summary after load:", getLeagueSummary(loadedLeague));

const nextGame = advanceToNextUserGame(loadedLeague);
console.log("Next game after reloading:", {
  done: nextGame.done,
  day: nextGame.day,
  opponent: nextGame.opponentName,
  score: nextGame.score,
});
