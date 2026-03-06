export interface ImageAssetDef {
  id: string;
  filename: string;
  category: 'backgrounds' | 'heroes' | 'ingredients' | 'potions' | 'branding';
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
  branding: ImageAssetDef[];
}

export const IMAGE_CATEGORIES = [
  'backgrounds',
  'heroes',
  'ingredients',
  'potions',
  'branding',
] as const;

export type ImageCategory = (typeof IMAGE_CATEGORIES)[number];

export interface LayerJobDef {
  id: string;
  source: string;
  numLayers: number;
  outputDir: string;
  outputPrefix: string;
  width: number;
  height: number;
}

export interface VideoJobDef {
  id: string;
  source: string;
  filename: string;
  outputDir: string;
  width: number;
  height: number;
  fps: number;
  numFrames: number;
  format: 'webm' | 'gif' | 'mp4';
  prompt: string;
  cameraLora: string;
}
