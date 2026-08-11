#!/usr/bin/env python3

"""Generate long, quiet, seamless writing-room ambience.

These tracks are intentionally slow sound beds, not little songs.  Each is three
minutes long and constructed from periodic components so the loop point disappears.
They are encoded directly to compact AAC without leaving large WAV files behind.
"""

from __future__ import annotations

import math
import random
import subprocess
from pathlib import Path

import numpy as np


RATE = 22_050
DURATION = 180.0
COUNT = int(RATE * DURATION)
OUT = Path(__file__).resolve().parent.parent / "Packaging" / "Placeholder Music"
FFMPEG = "/opt/homebrew/bin/ffmpeg"


TRACKS = {
    # roots, pad, air, darkness, movement, sparse glass accents
    "calm": ([55.00, 82.41, 110.00, 164.81], 0.33, 0.075, 1.25, 0.18, [47, 121]),
    "mac1999": ([65.41, 98.00, 130.81, 196.00], 0.29, 0.038, 0.75, 0.24, [36, 94, 151]),
    "system95": ([55.00, 73.42, 110.00, 146.83], 0.25, 0.048, 0.88, 0.22, [61, 139]),
    "dos": ([43.65, 65.41, 87.31, 130.81], 0.23, 0.028, 1.45, 0.13, [73, 154]),
    "typewriter": ([41.20, 61.74, 82.41, 123.47], 0.19, 0.105, 1.60, 0.09, [89]),
    "library": ([49.00, 73.42, 98.00, 146.83], 0.27, 0.125, 1.75, 0.10, [58, 146]),
    "spaceAge": ([55.00, 82.41, 123.47, 185.00, 246.94], 0.36, 0.042, 0.92, 0.32, [42, 107, 161]),
    "cyberdeck": ([41.20, 61.74, 82.41, 123.47, 164.81], 0.30, 0.034, 0.82, 0.22, [43, 101, 157]),
    "hell": ([27.50, 38.89, 55.00, 77.78, 110.00], 0.38, 0.052, 2.08, 0.055, [111]),
    "liquidGlass": ([61.74, 92.50, 138.59, 207.65, 311.13], 0.31, 0.068, 1.05, 0.28, [39, 101, 163]),
}


def loop_frequency(frequency: float) -> float:
    """Snap to a whole number of cycles so the end joins the beginning."""
    return round(frequency * DURATION) / DURATION


def circular_colored_noise(rng: np.random.Generator, darkness: float) -> np.ndarray:
    """Create low-level periodic room tone; higher darkness means softer highs."""
    bins = COUNT // 2 + 1
    frequencies = np.fft.rfftfreq(COUNT, d=1 / RATE)
    phases = rng.uniform(0, math.tau, bins)
    amplitude = np.ones(bins, dtype=np.float64)
    amplitude[1:] = 1.0 / np.power(np.maximum(frequencies[1:], 0.08), darkness / 2)
    amplitude[0] = 0
    # Remove inaudible energy and all hiss above the deliberately narrow ambience band.
    amplitude[frequencies < 0.12] = 0
    amplitude[frequencies > 7_800] = 0
    spectrum = amplitude * (np.cos(phases) + 1j * np.sin(phases))
    noise = np.fft.irfft(spectrum, n=COUNT).astype(np.float32)
    peak = float(np.max(np.abs(noise))) or 1.0
    return noise / peak


def circular_bell(t: np.ndarray, event: float, frequency: float, decay: float = 7.5) -> np.ndarray:
    distance = np.mod(t - event + DURATION / 2, DURATION) - DURATION / 2
    age = np.mod(t - event, DURATION)
    envelope = np.exp(-age * decay)
    envelope[np.abs(distance) > 4.5] = 0
    f = loop_frequency(frequency)
    return (
        np.sin(math.tau * f * t)
        + 0.34 * np.sin(math.tau * loop_frequency(f * 1.997) * t + 0.4)
        + 0.12 * np.sin(math.tau * loop_frequency(f * 3.01) * t + 1.1)
    ) * envelope


