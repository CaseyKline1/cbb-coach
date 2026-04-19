const COACH_ROLE = Object.freeze({
  HEAD_COACH: "head_coach",
  ASSISTANT: "assistant",
});

const DEFAULT_COACH_SKILLS = Object.freeze({
  recruiting: 50,
  playerDevelopment: 50,
  guardDevelopment: 50,
  wingDevelopment: 50,
  bigDevelopment: 50,
  offensiveCoaching: 50,
  defensiveCoaching: 50,
  fundraising: 50,
  scouting: 50,
  potential: 50,
});

const DEFAULT_PIPELINE_STATE_WEIGHTS = Object.freeze({
  CA: 10,
  TX: 10,
  FL: 8,
  NY: 6,
  NC: 6,
  IL: 6,
  GA: 6,
  PA: 5,
  OH: 5,
  VA: 4,
  NJ: 4,
  MI: 4,
  IN: 4,
  TN: 3,
  AZ: 3,
  WA: 3,
  MO: 3,
  MD: 3,
  AL: 2,
  LA: 2,
  SC: 2,
  KY: 2,
  MS: 1,
  AR: 1,
});

const SCHOOL_KEYWORDS_TO_STATE = Object.freeze({
  Alabama: "AL",
  Arizona: "AZ",
  Arkansas: "AR",
  California: "CA",
  Colorado: "CO",
  Connecticut: "CT",
  Florida: "FL",
  Georgia: "GA",
  Illinois: "IL",
  Indiana: "IN",
  Iowa: "IA",
  Kansas: "KS",
  Kentucky: "KY",
  Louisiana: "LA",
  Maryland: "MD",
  Michigan: "MI",
  Minnesota: "MN",
  Mississippi: "MS",
  Missouri: "MO",
  Nebraska: "NE",
  Nevada: "NV",
  Ohio: "OH",
  Oklahoma: "OK",
  Oregon: "OR",
  Pennsylvania: "PA",
  Tennessee: "TN",
  Texas: "TX",
  Virginia: "VA",
  Washington: "WA",
  Wisconsin: "WI",
  Carolina: "NC",
});

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function randomInt(min, maxInclusive, random = Math.random) {
  return Math.floor(random() * (maxInclusive - min + 1)) + min;
}

function chooseRandom(values, random = Math.random) {
  if (!Array.isArray(values) || values.length === 0) return null;
  return values[Math.floor(random() * values.length)];
}

function weightedRandomFromMap(weightByValue, random = Math.random) {
  const entries = Object.entries(weightByValue).filter(([, weight]) => Number(weight) > 0);
  if (entries.length === 0) return null;
  const total = entries.reduce((sum, [, weight]) => sum + Number(weight), 0);
  let roll = random() * total;
  for (const [value, weight] of entries) {
    roll -= Number(weight);
    if (roll <= 0) return value;
  }
  return entries[entries.length - 1][0];
}

function normalizeSkills(skills = {}, random = Math.random) {
  const normalized = {};
  Object.entries(DEFAULT_COACH_SKILLS).forEach(([key, base]) => {
    const value = Number(skills[key]);
    normalized[key] = Number.isFinite(value) ? clamp(Math.round(value), 1, 100) : clamp(base + randomInt(-20, 20, random), 1, 100);
  });
  return normalized;
}

function inferStateFromSchoolName(schoolName) {
  if (!schoolName || typeof schoolName !== "string") return null;
  const normalized = schoolName.trim();
  if (!normalized) return null;
  const upper = normalized.toUpperCase();
  if (upper.length === 2 && Object.prototype.hasOwnProperty.call(DEFAULT_PIPELINE_STATE_WEIGHTS, upper)) return upper;
  for (const [keyword, state] of Object.entries(SCHOOL_KEYWORDS_TO_STATE)) {
    if (normalized.includes(keyword)) return state;
  }
  return null;
}

function chooseAlmaMater({ almaMater, schoolPool = [], teamName = "", random = Math.random }) {
  if (typeof almaMater === "string" && almaMater.trim()) return almaMater.trim();
  const validPool = Array.isArray(schoolPool)
    ? schoolPool.filter((school) => typeof school === "string" && school.trim())
    : [];
  if (validPool.length > 0) return chooseRandom(validPool, random);
  return teamName || "Independent";
}

