// Rolling line graph of spectral flux + peak markers, drawn into a 2D canvas.
// Mirrors the FLUX_LINE debug overlay in the original gameAudioStuff.as.

import type { FrameFeatures } from "../audio/engine";

export class FluxVisualizer {
  private ctx: CanvasRenderingContext2D;
  private buf: { flux: number; peak: boolean }[];
  private head = 0;
  private maxFlux = 1;

  constructor(canvas: HTMLCanvasElement, sampleCount = 240) {
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("2d context unavailable");
    this.ctx = ctx;
    this.buf = Array.from({ length: sampleCount }, () => ({ flux: 0, peak: false }));
  }

  push(f: FrameFeatures, beatThreshold: number) {
    this.buf[this.head] = { flux: f.flux, peak: f.fluxPeak };
    this.head = (this.head + 1) % this.buf.length;
    this.maxFlux = Math.max(this.maxFlux * 0.995, f.flux, beatThreshold * 1.2, 0.001);
  }

  draw(beatThreshold: number) {
    const { ctx } = this;
    const w = ctx.canvas.width;
    const h = ctx.canvas.height;
    ctx.fillStyle = "#0a2330";
    ctx.fillRect(0, 0, w, h);

    // Threshold line.
    const ty = h - (beatThreshold / this.maxFlux) * h;
    ctx.strokeStyle = "#1d4f64";
    ctx.beginPath();
    ctx.moveTo(0, ty);
    ctx.lineTo(w, ty);
    ctx.stroke();

    // Flux line.
    ctx.strokeStyle = "#9ff0f6";
    ctx.beginPath();
    const n = this.buf.length;
    for (let i = 0; i < n; i++) {
      const idx = (this.head + i) % n;
      const x = (i / (n - 1)) * w;
      const y = h - (this.buf[idx].flux / this.maxFlux) * h;
      if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
    }
    ctx.stroke();

    // Peak markers.
    ctx.fillStyle = "#ffb347";
    for (let i = 0; i < n; i++) {
      const idx = (this.head + i) % n;
      if (this.buf[idx].peak) {
        const x = (i / (n - 1)) * w;
        const y = h - (this.buf[idx].flux / this.maxFlux) * h;
        ctx.beginPath();
        ctx.arc(x, y, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }
}
