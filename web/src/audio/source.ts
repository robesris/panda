// Audio source manager: file decode + microphone, both routed into the engine input.

import type { AudioFeatureEngine } from "./engine";

export type SourceKind = "file" | "mic" | "none";

export interface SourceState {
  kind: SourceKind;
  label: string;
  durationSec?: number;
}

export class AudioSource {
  private engine: AudioFeatureEngine;
  private currentNode: AudioNode | null = null;
  private currentBufferSource: AudioBufferSourceNode | null = null;
  private currentStream: MediaStream | null = null;
  private state: SourceState = { kind: "none", label: "no source" };
  private stateListeners = new Set<(s: SourceState) => void>();

  constructor(engine: AudioFeatureEngine) {
    this.engine = engine;
  }

  onState(fn: (s: SourceState) => void): () => void {
    this.stateListeners.add(fn);
    fn(this.state);
    return () => this.stateListeners.delete(fn);
  }

  private setState(s: SourceState) {
    this.state = s;
    this.stateListeners.forEach((l) => l(s));
  }

  async loadFile(file: File): Promise<void> {
    this.stop();
    const ctx = this.engine.ctx;
    if (ctx.state === "suspended") await ctx.resume();
    const buf = await file.arrayBuffer();
    const audioBuf = await ctx.decodeAudioData(buf);
    const src = ctx.createBufferSource();
    src.buffer = audioBuf;
    src.connect(this.engine.input);
    this.engine.setMonitor(true);
    this.engine.reset();
    src.start();
    src.onended = () => {
      if (this.currentBufferSource === src) {
        this.setState({ kind: "none", label: "ended" });
        this.currentBufferSource = null;
        this.currentNode = null;
      }
    };
    this.currentBufferSource = src;
    this.currentNode = src;
    this.setState({
      kind: "file",
      label: `file: ${file.name}`,
      durationSec: audioBuf.duration,
    });
  }

  async startMic(): Promise<void> {
    this.stop();
    const ctx = this.engine.ctx;
    if (ctx.state === "suspended") await ctx.resume();
    const stream = await navigator.mediaDevices.getUserMedia({
      audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: false },
    });
    const node = ctx.createMediaStreamSource(stream);
    node.connect(this.engine.input);
    this.engine.setMonitor(false); // avoid feedback
    this.engine.reset();
    this.currentStream = stream;
    this.currentNode = node;
    this.setState({ kind: "mic", label: "mic" });
  }

  stop() {
    if (this.currentBufferSource) {
      try { this.currentBufferSource.stop(); } catch { /* already stopped */ }
      try { this.currentBufferSource.disconnect(); } catch { /* already disconnected */ }
      this.currentBufferSource = null;
    }
    if (this.currentStream) {
      this.currentStream.getTracks().forEach((t) => t.stop());
      this.currentStream = null;
    }
    if (this.currentNode) {
      try { this.currentNode.disconnect(); } catch { /* already disconnected */ }
      this.currentNode = null;
    }
    this.engine.setMonitor(false);
    this.setState({ kind: "none", label: "stopped" });
  }
}
