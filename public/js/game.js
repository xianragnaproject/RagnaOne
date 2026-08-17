import {
  drawPlayer,
  drawGuard,
  drawDoll,
  drawDeathBurst,
  drawMuzzleFlash,
} from "./sprites.js";

const ROUND_SECONDS = 120;
const GREEN_MIN = 2.2;
const GREEN_MAX = 4.5;
const RED_MIN = 1.6;
const RED_MAX = 3.2;

function rand(min, max) {
  return min + Math.random() * (max - min);
}

function clamp(v, a, b) {
  return Math.max(a, Math.min(b, v));
}

function formatTime(sec) {
  const s = Math.max(0, Math.ceil(sec));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${String(m).padStart(2, "0")}:${String(r).padStart(2, "0")}`;
}

function shortName(name) {
  const n = String(name || "player");
  return n.length > 10 ? `${n.slice(0, 9)}…` : n;
}

export class Game {
  constructor(canvas, ui) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d");
    this.ui = ui;
    this.w = canvas.width;
    this.h = canvas.height;

    this.players = [];
    this.guards = [];
    this.fx = [];
    this.kills = new Map();
    this.frame = 0;
    this.timeLeft = ROUND_SECONDS;
    this.phase = "green"; // green | red
    this.phaseTimer = rand(GREEN_MIN, GREEN_MAX);
    this.running = true;
    this.finishY = 150;
    this.lineY = 0;
    this.spawnY = 0;
    this.dollLookingBack = false;
    this._layout();

    this._seedGuards();
    this._bindResize();
    this._last = performance.now();
    requestAnimationFrame((t) => this._loop(t));
  }

  _bindResize() {
    const sync = () => {
      // Keep internal resolution; CSS scales the canvas
      this._layout();
    };
    window.addEventListener("resize", sync);
  }

  _layout() {
    this.lineY = Math.floor(this.h * 0.58);
    this.spawnY = Math.floor(this.h * 0.86);
    this.finishY = Math.floor(this.h * 0.22);
  }

  _seedGuards() {
    this.guards = [
      { x: this.w * 0.18, y: this.h * 0.34, frame: 0, shootT: 0 },
      { x: this.w * 0.82, y: this.h * 0.34, frame: 20, shootT: 0 },
      { x: this.w * 0.3, y: this.h * 0.28, frame: 40, shootT: 0 },
      { x: this.w * 0.7, y: this.h * 0.28, frame: 60, shootT: 0 },
    ];
  }

  resetRound() {
    clearTimeout(this._nextRoundTimer);
    this.players = [];
    this.fx = [];
    this.kills.clear();
    this.timeLeft = ROUND_SECONDS;
    this.phase = "green";
    this.phaseTimer = rand(GREEN_MIN, GREEN_MAX);
    this.dollLookingBack = false;
    this.running = true;
    this._seedGuards();
    this.ui.setLeaderboard([]);
    this.ui.setPhase("green");
    this.ui.setTimer(formatTime(this.timeLeft));
    this.ui.toast("New round — send Rose to join!");
  }

  addKill(username, amount = 1) {
    const key = username || "unknown";
    this.kills.set(key, (this.kills.get(key) || 0) + amount);
    this._refreshLeaderboard();
  }

  _refreshLeaderboard() {
    const ranked = [...this.kills.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([name, score]) => ({ name, score }));
    this.ui.setLeaderboard(ranked);
  }

  handleGift({ action, username, nickname, repeatCount = 1 }) {
    const name = nickname || username || "viewer";
    switch (action) {
      case "join":
        this.spawnPlayer(name, 1);
        this.ui.toast(`${shortName(name)} joined (+1 life)`);
        break;
      case "clones":
        this.spawnClones(name, 5);
        this.ui.toast(`${shortName(name)} spawned 5 clones`);
        break;
      case "kill1":
        this.killPlayers(name, 1 * (repeatCount || 1));
        break;
      case "kills5":
        this.killPlayers(name, 5);
        break;
      case "kills15":
        this.killPlayers(name, 15);
        break;
      case "killAll":
        this.killPlayers(name, this.players.length);
        this.ui.toast(`${shortName(name)} wiped the field!`);
        break;
      default:
        break;
    }
  }

  spawnPlayer(name, lives = 1) {
    const existing = this.players.filter((p) => p.name === name && p.alive);
    if (existing.length >= 12) {
      existing[0].lives += lives;
      return;
    }
    const x = rand(this.w * 0.18, this.w * 0.82);
    this.players.push({
      id: `${name}-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      name,
      x,
      y: this.spawnY + rand(-10, 10),
      vx: 0,
      vy: 0,
      lives,
      alive: true,
      speed: rand(28, 46),
      jitter: rand(0, Math.PI * 2),
      frame: Math.floor(rand(0, 40)),
      moving: false,
      won: false,
    });
  }

  spawnClones(name, count) {
    for (let i = 0; i < count; i++) this.spawnPlayer(name, 1);
  }

  killPlayers(killerName, count) {
    const victims = this.players.filter((p) => p.alive && !p.won);
    if (!victims.length) {
      this.ui.toast("No players to eliminate");
      return;
    }
    const n = Math.min(count, victims.length);
    // Prefer players who crossed the red line (in danger zone)
    victims.sort((a, b) => {
      const az = a.y < this.lineY ? 0 : 1;
      const bz = b.y < this.lineY ? 0 : 1;
      return az - bz || Math.random() - 0.5;
    });

    let killed = 0;
    for (let i = 0; i < n; i++) {
      if (this._eliminate(victims[i], true)) killed += 1;
    }
    if (killed > 0) {
      this.addKill(killerName, killed);
      this.ui.toast(`${shortName(killerName)} +${killed} kill${killed > 1 ? "s" : ""}`);
      this._guardShoot();
    }
  }

  _eliminate(player, fromGift = false) {
    if (!player?.alive) return false;
    player.lives -= 1;
    if (player.lives > 0) {
      // bounce back to spawn with remaining life
      player.y = this.spawnY;
      player.x = clamp(player.x + rand(-40, 40), this.w * 0.15, this.w * 0.85);
      player.moving = false;
      this.fx.push({ type: "burst", x: player.x, y: player.y, life: 1 });
      return false;
    }
    player.alive = false;
    this.fx.push({ type: "burst", x: player.x, y: player.y, life: 1 });
    if (!fromGift) {
      // environment kill — credit goes to "TEMPLE"
      this.addKill("TEMPLE", 1);
    }
    return true;
  }

  _guardShoot() {
    for (const g of this.guards) g.shootT = 0.35;
    this.fx.push({
      type: "flash",
      x: this.guards[0]?.x + 20 || 100,
      y: this.guards[0]?.y || 100,
      life: 1,
    });
  }

  _setPhase(next) {
    this.phase = next;
    this.dollLookingBack = next === "red";
    this.phaseTimer = next === "green" ? rand(GREEN_MIN, GREEN_MAX) : rand(RED_MIN, RED_MAX);
    this.ui.setPhase(next);
    if (next === "red") {
      // Anyone still moving when lights turn red gets checked continuously
      this.ui.toast("RED LIGHT");
    } else {
      this.ui.toast("GREEN LIGHT");
    }
  }

  _update(dt) {
    if (!this.running) return;
    this.frame += 1;
    this.timeLeft -= dt;
    this.ui.setTimer(formatTime(this.timeLeft));
    if (this.timeLeft <= 0) {
      if (this.running) {
        this.running = false;
        this.ui.toast("Round over — starting next…");
        clearTimeout(this._nextRoundTimer);
        this._nextRoundTimer = setTimeout(() => {
          if (!this.running) this.resetRound();
        }, 2500);
      }
      return;
    }

    this.phaseTimer -= dt;
    if (this.phaseTimer <= 0) {
      this._setPhase(this.phase === "green" ? "red" : "green");
    }

    for (const g of this.guards) {
      g.frame += 1;
      g.shootT = Math.max(0, g.shootT - dt);
      g.x += Math.sin((this.frame + g.frame) * 0.01) * 0.15;
    }

    for (const p of this.players) {
      if (!p.alive || p.won) continue;
      p.frame += 1;

      if (this.phase === "green") {
        // Move toward the doll / finish line
        const targetX = this.w * 0.5 + Math.sin(p.jitter + this.frame * 0.01) * 80;
        const dx = targetX - p.x;
        p.vx = clamp(dx * 0.8, -30, 30);
        p.vy = -p.speed;
        p.moving = true;
        // occasional hesitant stop
        if (Math.random() < 0.002) p.vy *= 0.2;
      } else {
        // Red light — try to freeze; some keep drifting (punished)
        const slip = Math.random() < 0.004;
        if (slip && p.y < this.lineY) {
          p.vx = rand(-12, 12);
          p.vy = rand(-8, 4);
          p.moving = true;
        } else {
          p.vx *= 0.7;
          p.vy *= 0.7;
          if (Math.abs(p.vx) < 1 && Math.abs(p.vy) < 1) {
            p.vx = 0;
            p.vy = 0;
            p.moving = false;
          }
        }

        if (p.moving && p.y < this.lineY - 4) {
          this._eliminate(p, false);
          this._guardShoot();
          continue;
        }
      }

      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.x = clamp(p.x, 40, this.w - 40);
      p.y = clamp(p.y, this.finishY - 10, this.spawnY + 20);

      if (p.y <= this.finishY + 8) {
        p.won = true;
        p.moving = false;
        p.y = this.finishY;
        this.ui.toast(`${shortName(p.name)} reached the temple!`);
      }
    }

    // cleanup dead after a while is unnecessary; keep corpses briefly by filtering
    this.players = this.players.filter((p) => p.alive || p._deadT === undefined);
    for (const p of this.players) {
      if (!p.alive) {
        p._deadT = (p._deadT || 0) + dt;
      }
    }
    this.players = this.players.filter((p) => p.alive || (p._deadT || 0) < 0.8);

    for (const f of this.fx) f.life -= dt * 2.2;
    this.fx = this.fx.filter((f) => f.life > 0);
  }

  _drawBackground() {
    const ctx = this.ctx;
    const g = ctx.createLinearGradient(0, 0, 0, this.h);
    g.addColorStop(0, "#2a3a4e");
    g.addColorStop(0.35, "#6b7f93");
    g.addColorStop(0.55, "#b8a07a");
    g.addColorStop(1, "#5a4632");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, this.w, this.h);

    // sea horizon
    const sea = ctx.createLinearGradient(0, this.h * 0.28, 0, this.h * 0.5);
    sea.addColorStop(0, "rgba(40,80,110,0)");
    sea.addColorStop(0.2, "rgba(40,90,120,0.55)");
    sea.addColorStop(1, "rgba(30,50,70,0)");
    ctx.fillStyle = sea;
    ctx.fillRect(0, this.h * 0.25, this.w, this.h * 0.28);

    // storm clouds
    ctx.fillStyle = "rgba(20,24,32,0.35)";
    for (let i = 0; i < 6; i++) {
      const cx = ((i * 240 + this.frame * 0.15) % (this.w + 200)) - 100;
      ctx.beginPath();
      ctx.ellipse(cx, 70 + (i % 3) * 18, 120, 36, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    // ruined side walls
    ctx.fillStyle = "#8f8168";
    ctx.fillRect(0, this.h * 0.2, 70, this.h * 0.35);
    ctx.fillRect(this.w - 70, this.h * 0.22, 70, this.h * 0.33);
    ctx.fillStyle = "#b7a682";
    for (let i = 0; i < 4; i++) {
      ctx.fillRect(12, this.h * 0.24 + i * 48, 28, 34);
      ctx.fillRect(this.w - 40, this.h * 0.26 + i * 48, 28, 34);
    }

    // temple columns
    this._drawTemple();

    // courtyard stone floor
    const floorY = this.h * 0.48;
    ctx.fillStyle = "#9d8b6e";
    ctx.fillRect(0, floorY, this.w, this.h - floorY);

    // stone tiles
    ctx.strokeStyle = "rgba(60,40,20,0.18)";
    ctx.lineWidth = 1;
    for (let y = floorY; y < this.h; y += 36) {
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(this.w, y);
      ctx.stroke();
    }
    for (let x = 0; x < this.w; x += 48) {
      ctx.beginPath();
      ctx.moveTo(x, floorY);
      ctx.lineTo(x, this.h);
      ctx.stroke();
    }

    // red danger line
    ctx.fillStyle = "#d62839";
    ctx.fillRect(this.w * 0.08, this.lineY - 3, this.w * 0.84, 6);
    ctx.fillStyle = "rgba(255,80,80,0.25)";
    ctx.fillRect(this.w * 0.08, this.lineY - 10, this.w * 0.84, 20);

    // tree behind doll
    ctx.fillStyle = "#1a1410";
    ctx.beginPath();
    ctx.moveTo(this.w * 0.5, this.h * 0.08);
    ctx.quadraticCurveTo(this.w * 0.42, this.h * 0.2, this.w * 0.46, this.h * 0.3);
    ctx.quadraticCurveTo(this.w * 0.5, this.h * 0.22, this.w * 0.54, this.h * 0.3);
    ctx.quadraticCurveTo(this.w * 0.58, this.h * 0.2, this.w * 0.5, this.h * 0.08);
    ctx.fill();
  }

  _drawTemple() {
    const ctx = this.ctx;
    const baseY = this.h * 0.42;
    ctx.fillStyle = "#d7c7a8";
    ctx.fillRect(this.w * 0.15, baseY - 20, this.w * 0.7, 24);

    for (let i = 0; i < 7; i++) {
      const x = this.w * 0.2 + i * ((this.w * 0.6) / 6);
      ctx.fillStyle = "#e8dcc4";
      ctx.fillRect(x - 10, baseY - 150, 20, 130);
      ctx.fillStyle = "#cbb993";
      ctx.fillRect(x - 14, baseY - 156, 28, 10);
      ctx.fillRect(x - 14, baseY - 28, 28, 10);
    }

    // pediment
    ctx.fillStyle = "#efe4cf";
    ctx.beginPath();
    ctx.moveTo(this.w * 0.14, baseY - 150);
    ctx.lineTo(this.w * 0.5, baseY - 210);
    ctx.lineTo(this.w * 0.86, baseY - 150);
    ctx.closePath();
    ctx.fill();
  }

  _draw() {
    const ctx = this.ctx;
    this._drawBackground();

    // doll
    drawDoll(ctx, this.w * 0.5, this.h * 0.3, {
      lookingBack: this.dollLookingBack,
      frame: this.frame,
    });

    // sort by y for depth
    const guards = this.guards.map((g) => ({ kind: "guard", ...g }));
    const players = this.players.map((p) => ({ kind: "player", ...p }));
    const entities = [...guards, ...players].sort((a, b) => a.y - b.y);

    for (const e of entities) {
      if (e.kind === "guard") {
        drawGuard(ctx, e.x, e.y, { frame: e.frame, shooting: e.shootT > 0 });
      } else if (e.alive !== false || e.won) {
        drawPlayer(ctx, e.x, e.y, {
          moving: e.moving && !e.won,
          frame: e.frame,
        });
        // nametag
        ctx.font = "bold 12px IBM Plex Sans, sans-serif";
        ctx.textAlign = "center";
        ctx.fillStyle = "rgba(0,0,0,0.65)";
        const label = shortName(e.name);
        const tw = ctx.measureText(label).width + 12;
        ctx.fillRect(e.x - tw / 2, e.y - 42, tw, 16);
        ctx.fillStyle = "#fff";
        ctx.fillText(label, e.x, e.y - 30);
        if (e.lives > 1) {
          ctx.fillStyle = "#ff5d6c";
          ctx.fillText(`♥${e.lives}`, e.x, e.y - 48);
        }
      }
    }

    for (const f of this.fx) {
      if (f.type === "burst") drawDeathBurst(ctx, f.x, f.y, f.life);
      if (f.type === "flash") drawMuzzleFlash(ctx, f.x, f.y, f.life);
    }

    // vignette
    const vig = ctx.createRadialGradient(
      this.w / 2,
      this.h / 2,
      this.h * 0.2,
      this.w / 2,
      this.h / 2,
      this.h * 0.78
    );
    vig.addColorStop(0, "rgba(0,0,0,0)");
    vig.addColorStop(1, "rgba(0,0,0,0.35)");
    ctx.fillStyle = vig;
    ctx.fillRect(0, 0, this.w, this.h);
  }

  _loop(t) {
    const dt = Math.min(0.05, (t - this._last) / 1000);
    this._last = t;
    this._update(dt);
    this._draw();
    requestAnimationFrame((nt) => this._loop(nt));
  }
}
