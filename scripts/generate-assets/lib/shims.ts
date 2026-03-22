declare module "fs/promises" {
  export const mkdir: any;
  export const readFile: any;
  export const writeFile: any;
  export const access: any;
  export const copyFile: any;
}

declare module "fs" {
  export const constants: any;
}

declare module "path" {
  export const resolve: any;
  export const dirname: any;
}

declare module "url" {
  export const fileURLToPath: any;
}

declare module "dotenv" {
  const dotenv: { config: (options?: any) => any };
  export default dotenv;
}

declare module "sharp" {
  const sharp: any;
  export default sharp;
}

declare module "@fal-ai/client" {
  export function config(options: any): void;
  export function subscribe(model: string, options: any): Promise<any>;
  export const storage: { upload: (input: any) => Promise<string> };
}

declare const process: any;
declare const Buffer: any;
type Buffer = any;
