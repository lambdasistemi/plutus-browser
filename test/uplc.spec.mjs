import { expect, test } from "@playwright/test";

const addIntegerProgram =
  "(program 1.0.0 [ [ (builtin addInteger) (con integer 40) ] (con integer 2) ])";

const subtractProgram =
  "(program 1.0.0 [ [ (builtin subtractInteger) (con integer 50) ] (con integer 8) ])";

const multiplyProgram =
  "(program 1.0.0 [ [ (builtin multiplyInteger) (con integer 6) ] (con integer 7) ])";

const firstExampleName = "01-add-integers";
const factorialExampleName = "15-factorial-recursion";
const seededExampleCount = 22;

const escapeRegExp = (value) =>
  value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

const snippetButtonPattern = (name) =>
  new RegExp(`^${escapeRegExp(name)}\\b`);

const snippetRows = (page) => page.getByTestId("snippet-row");

async function waitForSnippetStore(page) {
  await expect(page.getByLabel("Quick add snippet")).toBeEnabled();
  await expect(page.getByRole("button", { name: snippetButtonPattern(firstExampleName) })).toBeVisible();
}

async function createEmptySnippet(page, name) {
  await page.getByLabel("Quick add snippet").fill(name);
  await page.getByRole("button", { name: "Add snippet" }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern(name) })).toBeVisible();
}

async function openNewSnippetDialog(page, name, source) {
  await page.getByRole("button", { name: "new from..." }).click();
  await page.getByRole("menuitem", { name: source }).click();
  const dialog = page.getByRole("dialog", { name: "New snippet" });
  await expect(dialog).toBeVisible();
  await dialog.getByLabel("Snippet name").fill(name);
  return dialog;
}

async function chooseSelectOption(page, label, option) {
  await page.getByLabel(label).click();
  await page.getByRole("option", { name: option }).click();
}

async function waitForEditCommit(page, name) {
  await expect(
    page.getByRole("button", { name: new RegExp(`edit ${escapeRegExp(name)}`) }),
  ).toBeVisible({ timeout: 8_000 });
}

test("seeds verified examples on first run and persists them", async ({ page }) => {
  const editor = page.getByLabel("UPLC program");
  const output = page.locator("#output");

  await page.goto("/");
  await waitForSnippetStore(page);

  await expect(snippetRows(page)).toHaveCount(seededExampleCount);
  await page.getByRole("button", { name: snippetButtonPattern(factorialExampleName) }).click();
  await expect(editor).toContainText("equalsInteger");

  await page.getByRole("button", { name: "Evaluate" }).click();
  await expect(output).toContainText("(con integer 120)");

  await page.reload();
  await waitForSnippetStore(page);
  await expect(snippetRows(page)).toHaveCount(seededExampleCount);
  await expect(page.getByRole("button", { name: snippetButtonPattern(factorialExampleName) })).toBeVisible();
});

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

  await page.getByRole("button", { name: snippetButtonPattern(alpha) }).click();
  await expect(editor).toContainText("subtractInteger");

  await page.getByRole("button", { name: snippetButtonPattern(beta) }).click();
  await expect(editor).toContainText("multiplyInteger");

  await page.reload();
  await waitForSnippetStore(page);
  await expect(page.getByRole("button", { name: snippetButtonPattern(alpha) })).toBeVisible();
  await expect(page.getByRole("button", { name: snippetButtonPattern(beta) })).toBeVisible();

  await page.getByRole("button", { name: snippetButtonPattern(alpha) }).click();
  await expect(editor).toContainText("subtractInteger");
  await expect(
    page.getByRole("button", { name: new RegExp(`edit ${escapeRegExp(alpha)}`) }),
  ).toBeVisible();
});

test("supports todo-list inline add, rename, and delete", async ({ page }) => {
  const enterAdded = "Inline enter add";
  const buttonAdded = "Inline button add";
  const renamed = "Inline renamed";

  await page.goto("/");
  await waitForSnippetStore(page);
  await expect(snippetRows(page)).toHaveCount(seededExampleCount);

  await page.getByLabel("Quick add snippet").fill(enterAdded);
  await page.getByLabel("Quick add snippet").press("Enter");
  await expect(page.getByRole("button", { name: snippetButtonPattern(enterAdded) })).toBeVisible();

  await page.getByLabel("Quick add snippet").fill(buttonAdded);
  await page.getByRole("button", { name: "Add snippet" }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern(buttonAdded) })).toBeVisible();
  await expect(snippetRows(page)).toHaveCount(seededExampleCount + 2);

  await page.getByRole("button", { name: snippetButtonPattern(buttonAdded) }).hover();
  await page.getByRole("button", { name: `Rename ${buttonAdded}` }).click();
  await page.getByLabel("Rename snippet").fill(renamed);
  await page.getByRole("button", { name: "Save rename" }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern(renamed) })).toBeVisible();
  await expect(page.getByRole("button", { name: snippetButtonPattern(buttonAdded) })).toHaveCount(0);

  await page.getByRole("button", { name: snippetButtonPattern(renamed) }).hover();
  await page.getByRole("button", { name: `Delete ${renamed}` }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern(renamed) })).toHaveCount(0);
  await expect(page.getByRole("button", { name: snippetButtonPattern(enterAdded) })).toBeVisible();
  await expect(snippetRows(page)).toHaveCount(seededExampleCount + 1);
});

test("creates new snippets from empty, copy, file, and URL sources", async ({ page }) => {
  const editor = page.getByLabel("UPLC program");

  await page.route("**/remote-snippet.uplc", (route) =>
    route.fulfill({
      contentType: "text/plain",
      body: addIntegerProgram,
    }),
  );

  await page.goto("/");
  await waitForSnippetStore(page);

  await createEmptySnippet(page, "Empty source test");

  let dialog = await openNewSnippetDialog(page, "Copy source test", "Copy existing");
  await chooseSelectOption(page, "Copy source", "02-multiply-integers");
  await dialog.getByRole("button", { name: "Create" }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern("Copy source test") })).toBeVisible();
  await expect(editor).toContainText("multiplyInteger");

  dialog = await openNewSnippetDialog(page, "File source test", "Local file");
  await dialog.locator('input[type="file"]').setInputFiles({
    name: "local.uplc",
    mimeType: "text/plain",
    buffer: Buffer.from(subtractProgram),
  });
  await expect(dialog).toContainText("file loaded");
  await dialog.getByRole("button", { name: "Create" }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern("File source test") })).toBeVisible();
  await expect(editor).toContainText("subtractInteger");

  dialog = await openNewSnippetDialog(page, "URL source test", "URL");
  await dialog.getByLabel("Snippet URL").fill("/remote-snippet.uplc");
  await dialog.getByRole("button", { name: "Create" }).click();
  await expect(page.getByRole("button", { name: snippetButtonPattern("URL source test") })).toBeVisible();
  await expect(editor).toContainText("addInteger");
});
