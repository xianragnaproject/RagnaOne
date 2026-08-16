#!/usr/bin/env python3
"""Render a 1080x1920 TikTok video from a JSON script."""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import random
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
WIDTH, HEIGHT = 1080, 1920
SERIF = "/usr/share/fonts/truetype/noto/NotoSerif-Bold.ttf"
SANS = "/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf"
SANS_REG = "/usr/share/fonts/truetype/macos/Inter-Regular.ttf"
MONO = "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf"
VOICE = "en-US-AndrewMultilingualNeural"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size)


def wrap(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textlength(trial, font=face) <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines or [text]


def paint_background(seed: int) -> Image.Image:
    rng = random.Random(seed)
    sw, sh = 180, 320
    img = Image.new("RGB", (sw, sh), (16, 13, 10))
    px = img.load()
    cx, cy = rng.randint(30, 150), rng.randint(60, 250)
    for y in range(sh):
        for x in range(sw):
            dx = (x - cx) / 70
            dy = (y - cy) / 95
            dist = math.sqrt(dx * dx + dy * dy)
            glow = max(0.0, 1.2 - dist)
            r = min(255, int(16 + glow * 118 + rng.randint(-6, 6)))
            g = min(255, int(11 + glow * 42 + rng.randint(-4, 4)))
            b = min(255, int(8 + glow * 14))
            px[x, y] = (r, g, b)
    img = img.resize((WIDTH, HEIGHT), Image.Resampling.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=10))
    overlay = Image.new("RGB", (WIDTH, HEIGHT), (12, 10, 8))
    img = Image.blend(img, overlay, 0.22)
    grain = Image.new("RGB", (WIDTH // 2, HEIGHT // 2))
    gpx = grain.load()
    gw, gh = grain.size
    for y in range(gh):
        for x in range(gw):
            n = rng.randint(0, 26)
            gpx[x, y] = (n, n, n)
    grain = grain.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    return Image.blend(img, grain, 0.1)


def draw_scene(bg: Image.Image, scene: dict, index: int, total: int, brand: str) -> Image.Image:
    frame = bg.copy().convert("RGBA")
    draw = ImageDraw.Draw(frame, "RGBA")
    draw.rectangle((0, 0, WIDTH, 140), fill=(10, 8, 6, 180))
    draw.rectangle((0, HEIGHT - 160, WIDTH, HEIGHT), fill=(10, 8, 6, 180))
    draw.rectangle((0, 0, 14, HEIGHT), fill=(224, 122, 61, 255))

    kicker = scene.get("kicker") or brand
    kicker_font = font(MONO, 28)
    draw.text((64, 56), kicker.upper(), font=kicker_font, fill=(224, 122, 61))

    text = scene["text"]
    size = 92 if scene.get("hook") else 76
    face = font(SERIF, size)
    max_width = WIDTH - 128
    while size > 48 and any(draw.textlength(line, font=face) > max_width for line in text.split("\n")):
        # shrink only if a single hard line is too wide; wrapping handles the rest
        break
    lines = []
    for chunk in text.split("\n"):
        lines.extend(wrap(draw, chunk, face, max_width))
    line_h = int(size * 1.18)
    block_h = line_h * len(lines)
    y = (HEIGHT - block_h) // 2 - 40
    for line in lines:
        w = draw.textlength(line, font=face)
        draw.text(((WIDTH - w) / 2, y), line, font=face, fill=(243, 234, 220))
        y += line_h

    sub = scene.get("sub")
    if sub:
        sub_font = font(SANS_REG, 34)
        sub_lines = wrap(draw, sub, sub_font, WIDTH - 160)
        sy = y + 28
        for line in sub_lines:
            w = draw.textlength(line, font=sub_font)
            draw.text(((WIDTH - w) / 2, sy), line, font=sub_font, fill=(156, 144, 126))
            sy += 46

    mark = font(SANS, 24)
    draw.text((64, HEIGHT - 88), brand, font=mark, fill=(215, 176, 86))
    counter = font(MONO, 24)
    label = f"{index + 1:02d}/{total:02d}"
    lw = draw.textlength(label, font=counter)
    draw.text((WIDTH - 64 - lw, HEIGHT - 88), label, font=counter, fill=(110, 101, 88))
    return frame.convert("RGB")


async def speak(text: str, dest: Path, voice: str) -> None:
    import edge_tts

    dest.parent.mkdir(parents=True, exist_ok=True)
    communicate = edge_tts.Communicate(text, voice)
    await communicate.save(str(dest))


def probe_duration(path: Path) -> float:
    out = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        text=True,
    ).strip()
    return float(out)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def render_clip(frame_path: Path, audio_path: Path, dest: Path, seconds: float) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    # Scale up, then pan the crop so the still has a slow push-in.
    filt = (
        f"scale=1190:2115,crop=1080:1920:"
        f"'min(in_w-out_w, (in_w-out_w)*t/{seconds:.3f})':"
        f"'min(in_h-out_h, (in_h-out_h)*t/{max(seconds / 2, 0.2):.3f})',"
        "format=yuv420p"
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-loop",
            "1",
            "-framerate",
            "30",
            "-t",
            f"{seconds:.3f}",
            "-i",
            str(frame_path),
            "-i",
            str(audio_path),
            "-vf",
            filt,
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "19",
            "-c:a",
            "aac",
            "-b:a",
            "160k",
            "-ar",
            "44100",
            "-ac",
            "2",
            "-shortest",
            "-movflags",
            "+faststart",
            str(dest),
        ]
    )


