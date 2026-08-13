export class Queue {
  constructor() {
    this.entries = []; // { id, name, joinedAt, source }
  }

  has(userId) {
    return this.entries.some((e) => e.id === userId);
  }

  add(user, source = "chat") {
    if (!user?.id || !user?.name) return { ok: false, reason: "invalid" };
    if (this.has(user.id)) return { ok: false, reason: "already_queued" };
    const entry = {
      id: user.id,
      name: user.name,
      joinedAt: Date.now(),
      source,
    };
    this.entries.push(entry);
    return { ok: true, entry, position: this.entries.length };
  }

  next() {
    return this.entries.shift() || null;
  }

  peek(n = 5) {
    return this.entries.slice(0, n);
  }

  size() {
    return this.entries.length;
  }

  remove(userId) {
    const i = this.entries.findIndex((e) => e.id === userId);
    if (i >= 0) this.entries.splice(i, 1);
  }

  clear() {
    this.entries = [];
  }
}
