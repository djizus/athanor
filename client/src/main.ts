import { mountApp } from "./ui/router.js";

const root = document.getElementById("app");
if (!root) {
  throw new Error("#app root not found");
}
mountApp(root);
