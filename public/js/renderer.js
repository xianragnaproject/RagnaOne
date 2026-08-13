/**
 * Canvas stickman wrestling arena renderer.
 */
export class ArenaRenderer {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.t = 0;
    this.particles = [];
    this.state = null;
    this.dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.resize();
    window.addEventListener("resize", () => this.resize());
  }

  resize() {
    const parent = this.canvas.parentElement;
    const w = parent?.clientWidth || 1280;
    const h = parent?.clientHeight || 720;
    this.canvas.width = Math.floor(w * this.dpr);
    this.canvas.height = Math.floor(h * this.dpr);
    this.canvas.style.width = `${w}px`;
    this.canvas.style.height = `${h}px`;
    this.ctx.setTransform(this.dpr, 0, 0, this.dpr, 0, 0);
    this.w = w;
    this.h = h;
  }

  setState(state) {
    this.state = state;
  }

  spawnBurst(x, y, color, n = 10) {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const s = 40 + Math.random() * 120;
      this.particles.push({
        x,
        y,
        vx: Math.cos(a) * s,
        vy: Math.sin(a) * s - 40,
        life: 0.5 + Math.random() * 0.5,
        max: 0.5 + Math.random() * 0.5,
        color,
        r: 2 + Math.random() * 3,
      });
    }
  }

  start() {
    const loop = (ts) => {
      this.t = ts / 1000;
      this.draw();
      requestAnimationFrame(loop);
    };
    requestAnimationFrame(loop);
  }

  draw() {
    const { ctx, w, h } = this;
    ctx.clearRect(0, 0, w, h);
    this.drawArena();
    this.drawCrowd();

    const left = this.state?.challenger;
    const right = this.state?.champion;
    const ringY = h * 0.72;
    const leftX = w * 0.34;
    const rightX = w * 0.66;

    if (left) this.drawFighter(left, leftX, ringY, 1);
    if (right) this.drawFighter(right, rightX, ringY, -1);

    // Impact flash when attacking
    if (left?.anim === "attack" || right?.anim === "attack") {
      const midX = (leftX + rightX) / 2;
      ctx.save();
      ctx.globalAlpha = 0.35 + Math.sin(this.t * 40) * 0.15;
      ctx.fillStyle = "#fff4c2";
      ctx.beginPath();
      ctx.arc(midX, ringY - 70, 28, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }

    this.updateParticles(1 / 60);
    this.drawParticles();

    if (this.state?.phase === "result") {
      this.drawResultBanner();
    } else if (this.state?.phase === "waiting" && !left) {
      this.drawWaiting();
    }
  }

  drawArena() {
    const { ctx, w, h } = this;
    // Floor wash
    const floor = ctx.createLinearGradient(0, h * 0.45, 0, h);
    floor.addColorStop(0, "rgba(20,28,42,0)");
    floor.addColorStop(0.35, "rgba(28, 18, 18, 0.55)");
    floor.addColorStop(1, "rgba(8,10,14,0.95)");
    ctx.fillStyle = floor;
    ctx.fillRect(0, h * 0.4, w, h * 0.6);

    // Ring apron
    const cx = w / 2;
    const cy = h * 0.74;
    const rw = Math.min(w * 0.62, 720);
    const rh = Math.min(h * 0.18, 130);

    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(1, 0.42);
    ctx.beginPath();
    ctx.rect(-rw / 2, -rh / 2, rw, rh);
    ctx.fillStyle = "#1a0f12";
    ctx.fill();
    ctx.lineWidth = 10;
    ctx.strokeStyle = "#c9a227";
    ctx.stroke();

    // Mat
    ctx.beginPath();
    ctx.rect(-rw / 2 + 18, -rh / 2 + 18, rw - 36, rh - 36);
    ctx.fillStyle = "#2a1218";
    ctx.fill();
    ctx.restore();

    // Posts + ropes (flat perspective)
    const nearL = { x: cx - rw * 0.42, y: cy + 8 };
    const nearR = { x: cx + rw * 0.42, y: cy + 8 };
    const farL = { x: cx - rw * 0.32, y: cy - 58 };
    const farR = { x: cx + rw * 0.32, y: cy - 58 };

    for (const p of [nearL, nearR, farL, farR]) {
      ctx.fillStyle = "#d6b23a";
      ctx.fillRect(p.x - 5, p.y - 110, 10, 118);
      ctx.fillStyle = "#f2d36b";
      ctx.beginPath();
      ctx.arc(p.x, p.y - 112, 9, 0, Math.PI * 2);
      ctx.fill();
    }

    const ropeColors = ["#d62828", "#f4f1e8", "#d62828"];
    for (let i = 0; i < 3; i++) {
      const yOff = -30 - i * 28;
      ctx.strokeStyle = ropeColors[i];
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.moveTo(nearL.x, nearL.y + yOff);
      ctx.lineTo(farL.x, farL.y + yOff);
      ctx.lineTo(farR.x, farR.y + yOff);
      ctx.lineTo(nearR.x, nearR.y + yOff);
      ctx.stroke();
    }

    // Spotlight
    const spot = ctx.createRadialGradient(cx, h * 0.2, 20, cx, h * 0.55, w * 0.45);
    spot.addColorStop(0, "rgba(255,230,160,0.12)");
    spot.addColorStop(1, "rgba(0,0,0,0)");
    ctx.fillStyle = spot;
    ctx.fillRect(0, 0, w, h);
  }

  drawCrowd() {
    const { ctx, w, h, t } = this;
    const baseY = h * 0.48;
    for (let i = 0; i < 18; i++) {
      const x = (w * 0.08) + (i / 17) * w * 0.84;
      const bob = Math.sin(t * 3 + i) * 4;
      const s = 0.55 + (i % 3) * 0.08;
      ctx.save();
      ctx.translate(x, baseY + bob);
      ctx.scale(s, s);
      ctx.strokeStyle = "rgba(220,220,230,0.35)";
      ctx.lineWidth = 3;
      ctx.lineCap = "round";
      // tiny spectator stick
      ctx.beginPath();
      ctx.arc(0, -40, 7, 0, Math.PI * 2);
      ctx.moveTo(0, -33);
      ctx.lineTo(0, -8);
      ctx.moveTo(-10, -24);
      ctx.lineTo(10, -24);
      ctx.stroke();
      ctx.restore();
    }
  }

  drawFighter(f, x, y, facing) {
    const { ctx, t } = this;
    const anim = f.anim || "idle";
    let bob = Math.sin(t * 6) * 2;
    let armSwing = Math.sin(t * 8) * 0.15;
    let legSpread = 10;
    let lean = 0;
    let flash = null;

    if (anim === "attack") {
      armSwing = facing * 1.2;
      lean = facing * 12;
      bob = -6;
    } else if (anim === "hurt") {
      lean = -facing * 14;
      bob = 8;
      flash = "rgba(214,40,40,0.5)";
    } else if (anim === "heal") {
      flash = "rgba(46,204,113,0.45)";
      bob = -4;
    } else if (anim === "power") {
      flash = "rgba(240,192,64,0.45)";
      armSwing = Math.sin(t * 20) * 0.8;
    } else if (anim === "ko") {
      this.drawKo(f, x, y, facing);
      return;
    }

    ctx.save();
    ctx.translate(x + lean, y + bob);
    ctx.scale(facing, 1);

    if (flash) {
      ctx.shadowColor = flash;
      ctx.shadowBlur = 24;
    }

    ctx.strokeStyle = f.color || "#f5f5f5";
    ctx.fillStyle = f.color || "#f5f5f5";
    ctx.lineWidth = 5;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    // Head
    ctx.beginPath();
    ctx.arc(0, -118, 16, 0, Math.PI * 2);
    ctx.stroke();

    // Body
    ctx.beginPath();
    ctx.moveTo(0, -102);
    ctx.lineTo(0, -48);
    ctx.stroke();

    // Arms
    ctx.beginPath();
    ctx.moveTo(0, -90);
    ctx.lineTo(-22, -70 + armSwing * 10);
    ctx.moveTo(0, -90);
    ctx.lineTo(28 + (anim === "attack" ? 24 : 0), -78 - armSwing * 20);
    ctx.stroke();

    // Weapon
    if (f.weapon === "stick") {
      ctx.strokeStyle = "#c9a227";
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(28 + (anim === "attack" ? 24 : 0), -78 - armSwing * 20);
      ctx.lineTo(70 + (anim === "attack" ? 30 : 0), -110 - armSwing * 10);
      ctx.stroke();
      ctx.strokeStyle = f.color || "#f5f5f5";
      ctx.lineWidth = 5;
    }

    // Legs
    ctx.beginPath();
    ctx.moveTo(0, -48);
    ctx.lineTo(-legSpread, 0);
    ctx.moveTo(0, -48);
    ctx.lineTo(legSpread + 4, 0);
    ctx.stroke();

    ctx.restore();

    // Nameplate
    ctx.save();
    ctx.font = '700 14px "IBM Plex Sans", sans-serif';
    ctx.textAlign = "center";
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    const label = f.name.length > 14 ? f.name.slice(0, 13) + "…" : f.name;
    const tw = ctx.measureText(label).width + 16;
    ctx.fillRect(x - tw / 2, y + 10, tw, 22);
    ctx.fillStyle = "#f4f1e8";
    ctx.fillText(label, x, y + 26);
    ctx.restore();
  }

  drawKo(f, x, y, facing) {
    const { ctx, t } = this;
    ctx.save();
    ctx.translate(x, y - 20);
    ctx.rotate(facing * (Math.PI / 2) * 0.9);
    ctx.strokeStyle = f.color || "#f5f5f5";
    ctx.lineWidth = 5;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.arc(0, -30, 14, 0, Math.PI * 2);
    ctx.moveTo(0, -16);
    ctx.lineTo(0, 30);
    ctx.moveTo(-18, 0);
    ctx.lineTo(18, 0);
    ctx.moveTo(0, 30);
    ctx.lineTo(-14, 50);
    ctx.moveTo(0, 30);
    ctx.lineTo(14, 50);
    ctx.stroke();
    ctx.restore();

    ctx.save();
    ctx.font = '700 18px "Bebas Neue", sans-serif';
    ctx.fillStyle = "#d62828";
    ctx.textAlign = "center";
    ctx.globalAlpha = 0.7 + Math.sin(t * 8) * 0.3;
    ctx.fillText("KO", x, y - 90);
    ctx.restore();
  }

  drawWaiting() {
    const { ctx, w, h, t } = this;
    ctx.save();
    ctx.font = '700 42px "Bebas Neue", sans-serif';
    ctx.textAlign = "center";
    ctx.fillStyle = `rgba(244,241,232,${0.55 + Math.sin(t * 3) * 0.2})`;
    ctx.fillText("TYPE  JOIN  IN  CHAT", w / 2, h * 0.58);
    ctx.font = '600 16px "IBM Plex Sans", sans-serif';
    ctx.fillStyle = "rgba(201,162,39,0.85)";
    ctx.fillText("or tap 30 likes to enter the ring", w / 2, h * 0.58 + 28);
    ctx.restore();
  }

  drawResultBanner() {
    const { ctx, w, h, t, state } = this;
    const winner =
      state?.challenger?.alive && !state?.champion?.alive
        ? state.challenger.name
        : state?.champion?.name || "WINNER";
    ctx.save();
    ctx.fillStyle = "rgba(0,0,0,0.35)";
    ctx.fillRect(0, h * 0.28, w, 90);
    ctx.font = '700 56px "Bebas Neue", sans-serif';
    ctx.textAlign = "center";
    ctx.fillStyle = "#ffd76a";
    ctx.shadowColor = "rgba(201,162,39,0.6)";
    ctx.shadowBlur = 18;
    ctx.globalAlpha = 0.85 + Math.sin(t * 6) * 0.15;
    ctx.fillText(`${String(winner).toUpperCase()} WINS`, w / 2, h * 0.28 + 62);
    ctx.restore();
  }

  updateParticles(dt) {
    this.particles = this.particles.filter((p) => {
      p.life -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 180 * dt;
      return p.life > 0;
    });
  }

  drawParticles() {
    const { ctx } = this;
    for (const p of this.particles) {
      ctx.globalAlpha = Math.max(0, p.life / p.max);
      ctx.fillStyle = p.color;
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  celebrate(kind) {
    const w = this.w;
    const h = this.h;
    if (kind === "heal") this.spawnBurst(w * 0.34, h * 0.55, "#2ecc71", 14);
    if (kind === "gift") this.spawnBurst(w * 0.5, h * 0.4, "#ffd76a", 18);
    if (kind === "win") this.spawnBurst(w * 0.5, h * 0.35, "#d62828", 24);
  }
}
