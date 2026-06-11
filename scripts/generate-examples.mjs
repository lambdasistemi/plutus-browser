import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const repoRoot = process.cwd();
const examplesDir = path.join(repoRoot, "examples");
const outputPath = path.join(repoRoot, "src", "Uplc", "Examples.purs");

const files = readdirSync(examplesDir)
  .filter((file) => file.endsWith(".uplc"))
  .sort((left, right) => left.localeCompare(right));

const encode = (value) => JSON.stringify(value);

const entries = files.map((file) => {
  const name = file.replace(/\.uplc$/, "");
  const program = readFileSync(path.join(examplesDir, file), "utf8");
  return `{ name: ${encode(name)}, program: ${encode(program)} }`;
});

const renderedExamples =
  entries.length === 0
    ? `  []\n`
    : `  [ ${entries[0]}\n` +
      entries
        .slice(1)
        .map((entry) => `  , ${entry}`)
        .join("\n") +
      `\n  ]\n`;

const body =
  `module Uplc.Examples\n` +
  `  ( examples\n` +
  `  ) where\n` +
  `\n` +
  `type Example =\n` +
  `  { name :: String\n` +
  `  , program :: String\n` +
  `  }\n` +
  `\n` +
  `examples :: Array Example\n` +
  `examples =\n` +
  renderedExamples;

mkdirSync(path.dirname(outputPath), { recursive: true });
writeFileSync(outputPath, body);
