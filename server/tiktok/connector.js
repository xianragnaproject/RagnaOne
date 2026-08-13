import { WebcastPushConnection } from "tiktok-live-connector";

/**
 * Thin wrapper around tiktok-live-connector.
 * Emits normalized events the game engine understands.
 */
export class TikTokBridge {
  constructor({ username, onChat, onGift, onLike, onStatus }) {
    this.username = username;
    this.onChat = onChat || (() => {});
    this.onGift = onGift || (() => {});
    this.onLike = onLike || (() => {});
    this.onStatus = onStatus || (() => {});
    this.connection = null;
    this.connected = false;
  }

  async connect() {
    if (!this.username) {
      this.onStatus({ connected: false, reason: "no_username" });
      return { ok: false, reason: "no_username" };
    }

    await this.disconnect();

    this.connection = new WebcastPushConnection(this.username, {
      processInitialData: false,
      enableExtendedGiftInfo: true,
    });

    this.connection.on("chat", (data) => {
      this.onChat({
        userId: data.userId,
        uniqueId: data.uniqueId,
        nickname: data.nickname,
        comment: data.comment,
      });
    });

    this.connection.on("gift", (data) => {
      // Skip gift streaks mid-combo; apply on end or non-streak gifts
      if (data.giftType === 1 && !data.repeatEnd) return;
      this.onGift({
        userId: data.userId,
        uniqueId: data.uniqueId,
        nickname: data.nickname,
        giftName: data.giftName,
        diamondCount: data.diamondCount,
        repeatCount: data.repeatCount || 1,
      });
    });

    this.connection.on("like", (data) => {
      this.onLike({
        userId: data.userId,
        uniqueId: data.uniqueId,
        nickname: data.nickname,
        likeCount: data.likeCount || 1,
      });
    });

    this.connection.on("disconnected", () => {
      this.connected = false;
      this.onStatus({ connected: false, reason: "disconnected" });
    });

    this.connection.on("streamEnd", () => {
      this.connected = false;
      this.onStatus({ connected: false, reason: "stream_end" });
    });

    try {
      const state = await this.connection.connect();
      this.connected = true;
      this.onStatus({
        connected: true,
        roomId: state.roomId,
        viewerCount: state.viewerCount,
        username: this.username,
      });
      return { ok: true, state };
    } catch (err) {
      this.connected = false;
      this.onStatus({
        connected: false,
        reason: "connect_failed",
        error: err?.message || String(err),
      });
      return { ok: false, error: err?.message || String(err) };
    }
  }

  async disconnect() {
    if (this.connection) {
      try {
        this.connection.disconnect();
      } catch {
        /* ignore */
      }
      this.connection = null;
    }
    this.connected = false;
  }
}
