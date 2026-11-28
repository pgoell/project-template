import { Story } from "@effect/ui/testing";
import { assert, describe, it } from "@effect/vitest";
import { Effect } from "effect";
import { Counter, CounterMessage } from "./Counter.ts";

describe("Counter", () => {
  it.effect("counts up and down", () =>
    Effect.gen(function* () {
      const story = yield* Story.make(Counter, {});
      story.send(CounterMessage.ClickedIncrement()).send(CounterMessage.ClickedIncrement());
      story.send(CounterMessage.ClickedDecrement());
      assert.strictEqual(story.model.count, 1);
    }),
  );
});
