import { AudioFeatureEngine } from "./audio/engine";
import { AudioSource } from "./audio/source";
import { FluxVisualizer } from "./debug/visualizer";
import { Sandbox } from "./game/sandbox";

const stageCanvas = document.getElementById("stage") as HTMLCanvasElement;
const debugCanvas = document.getElementById("debug") as HTMLCanvasElement;
const fileInput = document.getElementById("file-input") as HTMLInputElement;
const micBtn = document.getElementById("mic-btn") as HTMLButtonElement;
const stopBtn = document.getElementById("stop-btn") as HTMLButtonElement;
const meter = document.getElementById("meter") as HTMLSpanElement;

// AudioContext is created on first user gesture (browser policy).
let engine: AudioFeatureEngine | null = null;
let source: AudioSource | null = null;
const visualizer = new FluxVisualizer(debugCanvas);
const sandbox = new Sandbox();
await sandbox.init(stageCanvas);

function ensureEngine(): { engine: AudioFeatureEngine; source: AudioSource } {
  if (engine && source) return { engine, source };
  const ctx = new AudioContext();
  engine = new AudioFeatureEngine(ctx, { fftSize: 2048, smoothing: 0.0 });
  source = new AudioSource(engine);
  source.onState((s) => { meter.textContent = s.label; });
  // Drive the per-frame feature pull off rAF; same cadence as the renderer.
  const loop = () => {
    if (engine) {
      const f = engine.tick();
      visualizer.push(f, sandbox.thresholds.beatFlux);
      visualizer.draw(sandbox.thresholds.beatFlux);
      sandbox.feed(f);
    }
    requestAnimationFrame(loop);
  };
  requestAnimationFrame(loop);
  return { engine, source };
}

fileInput.addEventListener("change", async () => {
  const f = fileInput.files?.[0];
  if (!f) return;
  const { source } = ensureEngine();
  try {
    await source.loadFile(f);
  } catch (err) {
    meter.textContent = `decode failed: ${(err as Error).message}`;
  }
});

micBtn.addEventListener("click", async () => {
  const { source } = ensureEngine();
  try {
    await source.startMic();
  } catch (err) {
    meter.textContent = `mic denied: ${(err as Error).message}`;
  }
});

stopBtn.addEventListener("click", () => {
  source?.stop();
});
