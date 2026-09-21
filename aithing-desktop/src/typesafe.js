import { TypeSafeClient } from "@typesafe-ai/sdk";
import { fetch as tauriFetch } from "@tauri-apps/plugin-http";

export const DEFAULT_MODEL = "jev-latest";

/**
 * Create a TypeSafe client for use inside the Tauri webview.
 *
 * Requests go through the Rust HTTP plugin so they aren't subject to webview CORS.
 * The key is the user's own and stays on their machine, so browser mode is allowed.
 */
export function createClient(apiKey) {
  return new TypeSafeClient({
    apiKey,
    defaultModel: DEFAULT_MODEL,
    dangerouslyAllowBrowser: true,
    fetch: (input, init) => tauriFetch(input, init),
  });
}
