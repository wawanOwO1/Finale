// Market Street palette: warm orange + cream, red accent (GDD §7.1).
// Every color in the scene comes from here so the limited palette stays consistent.
export const PALETTE = {
  background: 0xf3d9b1,
  floor: 0xe8b77a,
  stage: 0xf6e7c8,
  stageTrim: 0xd9822b,
  counter: 0xc8642a,
  counterTop: 0xfaf0dc,
  accent: 0xd8342c,
  crowd: 0xb5703a,
  player: 0x2f6f8f,
  rival: 0x8f2f2f,
  skin: 0xf2c7a0,
  plate: 0xffffff,
} as const;

/** Placeholder ingredient colors on the Plate, by tag. */
export const TAG_COLORS: Record<string, number> = {
  PROTEIN: 0xf6d36b,
  CARB: 0xd9a35b,
  VEGGIE: 0xd8342c,
  FAT: 0xfff1a8,
  DAIRY: 0xfafafa,
  SPICE: 0xb8261f,
  SAUCE: 0x8a3b1e,
};
