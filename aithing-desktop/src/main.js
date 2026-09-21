import { load } from "@tauri-apps/plugin-store";
import { APIError } from "@typesafe-ai/sdk";
import { createClient } from "./typesafe.js";

const SAMPLE_STATE = "I was charged twice. Please fix this ASAP.";
const SAMPLE_INPUT = {
  category: {
    type: "choice",
    instructions: "What is this ticket about?",
    criteria: { billing: null, technical: null, other: null },
  },
  urgent: {
    type: "noul",
    instructions: "Is the customer asking for urgent help?",
  },
};

const $ = (id) => document.getElementById(id);
const apiKeyEl = $("api-key");
const stateEl = $("state");
const inputEl = $("input");
const outputEl = $("output");
const runEl = $("run");
const statusEl = $("status");

const store = await load("settings.json");

function setStatus(text, isError = false) {
  statusEl.textContent = text;
  statusEl.classList.toggle("error", isError);
}

/** Parse state as JSON when it looks like JSON, otherwise send it as text. */
function parseState(text) {
  const trimmed = text.trim();
  if (trimmed === "") return null;
  if (/^[[{]/.test(trimmed)) return JSON.parse(trimmed);
  return text;
}

async function run() {
  const apiKey = apiKeyEl.value.trim();
  if (!apiKey) return setStatus("Enter an API key", true);

  let state, questions;
  try {
    state = parseState(stateEl.value);
  } catch (e) {
    return setStatus(`State is not valid JSON: ${e.message}`, true);
  }
  try {
    questions = JSON.parse(inputEl.value);
  } catch (e) {
    return setStatus(`Input is not valid JSON: ${e.message}`, true);
  }

  runEl.disabled = true;
  setStatus("Running…");
  const started = performance.now();
  try {
    const result = await createClient(apiKey).systemOne({ state, questions });
    outputEl.value = JSON.stringify(result, null, 2);
    setStatus(`${result.model} · ${Math.round(performance.now() - started)} ms`);
  } catch (e) {
    outputEl.value = e instanceof APIError ? JSON.stringify(e.body, null, 2) ?? "" : "";
    setStatus(e.message, true);
  } finally {
    runEl.disabled = false;
  }
}

apiKeyEl.value = (await store.get("apiKey")) ?? "";
stateEl.value = (await store.get("state")) ?? SAMPLE_STATE;
inputEl.value = (await store.get("input")) ?? JSON.stringify(SAMPLE_INPUT, null, 2);

for (const [el, key] of [
  [apiKeyEl, "apiKey"],
  [stateEl, "state"],
  [inputEl, "input"],
]) {
  el.addEventListener("change", () => store.set(key, el.value));
}

runEl.addEventListener("click", run);
document.addEventListener("keydown", (e) => {
  if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) run();
});
