const {
  createD1League,
  runPreseasonSchedulingCli,
  generateSeasonSchedule,
  getLeagueSummary,
} = require("./index");

async function main() {
  const userTeamName = process.argv[2] || "Duke";
  const league = createD1League({
    userTeamName,
    seed: process.argv[3] || `preseason-cli-${Date.now()}`,
  });

  console.log("Preseason setup:", getLeagueSummary(league));
  const selection = await runPreseasonSchedulingCli(league);
  console.log("Selection result:", selection);

  if (!selection.completed) {
    console.log("Selection canceled before completion.");
    return;
  }

  const schedule = generateSeasonSchedule(league);
  console.log("Schedule generated:", schedule);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
