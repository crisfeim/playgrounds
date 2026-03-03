
module Promise = Js.Promise
module Global = Js.Global
module String = Js.String

open VanJS

let sleep: int => Promise.t<unit> = ms => {
let executor: (~resolve: unit => unit, ~reject: 'a => unit) => unit =
   (~resolve, ~reject as _) => {
     Global.setTimeout(() => resolve(), ms)->ignore
   }

 Promise.make(executor)
}

let rec loop = (steps: state<int>, sleepMs: int) =>
  if steps.val < 40 {
    steps.val = steps.val + 1
    sleep(sleepMs)
    // _ is the value from previous promise, unit in this case
    |> Promise.then_(_ => loop(steps, sleepMs))
  } else {
    Promise.resolve()
  }

let run = (speedMs, ~emoji="🚐") => {
    let steps = state(0)
    loop(steps, speedMs)->ignore
    pre(() => {
        let spaces = String.repeat(40 - steps.val, " ")
        let underscores = String.repeat(steps.val, "_")
        spaces ++ emoji ++ "💨Hello VanJS!" ++ underscores
    })
}

let make = () => {
  let dom = div()
  let btn = (ms, emoji) =>
     button({"onclick": () => add(dom, run(ms, ~emoji=emoji))}, "Hello" ++ emoji)

   div(
    dom,
    btn(2000,"🐌"),
    btn(500,"🐢"),
    btn(100,"🚶‍♂️"),
    btn(50,"🏃‍♂️"),
    btn(10,"🏎️"),
    btn(2,"🚀")
  )
}
