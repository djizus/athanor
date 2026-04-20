// Kept minimal — we do not expose Node to the renderer. The browser build runs
// identically to the Electron build today. Extend via contextBridge.exposeInMainWorld
// when the renderer needs filesystem or IPC capabilities (e.g. persisted runs).

export {};
