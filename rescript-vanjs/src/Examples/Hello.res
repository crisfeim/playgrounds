open VanJS

let make = () => div(
  p("👋Hello"),
  ul(
    li("🗺️World"),
    li(a({"href": "https://vanjs.org/"}, "🍦VanJS")),
  ),
)
