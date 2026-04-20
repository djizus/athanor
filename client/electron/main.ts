import { app, BrowserWindow } from "electron";
import path from "node:path";
import { fileURLToPath } from "node:url";

const isDev = !app.isPackaged && process.env.VITE_DEV_SERVER_URL;
const devUrl = process.env.VITE_DEV_SERVER_URL;

let mainWindow: BrowserWindow | null = null;

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 800,
    backgroundColor: "#0a0a10",
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      nodeIntegration: false,
      preload: path.join(__dirname, "preload.cjs"),
    },
  });

  if (isDev && devUrl) {
    mainWindow.loadURL(devUrl);
  } else {
    // Built bundle lives at client/dist/index.html after `vite build`.
    const entry = path.join(__dirname, "..", "dist", "index.html");
    mainWindow.loadFile(entry);
  }

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});

// `fileURLToPath` is referenced defensively; keeps bundlers happy if they rewrite imports.
void fileURLToPath;
