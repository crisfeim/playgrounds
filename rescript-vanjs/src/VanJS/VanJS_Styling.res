type styleValueFn<'a> = unit => 'a
type styleHandlers = Js.Dict.t<styleValueFn<string>>
type stylePipe = (Dom.element, styleHandlers)

@scope("style") @set external setAllInternal: (Dom.element, string) => unit = "all"
@scope("style") @set external setColorInternal: (Dom.element, string) => unit = "color"
@scope("style") @set external setFontSizeInternal: (Dom.element, string) => unit = "fontSize"
@scope("style") @set external setCursorInternal: (Dom.element, string) => unit = "cursor"
@scope("style") @set external setBackgroundInternal: (Dom.element, string) => unit = "background"
@scope("style") @set external setDisplay: (Dom.element, string) => unit = "display"
@scope("style") @set external setBorderBottom: (Dom.element, string) => unit = "borderBottom"
@scope("style") @set external setBorderRight: (Dom.element, string) => unit = "borderRight"
@scope("style") @set external setTransform: (Dom.element, string) => unit = "transform"
@scope("style") @set external setHeight: (Dom.element, string) => unit = "height"
@scope("style") @set external setWidth: (Dom.element, string) => unit = "width"
@scope("style") @set external setBorderColor: (Dom.element, string) => unit = "borderColor"
@scope("style") @set external setMarginRight: (Dom.element, string) => unit = "marginRight"
@scope("style") @set external setAlignItems: (Dom.element, string) => unit = "alignItems"
@scope("style") @set external setPadding: (Dom.element, string) => unit = "padding"
@scope("style") @set external setBackgroundColor: (Dom.element, string) => unit = "backgroundColor"
@scope("style") @set external setPosition: (Dom.element, string) => unit = "position"
@scope("style") @set external setLeft: (Dom.element, string) => unit = "left"
@scope("style") @set external setFontWeight: (Dom.element, string) => unit = "fontWeight"
@scope("style") @set external setMarginBottom: (Dom.element, string) => unit = "marginBottom"
@scope("style") @set external setBorderRadius: (Dom.element, string) => unit = "borderRadius"
@scope("style") @set external setListStyle: (Dom.element, string) => unit = "listStyle"
@scope("style") @set external setOverflow: (Dom.element, string) => unit = "overflow"
@scope("style") @set external setBoxSizing: (Dom.element, string) => unit = "boxSizing"
@scope("style") @set external setAspectRatio: (Dom.element, string) => unit = "aspectRatio"
@scope("style") @set external setMarginInline: (Dom.element, string) => unit = "marginInline"
@scope("style") @set external setFontFamily: (Dom.element, string) => unit = "fontFamily"

let setStyleProperty = (el: Dom.element, key: string, value: string): unit => {
  switch key {
  | "all" => el->setAllInternal(value)
  | "color" => el->setColorInternal(value)
  | "fontSize" => el->setFontSizeInternal(value)
  | "cursor" => el->setCursorInternal(value)
  | "background" => el->setBackgroundInternal(value)
  | "display" => el->setDisplay(value)
  | "borderBottom" => el->setBorderBottom(value)
  | "borderRight" => el->setBorderRight(value)
  | "transform" => el->setTransform(value)
  | "height" => el->setHeight(value)
  | "width" => el->setWidth(value)
  | "borderColor" => el->setBorderColor(value)
  | "marginRight" => el->setMarginRight(value)
  | "alignItems" => el->setAlignItems(value)
  | "padding" => el->setPadding(value)
  | "backgroundColor" => el->setBackgroundColor(value)
  | "position" => el->setPosition(value)
  | "left" => el->setLeft(value)
  | "fontWeight" => el->setFontWeight(value)
  | "marginBottom" => el->setMarginBottom(value)
  | "borderRadius" => el->setBorderRadius(value)
  | "listStyle" => el->setListStyle(value)
  | "overflow" => el->setOverflow(value)
  | "boxSizing" => el->setBoxSizing(value)
  | "aspectRatio" => el->setAspectRatio(value)
  | "marginInline" => el->setMarginInline(value)
  | "fontFamily" => el->setFontFamily(value)
  | _ => ()
  }
}

let addStyleHandler = (
    (el, handlers): stylePipe,
    key: string,
    fn: styleValueFn<string>,
): stylePipe => {
  Js.Dict.set(handlers, key, fn)
  (el, handlers)
}

let startStylePipe = (el: Dom.element): stylePipe => {
    (el, Js.Dict.empty())
}

let apply = ((el, handlers): stylePipe): Dom.element => {
  Van.derive(() => {
    handlers
    ->Js.Dict.entries
    ->Array.forEach(entry => {
      let (key, fn) = entry
      let value = fn()
      el->setStyleProperty(key, value)
    })
  })->ignore

  el
}

let all = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "all", fn)
}

let color = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "color", fn)
}

let fontSize = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "fontSize", fn)
}

let cursor = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "cursor", fn)
}

let background = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "background", fn)
}

let display = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "display", fn)
}

let borderBottom = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "borderBottom", fn)
}

let borderRight = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "borderRight", fn)
}

let transform = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "transform", fn)
}

let height = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "height", fn)
}

let width = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "width", fn)
}

let borderColor = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "borderColor", fn)
}

let marginRight = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "marginRight", fn)
}

let alignItems = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "alignItems", fn)
}

let padding = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "padding", fn)
}

let backgroundColor = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "backgroundColor", fn)
}

let position = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "position", fn)
}

let left = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "left", fn)
}

let fontWeight = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "fontWeight", fn)
}

let marginBottom = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "marginBottom", fn)
}

let borderRadius = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "borderRadius", fn)
}

let listStyle = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "listStyle", fn)
}

let overflow = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "overflow", fn)
}

let boxSizing = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "boxSizing", fn)
}

let aspectRatio = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "aspectRatio", fn)
}

let marginInline = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "marginInline", fn)
}

let fontFamily = (pipe: stylePipe, fn: styleValueFn<string>): stylePipe => {
  addStyleHandler(pipe, "fontFamily", fn)
}
