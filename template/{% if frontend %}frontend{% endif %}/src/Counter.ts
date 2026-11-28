import { UiSchema } from "@effect/ui";
import { Html } from "@effect/ui/html";
import { Schema } from "effect";

const CounterModel = Schema.Struct({
  count: Schema.Number,
});

export const CounterMessage = UiSchema.TaggedEnum({
  ClickedDecrement: {},
  ClickedIncrement: {},
});

export const Counter = Html.component({
  name: "Counter",
  model: CounterModel,
  message: CounterMessage,
}).make({
  init: () => ({ count: 0 }),
  update: {
    ClickedDecrement: ($) => $.evolve({ count: (count) => count - 1 }),
    ClickedIncrement: ($) => $.evolve({ count: (count) => count + 1 }),
  },
  view: (h, model) =>
    h.div(
      h.p(String(model.count)),
      h.button.on("click", CounterMessage.ClickedDecrement()).children("-"),
      h.button.on("click", CounterMessage.ClickedIncrement()).children("+"),
    ),
});
