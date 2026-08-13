import { Fighter } from "./Fighter.js";
import { Queue } from "./Queue.js";
import {
  DEFAULT_GIFT_MAP,
  JOIN_RULES,
  resolveGiftAction,
  resolveGiftByName,
} from "./GiftMapper.js";

const CHAMPION_ID = "champion";

export class GameEngine {
  constructor({ onState, onEvent } = {}) {
    this.onState = onState || (() => {});
    this.onEvent = onEvent || (() => {});
    this.giftMap = DEFAULT_GIFT_MAP;
    this.joinRules = { ...JOIN_RULES };
    this.queue = new Queue();
    this.likeProgress = new Map(); // userId -> count
    this.events = [];
    this.matchId = 0;
    this.phase = "waiting"; // waiting | fighting | result
    this.phaseUntil = 0;
    this.nextMatchLabel = "WAITING FOR FIGHTERS";
    this.champion = new Fighter({
      id: CHAMPION_ID,
      name: "HOUSE",
      side: "right",
      maxHp: 600,
    });
    this.challenger = null;
    this.lastHitAt = 0;
    this.hitIntervalMs = 900;
    this.resultHoldMs = 3200;
    this.broadcastSoon();
  }

  broadcastSoon() {
    clearTimeout(this._broadcastTimer);
    this._broadcastTimer = setTimeout(() => this.broadcast(), 16);
  }

  broadcast() {
    this.onState(this.getState());
  }

  pushEvent(evt) {
    const full = { id: `${Date.now()}-${Math.random()}`, t: Date.now(), ...evt };
    this.events.unshift(full);
    this.events = this.events.slice(0, 40);
    this.onEvent(full);
    this.broadcastSoon();
  }

  getState() {
    const next = this.queue.peek(1)[0];
    return {
      phase: this.phase,
      matchId: this.matchId,
      nextMatchLabel: this.nextMatchLabel,
      giftMap: this.giftMap,
      joinRules: this.joinRules,
      queue: this.queue.peek(8),
      queueSize: this.queue.size(),
      champion: this.champion.toPublic(),
      challenger: this.challenger ? this.challenger.toPublic() : null,
      nextUp: next || null,
      events: this.events.slice(0, 12),
      likeProgress: Object.fromEntries(
        [...this.likeProgress.entries()].slice(0, 20)
      ),
    };
  }

  startLoop() {
    if (this._loop) return;
    this._loop = setInterval(() => this.tick(), 100);
  }

  stopLoop() {
    clearInterval(this._loop);
    this._loop = null;
  }

  tick() {
    const now = Date.now();
    this.champion.tickAnim(now);
    if (this.challenger) this.challenger.tickAnim(now);

    if (this.phase === "waiting") {
      this.tryStartMatch();
    } else if (this.phase === "fighting") {
      this.tickCombat(now);
    } else if (this.phase === "result" && now >= this.phaseUntil) {
      this.phase = "waiting";
      this.challenger = null;
      this.updateNextLabel();
      this.broadcastSoon();
    }
  }

  updateNextLabel() {
    const next = this.queue.peek(1)[0];
    if (next) {
      this.nextMatchLabel = `NEXT MATCH: ${next.name.toUpperCase()} VS ${this.champion.name.toUpperCase()}`;
    } else if (this.phase === "fighting" && this.challenger) {
      this.nextMatchLabel = `${this.challenger.name.toUpperCase()} VS ${this.champion.name.toUpperCase()}`;
    } else {
      this.nextMatchLabel = "WAITING FOR FIGHTERS — TYPE JOIN";
    }
  }

  tryStartMatch() {
    if (this.challenger) return;
    const next = this.queue.next();
    if (!next) {
      this.updateNextLabel();
      return;
    }

    this.matchId += 1;
    this.challenger = new Fighter({
      id: next.id,
      name: next.name,
      side: "left",
      maxHp: 500,
    });
    // Soft reset house champion between matches but keep win streak
    this.champion.hp = this.champion.maxHp;
    this.champion.alive = true;
    this.champion.weapon = null;
    this.champion.weaponHits = 0;
    this.champion.anim = "idle";

    this.phase = "fighting";
    this.lastHitAt = Date.now() + 800;
    this.updateNextLabel();
    this.pushEvent({
      type: "match_start",
      message: `${this.challenger.name} enters the ring!`,
      user: next.name,
    });
  }

  tickCombat(now) {
    if (!this.challenger || !this.challenger.alive || !this.champion.alive) {
      this.finishMatch();
      return;
    }
    if (now - this.lastHitAt < this.hitIntervalMs) return;
    this.lastHitAt = now;

    // Alternate attacks with a bit of chaos; weapons hit harder
    const attacker =
      Math.random() > 0.48 ? this.challenger : this.champion;
    const defender = attacker === this.challenger ? this.champion : this.challenger;

    let dmg = 18 + Math.floor(Math.random() * 22);
    if (attacker.weapon === "stick") {
      dmg += 28 + Math.floor(Math.random() * 18);
      attacker.weaponHits -= 1;
      if (attacker.weaponHits <= 0) attacker.weapon = null;
    }
    // Slight underdog boost when HP is low
    if (attacker.hp < attacker.maxHp * 0.3) dmg += 10;

    attacker.setAnim("attack", 260);
    defender.takeDamage(dmg);
    this.broadcastSoon();

    if (!defender.alive) this.finishMatch();
  }

