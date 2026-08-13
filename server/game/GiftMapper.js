/**
 * Maps TikTok gifts / engagement to in-game actions.
 * Coin values mirror common TikTok gift tiers used in live gift games.
 */
export const DEFAULT_GIFT_MAP = [
  { coins: 1, action: "heal", amount: 25, label: "25 Heal", icon: "♥" },
  { coins: 10, action: "weapon", weapon: "stick", label: "Stick", icon: "/" },
  { coins: 50, action: "heal", amount: 255, label: "255 Heal", icon: "♥" },
  { coins: 100, action: "heal", amount: 325, label: "325 Heal", icon: "♥" },
  { coins: 1000, action: "heal", amount: 1000, label: "1K Heal", icon: "♥" },
];

export const JOIN_RULES = {
  chatKeyword: "join",
  likesRequired: 30,
};

/** Pick the best matching gift action for a diamond/coin cost. */
export function resolveGiftAction(diamondCount, map = DEFAULT_GIFT_MAP) {
  const sorted = [...map].sort((a, b) => b.coins - a.coins);
  const match = sorted.find((g) => diamondCount >= g.coins);
  return match || null;
}

/** Normalize gift names that streamers often remap in TikTok Studio. */
export function resolveGiftByName(giftName, map = DEFAULT_GIFT_MAP) {
  const name = String(giftName || "").toLowerCase();
  if (name.includes("rose") || name.includes("heart")) {
    return map.find((g) => g.coins === 1) || null;
  }
  if (name.includes("finger") || name.includes("heart me")) {
    return map.find((g) => g.coins === 5) || map.find((g) => g.coins === 1) || null;
  }
  if (name.includes("gg") || name.includes("drama") || name.includes("stick")) {
    return map.find((g) => g.action === "weapon") || null;
  }
  if (name.includes("doughnut") || name.includes("donut") || name.includes("ice cream")) {
    return map.find((g) => g.coins === 50) || null;
  }
  if (name.includes("perfume") || name.includes("corgi") || name.includes("money gun")) {
    return map.find((g) => g.coins === 100) || null;
  }
  if (name.includes("lion") || name.includes("universe") || name.includes("tiktok universe")) {
    return map.find((g) => g.coins === 1000) || null;
  }
  return null;
}
