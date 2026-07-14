#!/usr/bin/env python3
"""Собрать скриншоты лендинга: сырой захват экрана в рамке Pixel 8."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

import numpy as np
from PIL import Image

GARDEN_ROOT = Path(__file__).resolve().parents[1]
FARMING_ROOT = Path(os.environ.get('FARMING_ROOT', GARDEN_ROOT.parent / 'farming'))
RUSTORE_DIR = FARMING_ROOT / 'documents/rustore_screenshots'
SOURCE_DIR = RUSTORE_DIR / 'sources'
FRAME_DIR = RUSTORE_DIR / 'frames/pixel_8_hazel'
OUTPUT_DIR = GARDEN_ROOT / 'public/images/screenshots'

FRAME_METAL_DARK = np.array((30, 63, 38), dtype=np.float32)
FRAME_METAL_MID = np.array((47, 93, 58), dtype=np.float32)
FRAME_METAL_HIGHLIGHT = np.array((108, 150, 118), dtype=np.float32)
FRAME_METAL_SHINE = np.array((176, 208, 186), dtype=np.float32)
FRAME_TEXTURE_BLEND = 0.18
FRAME_INNER_BEZEL_LUMINANCE_MAX = 50.0

# Высоты рамки как в первоначальной версии лендинга (afad0bb).
LANDING_SPECS: tuple[tuple[str, str, int], ...] = (
    ('1.png', 'hero.png', 1073),
    ('6.png', 'plan.png', 996),
    ('7.png', 'garden.png', 996),
    ('2.png', 'plants.png', 996),
)


@dataclass(frozen=True)
class PhoneFrameAssets:
    frame: Image.Image
    mask: Image.Image
    screen_x: int
    screen_y: int
    screen_width: int
    screen_height: int
    frame_width: int
    frame_height: int


@lru_cache(maxsize=1)
def _load_phone_frame_assets(frame_dir: str) -> PhoneFrameAssets:
    frame_path = Path(frame_dir)
    with (frame_path / 'template.json').open(encoding='utf-8') as template_file:
        template = json.load(template_file)

    screen = template['screen']
    frame_size = template['frameSize']
    return PhoneFrameAssets(
        frame=Image.open(frame_path / template['frame']).convert('RGBA'),
        mask=Image.open(frame_path / template['mask']).convert('L'),
        screen_x=screen['x'],
        screen_y=screen['y'],
        screen_width=screen['width'],
        screen_height=screen['height'],
        frame_width=frame_size['width'],
        frame_height=frame_size['height'],
    )


def _tint_frame_metallic_green(frame: Image.Image) -> Image.Image:
    rgba = np.array(frame.convert('RGBA'), dtype=np.float32)
    alpha = rgba[:, :, 3]
    luminance = 0.299 * rgba[:, :, 0] + 0.587 * rgba[:, :, 1] + 0.114 * rgba[:, :, 2]
    tint_mask = (alpha > 0) & (luminance >= FRAME_INNER_BEZEL_LUMINANCE_MAX)

    result = rgba.copy()
    if not np.any(tint_mask):
        return frame

    outer_luminance = luminance[tint_mask]
    luminance_norm = np.clip(
        (outer_luminance - FRAME_INNER_BEZEL_LUMINANCE_MAX) / (255.0 - FRAME_INNER_BEZEL_LUMINANCE_MAX),
        0.0,
        1.0,
    )

    tinted = np.zeros((np.count_nonzero(tint_mask), 3), dtype=np.float32)
    low_mask = luminance_norm < 0.4
    mid_mask = (luminance_norm >= 0.4) & (luminance_norm < 0.75)
    high_mask = luminance_norm >= 0.75

    low_t = luminance_norm / 0.4
    tinted[low_mask] = FRAME_METAL_DARK + (FRAME_METAL_MID - FRAME_METAL_DARK) * low_t[low_mask, np.newaxis]

    mid_t = (luminance_norm - 0.4) / 0.35
    tinted[mid_mask] = FRAME_METAL_MID + (FRAME_METAL_HIGHLIGHT - FRAME_METAL_MID) * mid_t[mid_mask, np.newaxis]

    high_t = (luminance_norm - 0.75) / 0.25
    tinted[high_mask] = FRAME_METAL_HIGHLIGHT + (FRAME_METAL_SHINE - FRAME_METAL_HIGHLIGHT) * high_t[high_mask, np.newaxis]

    original_outer = rgba[:, :, :3][tint_mask]
    tinted = tinted * (1.0 - FRAME_TEXTURE_BLEND) + original_outer * FRAME_TEXTURE_BLEND
    result[:, :, :3][tint_mask] = np.clip(tinted, 0.0, 255.0)
    return Image.fromarray(result.astype(np.uint8), mode='RGBA')


def compose_phone_with_frame(
    screenshot: Image.Image,
    frame_assets: PhoneFrameAssets,
    target_frame_height: int,
) -> Image.Image:
    scale = target_frame_height / frame_assets.frame_height
    frame_width = int(frame_assets.frame_width * scale)
    frame_height = int(target_frame_height)
    screen_x = int(frame_assets.screen_x * scale)
    screen_y = int(frame_assets.screen_y * scale)
    screen_width = int(frame_assets.screen_width * scale)
    screen_height = int(frame_assets.screen_height * scale)

    frame = frame_assets.frame.resize((frame_width, frame_height), Image.Resampling.LANCZOS)
    frame = _tint_frame_metallic_green(frame)
    mask = frame_assets.mask.resize((frame_width, frame_height), Image.Resampling.LANCZOS)
    screen = screenshot.resize((screen_width, screen_height), Image.Resampling.LANCZOS)

    screen_mask = mask.crop((screen_x, screen_y, screen_x + screen_width, screen_y + screen_height))
    screen_rgba = screen.convert('RGBA')
    screen_rgba.putalpha(screen_mask)

    phone = Image.new('RGBA', (frame_width, frame_height), (0, 0, 0, 0))
    phone.paste(screen_rgba, (screen_x, screen_y), screen_rgba)
    phone.alpha_composite(frame)
    return phone


def _write_hero_webp(hero_png: Path) -> None:
    hero_webp = hero_png.with_suffix('.webp')
    try:
        subprocess.run(
            ['cwebp', '-q', '85', str(hero_png), '-o', str(hero_webp)],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise SystemExit('cwebp не найден — установите libwebp для hero.webp') from exc


def main() -> None:
    if not SOURCE_DIR.is_dir():
        raise SystemExit(f'Не найдена папка с исходниками: {SOURCE_DIR}')
    if not (FRAME_DIR / 'template.json').is_file():
        raise SystemExit(f'Не найдены ассеты рамки: {FRAME_DIR}')

    frame_assets = _load_phone_frame_assets(str(FRAME_DIR))
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for source_name, output_name, frame_height in LANDING_SPECS:
        source_path = SOURCE_DIR / source_name
        if not source_path.is_file():
            raise SystemExit(f'Не найден исходник: {source_path}')

        screenshot = Image.open(source_path).convert('RGB')
        phone = compose_phone_with_frame(screenshot, frame_assets, frame_height)
        output_path = OUTPUT_DIR / output_name
        phone.save(output_path, format='PNG', optimize=True)
        size_kb = os.path.getsize(output_path) / 1024
        print(f'✓ {output_path.name} ({phone.width}x{phone.height}, {size_kb:.0f} KB)')

    _write_hero_webp(OUTPUT_DIR / 'hero.png')


if __name__ == '__main__':
    main()