  finishMatch() {
    if (this.phase !== "fighting") return;
    this.phase = "result";
    this.phaseUntil = Date.now() + this.resultHoldMs;

    let winner = null;
    let loser = null;
    if (this.challenger?.alive && !this.champion.alive) {
      winner = this.challenger;
      loser = this.champion;
      winner.wins += 1;
      // Challenger becomes the new house champion
      this.champion = new Fighter({
        id: winner.id,
        name: winner.name,
        side: "right",
        maxHp: 600,
      });
      this.champion.wins = winner.wins;
      this.champion.hp = Math.min(600, Math.max(200, winner.hp + 80));
    } else if (this.champion.alive) {
      winner = this.champion;
      loser = this.challenger;
      this.champion.wins += 1;
    } else {
      // Rare double KO — champion keeps the belt
      winner = this.champion;
      loser = this.challenger;
      this.champion.hp = Math.floor(this.champion.maxHp * 0.4);
      this.champion.alive = true;
      this.champion.wins += 1;
    }

    this.pushEvent({
      type: "match_end",
      message: `${winner?.name || "?"} wins!`,
      user: winner?.name,
      winner: winner?.name,
      loser: loser?.name,
    });
    this.updateNextLabel();
  }

  // --- Live event handlers ---

  handleChat({ userId, uniqueId, nickname, comment }) {
    const name = nickname || uniqueId || "Viewer";
    const id = String(userId || uniqueId || name);
    const text = String(comment || "").trim().toLowerCase();
    this.pushEvent({
      type: "chat",
      message: comment,
      user: name,
    });

    if (text === this.joinRules.chatKeyword || text.startsWith("join")) {
      this.enqueueFighter({ id, name }, "chat");
    }
  }

  handleLike({ userId, uniqueId, nickname, likeCount = 1 }) {
    const name = nickname || uniqueId || "Viewer";
    const id = String(userId || uniqueId || name);
    const prev = this.likeProgress.get(id) || 0;
    const next = prev + (likeCount || 1);
    this.likeProgress.set(id, next);

    if (prev < this.joinRules.likesRequired && next >= this.joinRules.likesRequired) {
      this.enqueueFighter({ id, name }, "likes");
      this.likeProgress.set(id, 0);
    }
    this.broadcastSoon();
  }

  handleGift({ userId, uniqueId, nickname, giftName, diamondCount, repeatCount = 1 }) {
    const name = nickname || uniqueId || "Viewer";
    const id = String(userId || uniqueId || name);
    const diamonds = Number(diamondCount) || 0;
    const action =
      resolveGiftByName(giftName) || resolveGiftAction(diamonds) || null;

    this.pushEvent({
      type: "gift",
      message: `${name} sent ${giftName || "gift"} (x${repeatCount})`,
      user: name,
      giftName,
      diamonds,
      action,
    });

    if (!action) return;

    // Apply to the fighter matching the gifter if in ring, else challenger, else champion
    const target = this.pickGiftTarget(id);
    if (!target) return;

    if (action.action === "heal") {
      const healed = target.heal(action.amount * Math.max(1, repeatCount));
      this.pushEvent({
        type: "effect",
        message: `+${healed} HP to ${target.name}`,
        user: name,
      });
    } else if (action.action === "weapon") {
      target.giveWeapon(action.weapon || "stick", 8 * Math.max(1, repeatCount));
      this.pushEvent({
        type: "effect",
        message: `${target.name} got a ${action.weapon || "stick"}!`,
        user: name,
      });
    }
    this.broadcastSoon();
  }

  pickGiftTarget(gifterId) {
    if (this.challenger && this.challenger.id === gifterId && this.challenger.alive) {
      return this.challenger;
    }
    if (this.champion.id === gifterId && this.champion.alive) {
      return this.champion;
    }
    if (this.challenger?.alive) return this.challenger;
    if (this.champion.alive) return this.champion;
    return null;
  }

  enqueueFighter(user, source) {
    // Don't queue if already fighting
    if (this.challenger?.id === user.id || this.champion.id === user.id) {
      this.pushEvent({
        type: "join_denied",
        message: `${user.name} is already in the ring`,
        user: user.name,
      });
      return;
    }
    const result = this.queue.add(user, source);
    if (!result.ok) {
      this.pushEvent({
        type: "join_denied",
        message: `${user.name} is already queued`,
        user: user.name,
      });
      return;
    }
    this.updateNextLabel();
    this.pushEvent({
      type: "join",
      message: `${user.name} joined via ${source} (#${result.position})`,
      user: user.name,
      source,
      position: result.position,
    });
  }

  /** Manual / demo helpers */
  simulateJoin(name, source = "demo") {
    const id = `demo-${name.toLowerCase().replace(/\s+/g, "-")}-${Date.now()}`;
    this.enqueueFighter({ id, name }, source);
  }

  simulateGift(name, coins, giftName = "Gift") {
    this.handleGift({
      userId: `sim-${name}`,
      nickname: name,
      giftName,
      diamondCount: coins,
      repeatCount: 1,
    });
  }

  resetChampion(name = "HOUSE") {
    this.champion = new Fighter({
      id: CHAMPION_ID,
      name,
      side: "right",
      maxHp: 600,
    });
    this.challenger = null;
    this.phase = "waiting";
    this.queue.clear();
    this.updateNextLabel();
    this.broadcastSoon();
  }
}
