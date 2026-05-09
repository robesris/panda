// App orchestrator. Owns the Pixi Application, the audio engine, and routes
// state transitions between TitleScreen and Sandbox.

import { Application } from "pixi.js";
import { AudioFeatureEngine } from "./audio/engine";
import { AudioSource } from "./audio/source";
import { FluxVisualizer } from "./debug/visualizer";
import { Sandbox } from "./game/sandbox";
import { loadSprites } from "./game/sprites";
import { TitleScreen } from "./screens/title";

const stageCanvas = document.getElementById("stage") as HTMLCanvasElement;
const debugCanvas = document.getElementById("debug") as HTMLCanvasElement;
const fileInput = document.getElementById("file-input") as HTMLInputElement;
const meter = document.getElementById("meter") as HTMLSpanElement;
// HTML controls remain available as a low-level fallback / for restarting.
const micBtn = document.getElementById("mic-btn") as HTMLButtonElement;
const stopBtn = document.getElementById("stop-btn") as HTMLButtonElement;

const app = new Application();
await app.init({
  canvas: stageCanvas,
  width: 800,
  height: 500,
  background: 0x0a2330,
  antialias: false,
});

const sprites = await loadSprites();

const title = new TitleScreen();
title.build(sprites);
const game = new Sandbox();
game.build(sprites);
game.container.visible = false;

app.stage.addChild(game.container);
app.stage.addChild(title.container);

const visualizer = new FluxVisualizer(debugCanvas);

let engine: AudioFeatureEngine | null = null;
let source: AudioSource | null = null;
let mode: "title" | "game" = "title";

function ensureEngine(): { engine: AudioFeatureEngine; source: AudioSource } {
  if (engine && source) return { engine, source };
  const ctx = new AudioContext();
  engine = new AudioFeatureEngine(ctx, { fftSize: 2048, smoothing: 0.0 });
  source = new AudioSource(engine);
  source.onState((s) => {
    meter.textContent = s.label;
    title.setStatus(s.label);
    if (s.kind === "file" || s.kind === "mic") {
      switchToGame();
    } else if (s.kind === "none" && mode === "game") {
      switchToTitle();
    }
  });
  return { engine, source };
}

function switchToGame() {
  if (mode === "game") return;
  mode = "game";
  game.container.visible = true;
  fadeOut(title.container, 220, () => {
    title.container.visible = false;
    title.container.alpha = 1;
  });
}

function switchToTitle() {
  if (mode === "title") return;
  mode = "title";
  title.container.visible = true;
  title.container.alpha = 0;
  fadeIn(title.container, 220);
}

title.onPickFile = () => fileInput.click();
title.onPickMic = async () => {
  const { source } = ensureEngine();
  try { await source.startMic(); }
  catch (err) { title.setStatus(`mic denied: ${(err as Error).message}`); }
};

fileInput.addEventListener("change", async () => {
  const f = fileInput.files?.[0];
  if (!f) return;
  const { source } = ensureEngine();
  try { await source.loadFile(f); }
  catch (err) { title.setStatus(`decode failed: ${(err as Error).message}`); }
});

micBtn.addEventListener("click", async () => {
  const { source } = ensureEngine();
  try { await source.startMic(); }
  catch (err) { meter.textContent = `mic denied: ${(err as Error).message}`; }
});

stopBtn.addEventListener("click", () => source?.stop());

// Single render tick. Audio features only flow when game is active.
app.ticker.add(() => {
  game.update();
  if (engine && mode === "game") {
    const f = engine.tick();
    visualizer.push(f, game.thresholds.beatFlux);
    visualizer.draw(game.thresholds.beatFlux);
    game.feed(f);
  }
});

// Simple alpha tweens; Pixi's ticker drives them so we share the same clock.
function fadeOut(target: { alpha: number }, ms: number, done?: () => void) {
  const start = performance.now();
  const from = target.alpha;
  const tick = () => {
    const t = Math.min(1, (performance.now() - start) / ms);
    target.alpha = from * (1 - t);
    if (t < 1) requestAnimationFrame(tick);
    else done?.();
  };
  tick();
}
function fadeIn(target: { alpha: number }, ms: number) {
  const start = performance.now();
  const tick = () => {
    const t = Math.min(1, (performance.now() - start) / ms);
    target.alpha = t;
    if (t < 1) requestAnimationFrame(tick);
  };
  tick();
}
