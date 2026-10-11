// Takes screenshots of the running platform for the README: the app, ArgoCD and Grafana.
// Used by the e2e workflow; the gateway is port-forwarded to localhost:8443.
import { chromium } from "playwright";
import { mkdirSync, writeFileSync } from "node:fs";

const [argocdPassword, grafanaPassword] = process.argv.slice(2);
const out = "screenshots";
mkdirSync(out, { recursive: true });
const browser = await chromium.launch();
const ctx = await browser.newContext({ ignoreHTTPSErrors: true, viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();
// Record anything that fails to load, so a broken screenshot explains itself.
const problems = [];
page.on("requestfailed", (r) => problems.push(`failed ${r.url()} ${r.failure()?.errorText}`));
page.on("response", (r) => { if (r.status() >= 400) problems.push(`${r.status()} ${r.url()}`); });
page.on("console", (m) => { if (m.type() === "error") problems.push(`console: ${m.text().slice(0, 300)}`); });

async function step(name, fn) {
  try { await fn(); console.log(`saved ${name}`); }
  catch (e) { console.log(`could not capture ${name}: ${e.message}`); await page.screenshot({ path: `${out}/failed-${name}.png` }); }
}

await step("due-app", async () => {
  await page.goto("https://due.localhost:8443/");
  await page.getByRole("button", { name: "Create an account" }).click();
  await page.fill("input[type=email]", `screenshot-${Date.now()}@example.com`);
  await page.fill("input[type=password]", "a long screenshot password");
  await page.getByRole("button", { name: "Create account" }).click();
  await page.waitForSelector("text=Add deadline");
  const token = await page.evaluate(() => localStorage.getItem("due.token"));
  const now = Date.now();
  for (const [title, hours, weight] of [["Cloud architecture report", 30, 40], ["Networking lab write-up", 100, 15], ["Database design coursework", 400, 35], ["Algorithms quiz", -20, 10]]) {
    await page.request.post("https://due.localhost:8443/api/deadlines", {
      headers: { Authorization: `Bearer ${token}` },
      data: { title, due_at: new Date(now + hours * 36e5).toISOString(), weight_percent: weight },
    });
  }
  await page.reload();
  await page.waitForSelector(".next-countdown");
  await page.screenshot({ path: `${out}/due-app.png` });
});

await step("argocd", async () => {
  await page.goto("https://argocd.localhost:8443/login");
  await page.fill("input[name=username]", "admin");
  await page.fill("input[name=password]", argocdPassword);
  await page.click("button[type=submit]");
  await page.waitForSelector(".applications-tiles, .applications-list", { timeout: 30000 });
  await page.waitForTimeout(2000);
  await page.screenshot({ path: `${out}/argocd-apps.png` });
  await page.goto("https://argocd.localhost:8443/applications/argocd/due?view=tree");
  await page.waitForTimeout(5000);
  await page.screenshot({ path: `${out}/argocd-due-tree.png` });
});

await step("grafana", async () => {
  problems.length = 0;
  await page.goto("https://grafana.localhost:8443/login", { waitUntil: "networkidle" });
  await page.fill("input[name=user]", "admin");
  await page.fill("input[name=password]", grafanaPassword);
  await page.click("button[type=submit]");
  await page.waitForURL(/grafana\.localhost:8443\/(\?|$|d|home)/, { timeout: 30000 });
  await page.goto("https://grafana.localhost:8443/d/due-overview?orgId=1&from=now-20m&to=now&kiosk");
  await page.waitForTimeout(8000);
  await page.screenshot({ path: `${out}/grafana-due.png` });
});

writeFileSync(`${out}/page-problems.txt`, problems.slice(0, 80).join("\n"));
await browser.close();
