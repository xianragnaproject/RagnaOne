/** Pixel-art drawing helpers for temple arena characters. */

const SCALE = 3;

function px(ctx, color, x, y, w = 1, h = 1) {
  ctx.fillStyle = color;
  ctx.fillRect(Math.round(x), Math.round(y), w, h);
}

export function drawPlayer(ctx, x, y, { facing = 1, moving = false, frame = 0 } = {}) {
  const ox = Math.round(x);
  const oy = Math.round(y);
  const bob = moving ? Math.sin(frame * 0.4) * 1.5 : 0;
  const leg = moving ? Math.sin(frame * 0.55) * 3 : 0;

  // shadow
  ctx.fillStyle = "rgba(0,0,0,0.32)";
  ctx.beginPath();
  ctx.ellipse(ox, oy + 22, 14, 4, 0, 0, Math.PI * 2);
  ctx.fill();

  // legs
  px(ctx, "#1d5c38", ox - 7, oy + 10 + bob + leg, 6, 10);
  px(ctx, "#1d5c38", ox + 1, oy + 10 + bob - leg, 6, 10);
  px(ctx, "#1a1a1a", ox - 7, oy + 19 + bob + leg, 6, 3);
  px(ctx, "#1a1a1a", ox + 1, oy + 19 + bob - leg, 6, 3);

  // body (green tracksuit)
  px(ctx, "#3ecf6a", ox - 10, oy - 6 + bob, 20, 17);
  px(ctx, "#2aa353", ox - 10, oy + 3 + bob, 20, 3);
  // number bib
  px(ctx, "#f4efe6", ox - 6, oy - 2 + bob, 12, 9);
  px(ctx, "#222", ox - 3, oy + 1 + bob, 6, 4);

  // head
  px(ctx, "#f0c4a0", ox - 7, oy - 18 + bob, 14, 13);
  px(ctx, "#222", ox - 4 + facing, oy - 14 + bob, 3, 3);
  px(ctx, "#222", ox + 2 + facing, oy - 14 + bob, 3, 3);
  px(ctx, "#c9896a", ox - 3, oy - 8 + bob, 6, 2);

  // hair
  px(ctx, "#3b2a1d", ox - 7, oy - 21 + bob, 14, 4);
}

export function drawGuard(ctx, x, y, { frame = 0, shooting = false } = {}) {
  const ox = Math.round(x);
  const oy = Math.round(y);
  const bob = Math.sin(frame * 0.15) * 0.5;

  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.beginPath();
  ctx.ellipse(ox, oy + 18, 11, 3, 0, 0, Math.PI * 2);
  ctx.fill();

  px(ctx, "#222", ox - 5, oy + 10 + bob, 4, 7);
  px(ctx, "#222", ox + 1, oy + 10 + bob, 4, 7);

  // pink jumpsuit
  px(ctx, "#e879a8", ox - 8, oy - 4 + bob, 16, 15);
  px(ctx, "#d45f92", ox - 8, oy + 4 + bob, 16, 2);

  // mask
  px(ctx, "#1a1a1a", ox - 6, oy - 15 + bob, 12, 12);
  // triangle symbol
  ctx.fillStyle = "#f4efe6";
  ctx.beginPath();
  ctx.moveTo(ox, oy - 12 + bob);
  ctx.lineTo(ox - 3, oy - 6 + bob);
  ctx.lineTo(ox + 3, oy - 6 + bob);
  ctx.closePath();
  ctx.fill();

  // gun
  px(ctx, "#333", ox + 8, oy + 1 + bob, 10, 3);
  px(ctx, "#222", ox + 16, oy + bob, 3, 5);
  if (shooting) {
    px(ctx, "#ffe08a", ox + 19, oy - 1 + bob, 5, 3);
  }
}

export function drawDoll(ctx, x, y, { lookingBack = false, frame = 0 } = {}) {
  const ox = Math.round(x);
  const oy = Math.round(y);
  const sway = Math.sin(frame * 0.08) * 1.5;

  // dress
  ctx.fillStyle = "#f2d6b0";
  ctx.beginPath();
  ctx.moveTo(ox - 28 + sway, oy + 40);
  ctx.lineTo(ox + 28 + sway, oy + 40);
  ctx.lineTo(ox + 16 + sway, oy - 10);
  ctx.lineTo(ox - 16 + sway, oy - 10);
  ctx.closePath();
  ctx.fill();

  // sash
  px(ctx, "#c45c4a", ox - 18 + sway, oy + 8, 36, 5);

  // head
  px(ctx, "#f0c4a0", ox - 14 + sway, oy - 34, 28, 26);
  // hair buns
  px(ctx, "#3b2a1d", ox - 22 + sway, oy - 36, 12, 12);
  px(ctx, "#3b2a1d", ox + 10 + sway, oy - 36, 12, 12);
  px(ctx, "#3b2a1d", ox - 12 + sway, oy - 40, 24, 10);

  // face direction
  if (lookingBack) {
    // back of head / hair
    px(ctx, "#3b2a1d", ox - 12 + sway, oy - 30, 24, 18);
  } else {
    px(ctx, "#222", ox - 8 + sway, oy - 24, 4, 4);
    px(ctx, "#222", ox + 4 + sway, oy - 24, 4, 4);
    px(ctx, "#c9896a", ox - 3 + sway, oy - 16, 6, 2);
  }
}

export function drawMuzzleFlash(ctx, x, y, life) {
  const a = Math.max(0, Math.min(1, life));
  ctx.fillStyle = `rgba(255, 220, 120, ${a})`;
  ctx.beginPath();
  ctx.arc(x, y, 6 + (1 - a) * 10, 0, Math.PI * 2);
  ctx.fill();
}

export function drawDeathBurst(ctx, x, y, life) {
  const a = Math.max(0, Math.min(1, life));
  ctx.fillStyle = `rgba(255, 70, 80, ${a})`;
  for (let i = 0; i < 6; i++) {
    const ang = (i / 6) * Math.PI * 2 + (1 - a);
    const r = 8 + (1 - a) * 18;
    px(ctx, `rgba(255,90,90,${a})`, x + Math.cos(ang) * r, y + Math.sin(ang) * r, 3, 3);
  }
}

export { SCALE };
