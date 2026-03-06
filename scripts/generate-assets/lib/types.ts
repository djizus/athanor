export interface ImageAssetDef {
  id: string;
  filename: string;
  category: 'backgrounds' | 'heroes' | 'ingredients' | 'potions';
  width: number;
  height: number;
  description: string;
  zoneColor?: string;
  stripWhite?: boolean;
}

export interface SfxAssetDef {
  id: string;
  filename: string;
  duration: number;
  prompt: string;
}

export interface AssetManifest {
  backgrounds: ImageAssetDef[];
  heroes: ImageAssetDef[];
  ingredients: ImageAssetDef[];
  potions: ImageAssetDef[];
}

export const IMAGE_CATEGORIES = [
  'backgrounds',
  'heroes',
  'ingredients',
  'potions',
] as const;

export type ImageCategory = (typeof IMAGE_CATEGORIES)[number];
