export type ModelCategory = "tiles" | "obstacles" | "characters";

export interface StyleData {
  suffix: string;
}

export interface TileDef {
  prompt: string;
  polycount: number;
}

export interface ObstacleDef {
  prompt: string;
  polycount: number;
}

export interface CharacterDef {
  prompt: string;
  polycount: number;
  pose?: "a-pose" | "t-pose" | "";
}

export type AssetDef = TileDef | ObstacleDef | CharacterDef;

export interface AssetJob3D {
  id: string;
  category: ModelCategory;
  prompt: string; // full prompt with style suffix already appended
  polycount: number;
  pose?: "a-pose" | "t-pose" | "";
  outputGlbPath: string;
  outputThumbPath: string;
  outputMetaPath: string;
  cacheGlbPath: string;
}

export interface CliOptions {
  category?: ModelCategory;
  only?: string[];
  previewOnly: boolean;
  postprocess: boolean;
  force: boolean;
  dryRun: boolean;
}

export interface MeshyPreviewRequest {
  mode: "preview";
  prompt: string;
  model_type: "lowpoly" | "standard";
  target_polycount?: number;
  symmetry_mode?: "off" | "auto" | "on";
  pose_mode?: "a-pose" | "t-pose" | "";
  auto_size?: boolean;
  origin_at?: "bottom" | "center";
  target_formats?: string[];
}

export interface MeshyRefineRequest {
  mode: "refine";
  preview_task_id: string;
  enable_pbr?: boolean;
  hd_texture?: boolean;
  remove_lighting?: boolean;
  target_formats?: string[];
  auto_size?: boolean;
  origin_at?: "bottom" | "center";
}

export type MeshyStatus = "PENDING" | "IN_PROGRESS" | "SUCCEEDED" | "FAILED" | "CANCELED";

export interface MeshyTaskResponse {
  id: string;
  type: string;
  status: MeshyStatus;
  progress: number;
  model_urls?: {
    glb?: string;
    fbx?: string;
    obj?: string;
    mtl?: string;
    usdz?: string;
    stl?: string;
  };
  thumbnail_url?: string;
  texture_urls?: Array<{ base_color?: string; metallic?: string; normal?: string; roughness?: string; emission?: string }>;
  task_error?: { message?: string };
  created_at?: number;
  started_at?: number;
  finished_at?: number;
}

export interface MeshyResult {
  glbBuffer: Buffer;
  thumbBuffer?: Buffer;
  previewTaskId: string;
  refineTaskId?: string;
}

export interface AssetMetadata {
  id: string;
  category: ModelCategory;
  prompt: string;
  polycount_target: number;
  pose?: string;
  provider: "meshy";
  preview_task_id: string;
  refine_task_id?: string;
  generated_at: string;
  glb_bytes: number;
  thumb_path?: string;
  postprocessed: boolean;
}

// Internal types for the concurrency limiter fallback
export type LimitRunner = <T>(task: () => Promise<T>) => Promise<T>;
export type PLimitFactory = (concurrency: number) => LimitRunner;
