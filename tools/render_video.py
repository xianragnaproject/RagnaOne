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
SERIF_REG = "/usr/share/fonts/truetype/noto/NotoSerif-Regular.ttf"
SANS = "/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf"
SANS_REG = "/usr/share/fonts/truetype/macos/Inter-Regular.ttf"
MONO = "/usr/share/fonts/truetype/jetbrains-mono/JetBrainsMono-Bold.ttf"
VOICE = "en-GB-RyanNeural"

PALETTES = {
    "tungsten": {
        "base": (12, 9, 7),
        "glow": (210, 92, 38),
        "text": (247, 236, 220),
        "muted": (168, 148, 128),
        "kicker": (232, 150, 74),
        "bar": (6, 5, 4),
    },
    "midnight": {
        "base": (7, 9, 16),
        "glow": (48, 82, 160),
        "text": (232, 238, 248),
        "muted": (140, 152, 176),
        "kicker": (170, 196, 230),
        "bar": (4, 5, 8),
    },
    "blood": {
        "base": (12, 6, 6),
        "glow": (150, 28, 32),
        "text": (247, 230, 224),
        "muted": (176, 132, 128),
        "kicker": (220, 86, 78),
        "bar": (8, 3, 3),
    },
    "sage": {
        "base": (7, 11, 9),
        "glow": (46, 110, 78),
        "text": (230, 240, 228),
        "muted": (140, 160, 148),
        "kicker": (150, 196, 164),
        "bar": (4, 7, 6),
    },
}


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


def paint_background(seed: int, palette: dict) -> Image.Image:
    rng = random.Random(seed)
    sw, sh = 200, 356
    img = Image.new("RGB", (sw, sh), palette["base"])
    px = img.load()
    cx, cy = rng.randint(40, 160), rng.randint(80, 260)
    gr, gg, gb = palette["glow"]
    br, bg_, bb = palette["base"]
    for y in range(sh):
        for x in range(sw):
            # Wide anamorphic streak, plus a weaker vertical bloom.
            dx = (x - cx) / 150
            dy = (y - cy) / 22
            streak = math.exp(-(dx * dx + dy * dy))
            bloom = max(0.0, 1.05 - math.sqrt(((x - cx) / 90) ** 2 + ((y - cy) / 80) ** 2))
            glow = min(1.0, streak * 1.15 + bloom * 0.35)
            r = min(255, int(br + glow * gr + rng.randint(-5, 5)))
            g = min(255, int(bg_ + glow * (gg * 0.55) + rng.randint(-4, 4)))
            b = min(255, int(bb + glow * (gb * 0.45)))
            px[x, y] = (r, g, b)
    img = img.resize((WIDTH, HEIGHT), Image.Resampling.BICUBIC)
    img = img.filter(ImageFilter.GaussianBlur(radius=14))
    overlay = Image.new("RGB", (WIDTH, HEIGHT), palette["base"])
    img = Image.blend(img, overlay, 0.18)
    grain = Image.new("RGB", (WIDTH // 2, HEIGHT // 2))
    gpx = grain.load()
    gw, gh = grain.size
    for y in range(gh):
        for x in range(gw):
            n = rng.randint(0, 30)
            gpx[x, y] = (n, n, n)
    grain = grain.resize((WIDTH, HEIGHT), Image.Resampling.NEAREST)
    return Image.blend(img, grain, 0.11)


def draw_scene(bg: Image.Image, scene: dict, index: int, total: int, brand: str, palette: dict) -> Image.Image:
    frame = bg.copy().convert("RGBA")
    draw = ImageDraw.Draw(frame, "RGBA")
    bar = (*palette["bar"], 255)
    letter = 268
    draw.rectangle((0, 0, WIDTH, letter), fill=bar)
    draw.rectangle((0, HEIGHT - letter, WIDTH, HEIGHT), fill=bar)
    # Hairline like a scope frame.
    draw.rectangle((0, letter, WIDTH, letter + 3), fill=(*palette["kicker"], 210))
    draw.rectangle((0, HEIGHT - letter - 3, WIDTH, HEIGHT - letter), fill=(*palette["kicker"], 210))

    kicker = scene.get("kicker") or "FEATURE"
    kicker_font = font(MONO, 26)
    draw.text((56, 72), kicker.upper(), font=kicker_font, fill=palette["kicker"])
    counter = font(MONO, 22)
    label = f"{index + 1:02d}/{total:02d}"
    lw = draw.textlength(label, font=counter)
    draw.text((WIDTH - 56 - lw, 74), label, font=counter, fill=palette["muted"])

    text = scene["text"]
    size = 88 if scene.get("hook") else 70
    face = font(SERIF, size)
    max_width = WIDTH - 120
    lines: list[str] = []
    for chunk in text.split("\n"):
        lines.extend(wrap(draw, chunk, face, max_width))
    line_h = int(size * 1.16)
    block_h = line_h * len(lines)
    y = letter + ((HEIGHT - 2 * letter) - block_h) // 2 - 20
    for line in lines:
        w = draw.textlength(line, font=face)
        draw.text(((WIDTH - w) / 2, y), line, font=face, fill=palette["text"])
        y += line_h

    sub = scene.get("sub")
    if sub:
        sub_font = font(SERIF_REG, 32)
        sub_lines = wrap(draw, sub, sub_font, WIDTH - 160)
        sy = y + 22
        for line in sub_lines:
            w = draw.textlength(line, font=sub_font)
            draw.text(((WIDTH - w) / 2, sy), line, font=sub_font, fill=palette["muted"])
            sy += 42

    mark = font(SANS, 22)
    draw.text((56, HEIGHT - 92), brand, font=mark, fill=palette["kicker"])
    tag = font(SANS_REG, 20)
    tag_text = scene.get("footer") or "ORIGINAL COMMENTARY"
    tw = draw.textlength(tag_text, font=tag)
    draw.text((WIDTH - 56 - tw, HEIGHT - 90), tag_text, font=tag, fill=palette["muted"])
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
    palette = PALETTES.get(spec.get("palette", "tungsten"), PALETTES["tungsten"])
    work = work_dir / video_id
    work.mkdir(parents=True, exist_ok=True)
    bg = paint_background(spec.get("seed", 7), palette)
    clips: list[Path] = []
    chosen_voice = spec.get("voice") or voice

    for i, scene in enumerate(scenes):
        frame = draw_scene(bg, scene, i, len(scenes), brand, palette)
        frame_path = work / f"frame-{i:02d}.png"
        frame.save(frame_path)
        spoken = scene.get("voice") or scene["text"].replace("\n", " ")
        audio_path = work / f"vo-{i:02d}.mp3"
        asyncio.run(speak(spoken, audio_path, chosen_voice))
        audio_dur = probe_duration(audio_path)
        seconds = max(float(scene.get("seconds", 2.6)), audio_dur + 0.35)
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
