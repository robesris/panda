// Take a series of screenshots of the Phase A game using Playwright.
// Requires the Vite dev server to be running on http://127.0.0.1:5180.

import { chromium } from "playwright";
import * as path from "node:path";

const URL = "http://127.0.0.1:5180/";
const OUT = "/tmp/panda-shots";
const AUDIO_FILE = "/tmp/testbeat.wav";

async function main() {
  const browser = await chromium.launch({
    headless: true,
    args: ["--autoplay-policy=no-user-gesture-required", "--no-sandbox"],
  });
  const ctx = await browser.newContext({
    viewport: { width: 1024, height: 700 },
    deviceScaleFactor: 1,
  });
  const page = await ctx.newPage();

  page.on("pageerror", (e) => console.error("pageerror:", e.message));
  page.on("console", (m) => {
    if (m.type() === "error") console.error("console error:", m.text());
  });

  console.log("loading", URL);
  await page.goto(URL, { waitUntil: "networkidle" });
  // Wait for the title screen to be drawn.
  await page.waitForTimeout(800);

  // Screenshot 1: title screen
  await page.screenshot({ path: path.join(OUT, "01-title.png") });
  console.log("shot 1: title");

  // Find the file input and load the test WAV.
  await page.setInputFiles("#file-input", AUDIO_FILE);
  await page.waitForTimeout(500); // let decode + scene swap finish
  await page.screenshot({ path: path.join(OUT, "02-game-start.png") });
  console.log("shot 2: game initial");

  // Move the mouse low so the panda runs along the ground.
  const canvas = await page.$("#stage");
  const box = await canvas!.boundingBox();
  if (!box) throw new Error("no canvas bounding box");

  // Move panda along ground
  await page.mouse.move(box.x + 200, box.y + box.height - 30);
  await page.waitForTimeout(800);
  await page.screenshot({ path: path.join(OUT, "03-running.png") });
  console.log("shot 3: running on ground");

  // Fly up and to the right, fire several seeds
  await page.mouse.move(box.x + 200, box.y + 200, { steps: 10 });
  await page.waitForTimeout(200);
  for (let i = 0; i < 4; i++) {
    await page.mouse.move(box.x + 200 + i * 30, box.y + 200, { steps: 4 });
    await page.mouse.down();
    await page.mouse.up();
    await page.waitForTimeout(80);
  }
  await page.screenshot({ path: path.join(OUT, "04-flying-shooting.png") });
  console.log("shot 4: flying + shooting");

  // Move left briefly to trigger fly_back
  await page.mouse.move(box.x + 120, box.y + 220, { steps: 5 });
  await page.waitForTimeout(120);
  await page.screenshot({ path: path.join(OUT, "05-fly-back.png") });
  console.log("shot 5: fly_back");

  // Wait long enough for the 15s warm-up + 20s lock to elapse so we can
  // capture the HUD's LOCKED state. We have a 30s clip; wait ~22s.
  console.log("waiting 22s for audio normalization to lock...");
  // Move mouse around during the wait so animation states stay varied.
  for (let i = 0; i < 22; i++) {
    const y = 150 + Math.sin(i / 2) * 80;
    await page.mouse.move(box.x + 220 + Math.cos(i / 2) * 80, box.y + y, { steps: 5 });
    if (i % 3 === 0) {
      await page.mouse.down(); await page.mouse.up();
    }
    await page.waitForTimeout(1000);
  }
  await page.screenshot({ path: path.join(OUT, "06-locked.png") });
  console.log("shot 6: normalization locked");

  await browser.close();
}

main().catch((e) => { console.error(e); process.exit(1); });
