export class Fighter {
  constructor({ id, name, side = "left", maxHp = 500 }) {
    this.id = id;
    this.name = name;
    this.side = side;
    this.maxHp = maxHp;
    this.hp = maxHp;
    this.wins = 0;
    this.weapon = null; // null | "stick"
    this.weaponHits = 0;
    this.alive = true;
    this.anim = "idle";
    this.animUntil = 0;
    this.combo = 0;
    this.color = side === "left" ? "#f5f5f5" : "#ffe566";
  }

  heal(amount) {
    if (!this.alive) return 0;
    const before = this.hp;
    this.hp = Math.min(this.maxHp, this.hp + amount);
    this.setAnim("heal", 400);
    return this.hp - before;
  }

  giveWeapon(weapon = "stick", hits = 8) {
    this.weapon = weapon;
    this.weaponHits = hits;
    this.setAnim("power", 500);
  }

  takeDamage(amount) {
    if (!this.alive) return 0;
    const before = this.hp;
    this.hp = Math.max(0, this.hp - amount);
    this.setAnim("hurt", 280);
    if (this.hp <= 0) {
      this.alive = false;
      this.setAnim("ko", 2000);
    }
    return before - this.hp;
  }

  setAnim(name, durationMs) {
    this.anim = name;
    this.animUntil = Date.now() + durationMs;
  }

  tickAnim(now = Date.now()) {
    if (this.anim !== "idle" && this.anim !== "ko" && now >= this.animUntil) {
      this.anim = this.alive ? "idle" : "ko";
    }
  }

  toPublic() {
    return {
      id: this.id,
      name: this.name,
      side: this.side,
      hp: this.hp,
      maxHp: this.maxHp,
      wins: this.wins,
      weapon: this.weapon,
      weaponHits: this.weaponHits,
      alive: this.alive,
      anim: this.anim,
      color: this.color,
    };
  }
}
