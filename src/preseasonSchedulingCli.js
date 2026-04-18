const readline = require("readline");
const {
  getPreseasonSchedulingBoard,
  setUserNonConferenceOpponents,
  autoFillUserNonConferenceOpponents,
} = require("./leagueEngine");

function buildSelectedSummary(board) {
  if (!board.selectedOpponents.length) return "none";
  return board.selectedOpponents
    .slice(0, 8)
    .map((team) => `${team.teamName} (${team.overall})`)
    .join(", ");
}

function renderBoard(output, league, board) {
  const userTeamName = league.teams.byId[league.userTeamId].name;
  output.write("\n=== Preseason Non-Conference Scheduler ===\n");
  output.write(`Team: ${userTeamName}\n`);
  output.write(
    `Selected: ${board.selectedCount}/${board.requiredCount} (${board.remainingCount} remaining)\n`,
  );
  output.write(`Search: ${board.search || "(none)"} | Page ${board.page}/${board.totalPages}\n`);
  output.write(`Current selections: ${buildSelectedSummary(board)}\n\n`);

  if (!board.options.length) {
    output.write("No teams match the current search filter.\n");
  } else {
    board.options.forEach((option) => {
      const marker = option.selected ? "x" : " ";
      output.write(
        `${String(option.displayIndex).padStart(2, " ")}. [${marker}] ${option.teamName} ` +
          `(${option.conferenceName}, OVR ${option.overall})\n`,
      );
    });
  }

  output.write(
    "\nCommands: <number> toggle, n next, p prev, /text search, clear, auto, done, help, quit\n",
  );
}

function findOptionByIndex(board, token) {
  const numeric = Number(token);
  if (!Number.isInteger(numeric)) return null;
  return board.options.find((option) => option.displayIndex === numeric) || null;
}

function toggleSelection(league, option, output) {
  const existing = new Set(league.userPreseason.nonConferenceOpponentIds);
  if (existing.has(option.teamId)) {
    existing.delete(option.teamId);
  } else {
    if (existing.size >= league.userPreseason.requiredNonConferenceGames) {
      output.write(
        `Selection is full (${league.userPreseason.requiredNonConferenceGames}). Remove one first or use auto.\n`,
      );
      return;
    }
    existing.add(option.teamId);
  }

  setUserNonConferenceOpponents(league, [...existing]);
}

async function runPreseasonSchedulingCli(league, options = {}) {
  if (league.status !== "preseason_nonconference") {
    throw new Error("Preseason scheduling CLI can only run before the season starts.");
  }

  const input = options.input || process.stdin;
  const output = options.output || process.stdout;
  const pageSize =
    Number.isFinite(Number(options.pageSize)) && Number(options.pageSize) > 0
      ? Math.round(Number(options.pageSize))
      : 20;

  const rl = readline.createInterface({
    input,
    output,
    terminal: options.terminal ?? Boolean(output.isTTY),
  });

  let page = 1;
  let search = "";

  try {
    const lines = rl[Symbol.asyncIterator]();
    while (true) {
      const board = getPreseasonSchedulingBoard(league, { page, pageSize, search });
      page = board.page;
      renderBoard(output, league, board);
      output.write("preseason> ");

      const next = await lines.next();
      if (next.done) {
        return {
          completed: false,
          selectedOpponentIds: league.userPreseason.nonConferenceOpponentIds.slice(),
          selectedCount: league.userPreseason.nonConferenceOpponentIds.length,
          requiredCount: league.userPreseason.requiredNonConferenceGames,
        };
      }

      const command = String(next.value || "").trim();
      if (!command) continue;

      if (command === "help" || command === "?") {
        output.write(
          "Use a listed number to add/remove that team. Use /text to filter by team, conference, or id.\n",
        );
        continue;
      }

      if (command === "n" || command === "next") {
        page = Math.min(board.totalPages, board.page + 1);
        continue;
      }

      if (command === "p" || command === "prev") {
        page = Math.max(1, board.page - 1);
        continue;
      }

      if (command.startsWith("/")) {
        search = command.slice(1).trim();
        page = 1;
        continue;
      }

      if (command === "clear") {
        search = "";
        page = 1;
        continue;
      }

      if (command === "auto") {
        autoFillUserNonConferenceOpponents(league);
        continue;
      }

      if (command === "done") {
        const summary = setUserNonConferenceOpponents(league, league.userPreseason.nonConferenceOpponentIds);
        if (!summary.complete) {
          output.write(`Need ${summary.requiredCount - summary.selectedCount} more opponents before continuing.\n`);
          continue;
        }

        return {
          completed: true,
          selectedOpponentIds: league.userPreseason.nonConferenceOpponentIds.slice(),
          selectedCount: summary.selectedCount,
          requiredCount: summary.requiredCount,
        };
      }

      if (command === "quit" || command === "q" || command === "exit") {
        return {
          completed: false,
          selectedOpponentIds: league.userPreseason.nonConferenceOpponentIds.slice(),
          selectedCount: league.userPreseason.nonConferenceOpponentIds.length,
          requiredCount: league.userPreseason.requiredNonConferenceGames,
        };
      }

      const option = findOptionByIndex(board, command);
      if (option) {
        toggleSelection(league, option, output);
        continue;
      }

      output.write(`Unknown command: "${command}". Type "help" for commands.\n`);
    }
  } finally {
    rl.close();
  }
}

module.exports = {
  runPreseasonSchedulingCli,
};
