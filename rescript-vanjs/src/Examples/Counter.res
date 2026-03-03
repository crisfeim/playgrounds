open VanJS

let make = () => {
    let counter = state(0)
    span(
        "❤️ ", counter, " ",
        button({"onclick": () => counter.val = counter.val + 1}, "👍"),
        button({"onclick": () => counter.val = counter.val - 1}, "👎"),
      )
}
