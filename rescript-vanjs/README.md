# VansJS + Rescript showcase

POC that showcases how to make vanjs work with rescript. Kept as a reference for my future self.

## Use cases

- Having a really typed language for declaring both, logic and UI on web platforms.
- Defining native elements and webcomponents from rescript.

## Feautures

- Vanjs tag primitive bindings.
- Functional syntax so we can chain components styling in a SwiftUI alike way.

```rescript
// Button.res
open VanJS
open Styling

let make(~label: string) => {
  button(label)
    -> startStylingPipe
    -> color("blue")
    -> paddingInline("6px")
    -> apply
}

// Main.res
switch Document.getElementById("root") {
| Some(el) => add(el, Button.make(~label="Click"))->ignore
| None => add(Document.body, (p("Root element not found")))->ignore
}
```
