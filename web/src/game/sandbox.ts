// Placeholder gameplay sandbox. Demonstrates feature-driven spawning so we
// can verify the audio engine end-to-end before porting the real game logic.
//
// Mapping (matches original semantics, scaled for our flux range):
//   flux > HI_FLUX           → small "skitter" enemy (pitch sets Y)
//   flux > BEAT_FLUX & peak  → big "beat" enemy (pulses)
//   level                    → background brightness

import { Application, Container, Graphics, Text } from "pixi.js";
import type { FrameFeatures } from "../audio/engine";

export interface SandboxThresholds {
  hiFlux: number;
  beatFlux: number;
}

interface Mover {
  g: Graphics;
  vx: number;
  vy: number;
  life: number;
  maxLife: number;
}

export class Sandbox {
  app: Application;
  private world: Container;
  private bg: Graphics;
  private movers: Mover[] = [];
  private statText: Text;
  thresholds: SandboxThresholds = { hiFlux: 0.6, beatFlux: 1.5 };
  private lastFlash = 0;

  constructor() {
    this.app = new Application();
    this.world = new Container();
    this.bg = new Graphics();
    this.statText = new Text({
      text: "",
      style: { fill: 0x9ff0f6, fontFamily: "ui-monospace, monospace", fontSize: 12 },
    });
  }

  async init(canvas: HTMLCanvasElement) {
    await this.app.init({
      canvas,
      width: 800,
      height: 500,
      background: 0x000000,
      antialias: true,
    });
    this.app.stage.addChild(this.bg);
    this.app.stage.addChild(this.world);
    this.statText.x = 8;
    this.statText.y = 8;
    this.app.stage.addChild(this.statText);
    this.app.ticker.add(() => this.update());
  }

  /** Feed one frame of audio features. Call before/each app.ticker tick. */
  feed(f: FrameFeatures) {
    // Background brightness from level.
    const brightness = Math.min(1, f.level * 4);
    const r = Math.floor(0x11 + 0x20 * brightness);
    const g = Math.floor(0x37 + 0x40 * brightness);
    const b = Math.floor(0x45 + 0x60 * brightness);
    this.bg.clear();
    this.bg.rect(0, 0, 800, 500).fill((r << 16) | (g << 8) | b);

    // Flash on peak.
    if (f.fluxPeak && f.flux > this.thresholds.beatFlux) {
      this.lastFlash = 8;
      this.spawnBeatEnemy(f);
    } else if (f.flux > this.thresholds.hiFlux) {
      // throttle hi-flux spawns; otherwise we get a flood.
      if (Math.random() < 0.25) this.spawnSkitter(f);
    }

    if (this.lastFlash > 0) {
      this.bg.rect(0, 0, 800, 500).fill({ color: 0xffffff, alpha: this.lastFlash / 16 });
      this.lastFlash--;
    }

    this.statText.text =
      `flux ${f.flux.toFixed(2)}  peak ${f.fluxPeak ? "*" : " "}  ` +
      `pitch ${f.pitch.toString().padStart(2, " ")}  ` +
      `Hz ${f.dominantHz.toFixed(0).padStart(5, " ")}  ` +
      `level ${f.level.toFixed(2)}  ` +
      `live ${this.movers.length}`;
  }

  private spawnSkitter(f: FrameFeatures) {
    const g = new Graphics();
    g.circle(0, 0, 6).fill(0x9ff0f6);
    const yFromPitch = f.pitch >= 0 ? 50 + (36 - f.pitch) * 12 : 250;
    g.x = 800 + 10;
    g.y = yFromPitch;
    this.world.addChild(g);
    this.movers.push({ g, vx: -3 - Math.random() * 2, vy: 0, life: 0, maxLife: 320 });
  }

  private spawnBeatEnemy(f: FrameFeatures) {
    const g = new Graphics();
    const size = 18 + Math.min(20, f.flux * 4);
    g.regularPoly(0, 0, size, 6).fill(0xffb347);
    const yFromPitch = f.pitch >= 0 ? 30 + (36 - f.pitch) * 12 : 200;
    g.x = 800 + 20;
    g.y = yFromPitch;
    this.world.addChild(g);
    this.movers.push({ g, vx: -2 - Math.random(), vy: 0, life: 0, maxLife: 400 });
  }

  private update() {
    for (let i = this.movers.length - 1; i >= 0; i--) {
      const m = this.movers[i];
      m.g.x += m.vx;
      m.g.y += m.vy;
      m.life++;
      if (m.life > m.maxLife || m.g.x < -40) {
        this.world.removeChild(m.g);
        m.g.destroy();
        this.movers.splice(i, 1);
      }
    }
  }
}
