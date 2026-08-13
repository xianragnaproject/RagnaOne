const DEMO_NAMES = [
  "Denver4E",
  "Shan",
  "VelvetFan",
  "RingKing",
  "PixelPunch",
  "GlowStick",
  "NightOwl",
  "Kai",
  "Mira",
  "Jax",
  "Nova",
  "Leo",
];

const DEMO_GIFTS = [
  { name: "Rose", coins: 1 },
  { name: "TikTok", coins: 1 },
  { name: "Finger Heart", coins: 5 },
  { name: "GG", coins: 10 },
  { name: "Doughnut", coins: 30 },
  { name: "Corgi", coins: 100 },
  { name: "Lion", coins: 1000 },
];

/**
 * Generates fake TikTok Live events so you can develop & demo without going live.
 */
export class DemoSimulator {
  constructor(engine) {
    this.engine = engine;
    this.timer = null;
    this.running = false;
    this.tickMs = 2200;
    this.nameIdx = 0;
  }

  start() {
    if (this.running) return;
    this.running = true;
    // Seed a few fighters so the ring isn't empty
    this.engine.simulateJoin("Denver4E", "demo");
    this.engine.simulateJoin("Shan", "demo");
    this.engine.simulateJoin("VelvetFan", "demo");
    this.timer = setInterval(() => this.tick(), this.tickMs);
  }

  stop() {
    this.running = false;
    clearInterval(this.timer);
    this.timer = null;
  }

  nextName() {
    const name = DEMO_NAMES[this.nameIdx % DEMO_NAMES.length];
    this.nameIdx += 1;
    return name;
  }

  tick() {
    const roll = Math.random();
    if (roll < 0.35) {
      this.engine.simulateJoin(this.nextName(), "chat");
    } else if (roll < 0.55) {
      const name = this.nextName();
      this.engine.handleLike({
        userId: `like-${name}`,
        nickname: name,
        likeCount: 8 + Math.floor(Math.random() * 25),
      });
    } else if (roll < 0.9) {
      const gift = DEMO_GIFTS[Math.floor(Math.random() * DEMO_GIFTS.length)];
      // Prefer gifting for current challenger when fighting
      const targetName =
        this.engine.challenger?.name || this.nextName();
      this.engine.simulateGift(targetName, gift.coins, gift.name);
    } else {
      this.engine.handleChat({
        userId: `chat-${Date.now()}`,
        nickname: this.nextName(),
        comment: Math.random() > 0.5 ? "join" : "LET'S GOOO",
      });
    }
  }
}
