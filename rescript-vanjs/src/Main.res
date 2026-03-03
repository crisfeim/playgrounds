open VanJS

let app = () => div(
    Hello.make(),
    Counter.make(),
    RaceApp.make(),
    RedGreenToggle.make()
)

switch Document.getElementById("root") {
| Some(el) => add(el, app())->ignore
| None => add(Document.body, (p("Root element not found")))->ignore
}
