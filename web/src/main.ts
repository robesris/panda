// App orchestrator. Owns the Pixi Application, the audio engine, and routes
// state transitions between TitleScreen and GameScene.

import { Application } from "pixi.js";
import { AudioFeatureEngine } from "./audio/engine";
import { AudioSource } from "./audio/source";
import { FluxVisualizer } from "./debug/visualizer";
import { FLUX_BEAT, GameScene, type InputState } from "./game/scene";
import { loadSprites } from "./game/sprites";
import { TitleScreen } from "./screens/title";

const stageCanvas = document.getElementById("stage") as HTMLCanvasElement;
const debugCanvas = document.getElementById("debug") as HTMLCanvasElement;
const fileInput = document.getElementById("file-input") as HTMLInputElement;
const meter = document.getElementById("meter") as HTMLSpanElement;
const micBtn = document.getElementById("mic-btn") as HTMLButtonElement;
const stopBtn = document.getElementById("stop-btn") as HTMLButtonElement;

const app = new Application();
await app.init({
  canvas: stageCanvas,
  width: 800,
  height: 500,
  background: 0x000000,
  antialias: false,
});

const sprites = await loadSprites();

const title = new TitleScreen();
title.build(sprites);
const game = new GameScene();
game.build(sprites);
game.container.visible = false;

app.stage.addChild(game.container);
app.stage.addChild(title.container);

const visualizer = new FluxVisualizer(debugCanvas);

let engine: AudioFeatureEngine | null = null;
let source: AudioSource | null = null;
let mode: "title" | "game" = "title";

const input: InputState = {
  mouseX: 400,
  mouseY: 250,
  mouseDown: false,
  spaceDown: false,
};

function ensureEngine(): { engine: AudioFeatureEngine; source: AudioSource } {
  if (engine && source) return { engine, source };
  const ctx = new AudioContext();
  engine = new AudioFeatureEngine(ctx, { fftSize: 2048, smoothing: 0.0, fps: 60 });
  source = new AudioSource(engine);
  source.onState((s) => {
    meter.textContent = s.label;
    title.setStatus(s.label);
    if (s.kind === "file" || s.kind === "mic") switchToGame();
    else if (s.kind === "none" && mode === "game") switchToTitle();
  });
  return { engine, source };
}

function switchToGame() {
  if (mode === "game") return;
  mode = "game";
  game.container.visible = true;
  stageCanvas.style.cursor = "none"; // Mouse.hide() in the original
  fadeOut(title.container, 220, () => {
    title.container.visible = false;
    title.container.alpha = 1;
  });
}

function switchToTitle() {
  if (mode === "title") return;
  mode = "title";
  stageCanvas.style.cursor = "default";
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

// Mouse + keyboard: only consumed during game mode; the title screen has its
// own Pixi event handlers for buttons.
function updateMouseFromEvent(e: MouseEvent) {
  const rect = stageCanvas.getBoundingClientRect();
  // Account for any CSS scaling between the canvas's drawing buffer and its
  // displayed size.
  const sx = stageCanvas.width / rect.width;
  const sy = stageCanvas.height / rect.height;
  input.mouseX = (e.clientX - rect.left) * sx;
  input.mouseY = (e.clientY - rect.top) * sy;
}

stageCanvas.addEventListener("mousemove", updateMouseFromEvent);
stageCanvas.addEventListener("mousedown", (e) => {
  updateMouseFromEvent(e);
  input.mouseDown = true;
  if (mode === "game") game.shoot();
});
window.addEventListener("mouseup", () => { input.mouseDown = false; });

window.addEventListener("keydown", (e) => {
  if (e.code === "Space" && !input.spaceDown) {
    input.spaceDown = true;
    if (mode === "game") game.shoot();
    e.preventDefault();
  }
});
window.addEventListener("keyup", (e) => {
  if (e.code === "Space") input.spaceDown = false;
});

// Single render tick.
let prevTime = performance.now();
app.ticker.add(() => {
  const now = performance.now();
  // dt scaled so 1.0 == "one frame at 60Hz" — the same units the original used at 30 FPS halved.
  const dt = Math.min(2, (now - prevTime) / (1000 / 60));
  prevTime = now;

  if (mode === "game") {
    game.update(input, dt);
    if (engine) {
      const f = engine.tick();
      visualizer.push(f, FLUX_BEAT);
      visualizer.draw(FLUX_BEAT);
      game.feed(f);
    }
  }
});

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
