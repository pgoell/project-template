import { BrowserHost } from "@effect/ui/html";
import { Effect, Layer } from "effect";
import { Counter } from "./Counter.ts";

const root = document.getElementById("app");
if (root === null) throw new Error("index.html has no #app element");

Layer.launch(BrowserHost.mount(Counter, {}, root)).pipe(Effect.runFork);
