import { expect, test } from "@playwright/test";

const addIntegerProgram =
  "(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])";

const subtractProgram =
  "(program 1.0.0 [ [ (builtin subtractInteger) (con integer 50) ] (con integer 8) ])";

const multiplyProgram =
  "(program 1.0.0 [ [ (builtin multiplyInteger) (con integer 6) ] (con integer 7) ])";

const escapeRegExp = (value) =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

async function waitForSnippetStore(page) {
  await expect(page.getByRole("button", { name: "New snippet" })).toBeEnabled();
  await expect(page.getByRole("button", { name: /^Example\b/ })).toBeVisible();
}

async function createEmptySnippet(page, name) {
  await page.getByRole("button", { name: "New snippet" }).click();
  await page.getByLabel("Snippet name").fill(name);
  await page.getByRole("button", { name: "Create" }).click();
  await expect(page.getByRole("button", { name: new RegExp(`^${escapeRegExp(name)}\\b`) })).toBeVisible();
}

async function waitForEditCommit(page, name) {
  await expect(
    page.getByRole("button", { name: new RegExp(`edit ${escapeRegExp(name)}`) }),
  ).toBeVisible({ timeout: 8_000 });
}

test("evaluates UPLC with the browser WASI CEK", async ({ page }) => {
  await page.goto("/");
  await waitForSnippetStore(page);

  const evalDelay = page.getByLabel("auto evaluate debounce milliseconds");
  await expect(evalDelay).toHaveValue("350");
  await evalDelay.fill("100");
  await expect(evalDelay).toHaveValue("100");

  await page.getByLabel("UPLC program").fill(addIntegerProgram);
  await page.getByRole("button", { name: "Evaluate" }).click();

  const output = page.locator("#output");
  await expect(output).toContainText("(con integer 42)");

  await page.getByLabel("show budget (-c)").check();
  await page.getByRole("button", { name: "Evaluate" }).click();

  await expect(output).toContainText("(con integer 42)");
  await expect(output).toContainText("CPU budget");
  await expect(output).toContainText("Memory budget");

  const observed = await output.textContent();
  console.log(`observed output:\n${observed}`);
});

test("manages named auto-versioned snippets in browser storage", async ({ page }) => {
  const alpha = "Alpha snippet";
  const beta = "Beta snippet";
  const editor = page.getByLabel("UPLC program");

  await page.goto("/");
  await waitForSnippetStore(page);

  const commitDelay = page.getByLabel("auto commit debounce milliseconds");
  await expect(commitDelay).toHaveValue("1500");
  await commitDelay.fill("100");
  await expect(commitDelay).toHaveValue("100");

  await createEmptySnippet(page, alpha);
  await editor.fill(subtractProgram);
  await waitForEditCommit(page, alpha);
  await expect(page.getByRole("button", { name: new RegExp(`^${escapeRegExp(alpha)} saved$`) })).toBeVisible();

  await createEmptySnippet(page, beta);
  await editor.fill(multiplyProgram);
  await waitForEditCommit(page, beta);

  await page.getByRole("button", { name: new RegExp(`^${escapeRegExp(alpha)}\\b`) }).click();
  await expect(editor).toContainText("subtractInteger");

  await page.getByRole("button", { name: new RegExp(`^${escapeRegExp(beta)}\\b`) }).click();
  await expect(editor).toContainText("multiplyInteger");

  await page.reload();
  await waitForSnippetStore(page);
  await expect(page.getByRole("button", { name: new RegExp(`^${escapeRegExp(alpha)}\\b`) })).toBeVisible();
  await expect(page.getByRole("button", { name: new RegExp(`^${escapeRegExp(beta)}\\b`) })).toBeVisible();

  await page.getByRole("button", { name: new RegExp(`^${escapeRegExp(alpha)}\\b`) }).click();
  await expect(editor).toContainText("subtractInteger");
  await expect(
    page.getByRole("button", { name: new RegExp(`edit ${escapeRegExp(alpha)}`) }),
  ).toBeVisible();
});
