# Running Playwright Tests

> **Permission/cache-only consistency note** — These `npx playwright test` commands invoke the `playwright` test runner (a separate npm package from `@playwright/cli` — which provides the agent's `playwright-cli` browser automation bin documented in [SKILL.md](../SKILL.md)). They presume `playwright` is already installed as a project dev-dependency (`node_modules/.bin/playwright` is what `npx` resolves to). For agent sessions, prefer running through `npm run <script>` (which the project owner has wired to its installed dependency) so that registry fetch is structurally avoided. If `playwright` is *not* present locally, the user must install it as a project dep first (`npm install --save-dev playwright`) — agents should not auto-bootstrap via `npx --yes`.
>
> The skill's frontmatter `allowed-tools: Bash(playwright-cli:*) Bash(npx:*)` permits `npx` invocation, but the cache-only / user-managed-bootstrap split documented in the SKILL.md Installation section applies analogously to the `playwright` test runner.

To run Playwright tests, use `npx --offline playwright test` (cache-only — resolves to project's `node_modules/.bin/playwright`, fails fast if not installed locally) or a package manager script. To avoid opening the interactive html report, use `PLAYWRIGHT_HTML_OPEN=never` environment variable.

```bash
# Run all tests (assumes `playwright` is installed as a project dev-dep — npx resolves to node_modules/.bin/playwright)
PLAYWRIGHT_HTML_OPEN=never npx --offline playwright test

# Run all tests through a custom npm script (recommended — registry fetch structurally avoided)
PLAYWRIGHT_HTML_OPEN=never npm run special-test-command
```

# Debugging Playwright Tests

To debug a failing Playwright test, run it with `--debug=cli` option. This command will pause the test at the start and print the debugging instructions.

**IMPORTANT**: run the command in the background and check the output until "Debugging Instructions" is printed.

Once instructions containing a session name are printed, use `playwright-cli` to attach the session and explore the page.

```bash
# Run the test
PLAYWRIGHT_HTML_OPEN=never npx --offline playwright test --debug=cli
# ...
# ... debugging instructions for "tw-abcdef" session ...
# ...

# Attach to the test
playwright-cli attach tw-abcdef
```

Keep the test running in the background while you explore and look for a fix.
The test is paused at the start, so you should step over or pause at a particular location
where the problem is most likely to be.

Every action you perform with `playwright-cli` generates corresponding Playwright TypeScript code.
This code appears in the output and can be copied directly into the test. Most of the time, a specific locator or an expectation should be updated, but it could also be a bug in the app. Use your judgement.

After fixing the test, stop the background test run. Rerun to check that test passes.