function choosePipelineState({
  almaMater,
  almaMaterState,
  pipelineState,
  pipelineStateWeights = DEFAULT_PIPELINE_STATE_WEIGHTS,
  random = Math.random,
}) {
  if (typeof pipelineState === "string" && pipelineState.trim()) return pipelineState.trim().toUpperCase();
  const inferredAlmaState = almaMaterState || inferStateFromSchoolName(almaMater);
  const overlapChance = inferredAlmaState ? 0.45 : 0;
  if (inferredAlmaState && random() < overlapChance) return inferredAlmaState;
  return weightedRandomFromMap(pipelineStateWeights, random) || "CA";
}

function createCoach({
  role = COACH_ROLE.ASSISTANT,
  age,
  pressAggressiveness,
  pace = "normal",
  defaultOffensiveSet = "motion",
  defaultDefensiveSet = "man_to_man",
  almaMater,
  schoolPool = [],
  teamName = "",
  almaMaterState,
  pipelineState,
  pipelineStateWeights = DEFAULT_PIPELINE_STATE_WEIGHTS,
  skills = {},
  focus,
  random = Math.random,
} = {}) {
  const resolvedAlmaMater = chooseAlmaMater({ almaMater, schoolPool, teamName, random });
  const resolvedFocus = typeof focus === "string" && focus.trim() ? focus.trim() : role === COACH_ROLE.ASSISTANT ? "recruiting" : null;
  return {
    role,
    focus: resolvedFocus,
    age: Number.isFinite(Number(age)) ? clamp(Math.round(Number(age)), 24, 80) : randomInt(31, 69, random),
    pressAggressiveness: Number.isFinite(Number(pressAggressiveness))
      ? clamp(Math.round(Number(pressAggressiveness)), 1, 100)
      : randomInt(25, 90, random),
    pace,
    defaultOffensiveSet,
    defaultDefensiveSet,
    almaMater: resolvedAlmaMater,
    pipelineState: choosePipelineState({
      almaMater: resolvedAlmaMater,
      almaMaterState,
      pipelineState,
      pipelineStateWeights,
      random,
    }),
    skills: normalizeSkills(skills, random),
  };
}

function createCoachingStaff({
  headCoach = null,
  assistants = [],
  gamePrepAssistantIndex = null,
  schoolPool = [],
  teamName = "",
  defaultPace = "normal",
  defaultOffensiveSet = "motion",
  defaultDefensiveSet = "man_to_man",
  pipelineStateWeights = DEFAULT_PIPELINE_STATE_WEIGHTS,
  random = Math.random,
} = {}) {
  const generatedHead = createCoach({
    role: COACH_ROLE.HEAD_COACH,
    schoolPool,
    teamName,
    pace: defaultPace,
    defaultOffensiveSet,
    defaultDefensiveSet,
    pipelineStateWeights,
    random,
    ...(headCoach || {}),
  });

  const assistantSeed = Array.isArray(assistants) ? assistants.slice(0, 4) : [];
  while (assistantSeed.length < 4) assistantSeed.push({});
  const generatedAssistants = assistantSeed.map((assistant) =>
    createCoach({
      role: COACH_ROLE.ASSISTANT,
      schoolPool,
      teamName,
      pace: defaultPace,
      defaultOffensiveSet,
      defaultDefensiveSet,
      pipelineStateWeights,
      random,
      ...(assistant || {}),
    }),
  );

  const numericGamePrepIndex = Number(gamePrepAssistantIndex);
  const resolvedGamePrepAssistantIndex =
    Number.isInteger(numericGamePrepIndex) &&
    numericGamePrepIndex >= 0 &&
    numericGamePrepIndex < generatedAssistants.length
      ? numericGamePrepIndex
      : null;

  return {
    headCoach: generatedHead,
    assistants: generatedAssistants,
    gamePrepAssistantIndex: resolvedGamePrepAssistantIndex,
    coaches: [generatedHead, ...generatedAssistants],
  };
}

module.exports = {
  COACH_ROLE,
  DEFAULT_COACH_SKILLS,
  DEFAULT_PIPELINE_STATE_WEIGHTS,
  createCoach,
  createCoachingStaff,
};
