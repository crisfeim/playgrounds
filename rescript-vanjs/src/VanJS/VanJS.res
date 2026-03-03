// Van.res
type state<'a> = { mutable val: 'a }

@module("vanjs-core")
external van: {
  "tags": {
    "div": 'a,
    "p": 'a,
    "button": 'a,
    "span": 'a,
    "ul": 'a,
    "li": 'a,
    "style": 'a,
    "a": 'a,
    "pre": 'a
  },
  "state": 'a => state<'a>,
  "derive": 'a => state<'a>,
} = "default"

let state = (x: 'a) => van["state"](x)
let derive = (x: 'a) => van["derive"](x)
let div = van["tags"]["div"]
let button = van["tags"]["button"]
let p = van["tags"]["p"]
let pre = van["tags"]["pre"]
let span = van["tags"]["span"]
let ul = van["tags"]["ul"]
let li = van["tags"]["li"]
let a = van["tags"]["a"]
let style = van["tags"]["style"]

let add = (parent: Dom.element, child: Dom.element): Dom.element => {
    open Van
    add(parent, [Child.Dom(child)])
}