def make_track(name: str, roots, pad_gain: float, air_gain: float, darkness: float, movement: float, events):
    seed = sum((index + 1) * ord(char) for index, char in enumerate(name))
    rng = np.random.default_rng(seed)
    randomizer = random.Random(seed)
    t = (np.arange(COUNT, dtype=np.float64) / RATE)

    left = np.zeros(COUNT, dtype=np.float32)
    right = np.zeros(COUNT, dtype=np.float32)
    for index, root in enumerate(roots):
        frequency = loop_frequency(root)
        drift_cycles = 1 + (index * 2) % 7
        drift = movement * 0.018 * np.sin(math.tau * drift_cycles * t / DURATION + index * 0.73)
        phase = math.tau * frequency * t + drift
        breathing = 0.68 + 0.24 * np.sin(math.tau * (index + 1) * t / DURATION + index) + 0.08 * np.sin(math.tau * (index + 4) * t / DURATION)
        partial = (np.sin(phase) + 0.18 * np.sin(phase * 2 + 0.8) + 0.06 * np.sin(phase * 3 - 0.3))
        weight = pad_gain / (1.4 + index * 0.72)
        pan = -0.62 + 1.24 * index / max(1, len(roots) - 1)
        left += (partial * breathing * weight * math.sqrt((1 - pan) / 2)).astype(np.float32)
        right += (partial * breathing * weight * math.sqrt((1 + pan) / 2)).astype(np.float32)

    noise_left = circular_colored_noise(rng, darkness)
    noise_right = circular_colored_noise(np.random.default_rng(seed + 9_973), darkness)
    # Slow, periodic changes make rain/air feel alive without becoming rhythmic.
    air_motion = (0.56 + 0.22 * np.sin(math.tau * 3 * t / DURATION + 0.8) + 0.12 * np.sin(math.tau * 7 * t / DURATION - 0.4)).astype(np.float32)
    left += noise_left * air_gain * air_motion
    right += noise_right * air_gain * np.roll(air_motion, COUNT // 11)

    # A faint environment-specific electrical or room fundamental.
    hum = (0.010 if name not in {"dos", "system95"} else 0.018) * np.sin(math.tau * loop_frequency(59.94 if name in {"dos", "system95"} else 29.97) * t)
    left += hum.astype(np.float32)
    right += np.roll(hum, 41).astype(np.float32)

    if name == "cyberdeck":
        # A submerged 90 BPM analog pulse: enough Italo-disco DNA to suggest motion,
        # slow and quiet enough that it never asks the writer to dance instead.
        beat_age = np.mod(t, 2 / 3)
        pulse = np.exp(-beat_age * 9.5)
        bass = np.sin(math.tau * loop_frequency(41.20) * t) * pulse * 0.040
        shimmer = np.sin(math.tau * loop_frequency(329.63) * t + 0.4) * np.exp(-beat_age * 14) * 0.009
        left += (bass + shimmer).astype(np.float32)
        right += (bass + np.roll(shimmer, RATE // 18)).astype(np.float32)

    for index, event in enumerate(events):
        if name == "typewriter":
            frequency = 220.0
        elif name == "cyberdeck":
            frequency = [329.63, 493.88, 659.25][index % 3]
        elif name == "liquidGlass":
            frequency = [622.25, 830.61, 739.99][index % 3]
        elif name == "hell":
            frequency = 73.42
        elif name == "dos":
            frequency = 329.63
        else:
            frequency = randomizer.choice([329.63, 392.00, 440.00, 493.88])
        bell = circular_bell(t, float(event), frequency, decay=8.8 if name != "liquidGlass" else 5.8).astype(np.float32)
        gain = 0.018 if name == "hell" else (0.025 if name in {"typewriter", "dos"} else (0.038 if name == "cyberdeck" else 0.034))
        if index % 2:
            left += bell * gain * 0.55
            right += bell * gain
        else:
            left += bell * gain
            right += bell * gain * 0.55

    audio = np.column_stack((left, right)).astype(np.float32)
    # Gentle saturation removes surprise peaks. The result is meant to sit behind thought.
    audio = np.tanh(audio * 1.25) * 0.52
    peak = float(np.max(np.abs(audio))) or 1.0
    if peak > 0.56:
        audio *= 0.56 / peak

    OUT.mkdir(parents=True, exist_ok=True)
    destination = OUT / f"{name}.m4a"
    command = [
        FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
        "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", "pipe:0",
        "-c:a", "aac", "-b:a", "48k", "-movflags", "+faststart", str(destination),
    ]
    process = subprocess.Popen(command, stdin=subprocess.PIPE)
    assert process.stdin is not None
    for start in range(0, COUNT, RATE * 10):
        chunk = audio[start : start + RATE * 10].astype("<f4", copy=False)
        process.stdin.write(chunk.tobytes())
    process.stdin.close()
    if process.wait() != 0:
        raise RuntimeError(f"ffmpeg failed while encoding {name}")
    print(f"{name}: {DURATION:.0f}s, {destination.stat().st_size / 1024:.0f} KB")


if __name__ == "__main__":
    for track_name, parameters in TRACKS.items():
        make_track(track_name, *parameters)