def concat(clips: list[Path], dest: Path) -> None:
    listing = dest.with_suffix(".txt")
    listing.write_text("".join(f"file '{clip.resolve()}'\n" for clip in clips))
    run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(listing),
            "-c:v",
            "libx264",
            "-preset",
            "fast",
            "-crf",
            "19",
            "-c:a",
            "aac",
            "-b:a",
            "160k",
            "-movflags",
            "+faststart",
            str(dest),
        ]
    )


def render_spec(spec_path: Path, out_dir: Path, work_dir: Path, voice: str) -> Path:
    spec = json.loads(spec_path.read_text())
    video_id = spec["id"]
    brand = spec.get("brand", "RAGNA ONE")
    scenes = spec["scenes"]
    work = work_dir / video_id
    work.mkdir(parents=True, exist_ok=True)
    bg = paint_background(spec.get("seed", 7))
    clips: list[Path] = []

    for i, scene in enumerate(scenes):
        frame = draw_scene(bg, scene, i, len(scenes), brand)
        frame_path = work / f"frame-{i:02d}.png"
        frame.save(frame_path)
        spoken = scene.get("voice") or scene["text"]
        audio_path = work / f"vo-{i:02d}.mp3"
        asyncio.run(speak(spoken, audio_path, voice))
        audio_dur = probe_duration(audio_path)
        seconds = max(float(scene.get("seconds", 2.4)), audio_dur + 0.28)
        clip_path = work / f"clip-{i:02d}.mp4"
        render_clip(frame_path, audio_path, clip_path, seconds)
        clips.append(clip_path)

    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / f"{video_id}.mp4"
    concat(clips, dest)
    return dest


def main() -> int:
    parser = argparse.ArgumentParser(description="Render a RagnaOne TikTok video")
    parser.add_argument("script", nargs="+", help="JSON script path(s)")
    parser.add_argument("--out", default=str(ROOT / "videos" / "out"))
    parser.add_argument("--work", default=str(ROOT / "videos" / "work"))
    parser.add_argument("--voice", default=VOICE)
    args = parser.parse_args()
    for script in args.script:
        dest = render_spec(Path(script), Path(args.out), Path(args.work), args.voice)
        print(dest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
