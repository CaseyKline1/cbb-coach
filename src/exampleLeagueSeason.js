const {
  createD1League,
  listUserNonConferenceOptions,
  setUserNonConferenceOpponents,
  generateSeasonSchedule,
  advanceToNextUserGame,
  getUserCompletedGames,
  getLeagueSummary,
} = require("./index");

const league = createD1League({
  userTeamName: "Duke",
  seed: "demo-duke-2026",
});

const summaryBefore = getLeagueSummary(league);
console.log("Initial league summary:", summaryBefore);

const options = listUserNonConferenceOptions(league);
const required = league.userPreseason.requiredNonConferenceGames;
const selected = options.slice(0, required).map((option) => option.teamId);
setUserNonConferenceOpponents(league, selected);

const scheduleMeta = generateSeasonSchedule(league);
console.log("Schedule generated:", scheduleMeta);

for (let i = 0; i < 5; i += 1) {
  const advance = advanceToNextUserGame(league);
  if (advance.done) break;
  const result = `${advance.won ? "W" : "L"} ${advance.score.user}-${advance.score.opponent}`;
  console.log(`Game ${i + 1}: ${advance.isHome ? "vs" : "at"} ${advance.opponentName} (${result})`);
}

const completed = getUserCompletedGames(league);
const last = completed[completed.length - 1];

if (last?.result?.boxScore) {
  const userTeamBox = last.isHome ? last.result.boxScore[0] : last.result.boxScore[1];
  console.log("Most recent detailed box score team total:", {
    team: userTeamBox.name,
    points: last.userScore,
    playersTracked: userTeamBox.players.length,
  });
}
