@module("bun:test")
external test: (string, unit => unit) => unit = "test"

type expectation<'a>

@module("bun:test")
external expect: 'a => expectation<'a> = "expect"

@send external toBe: (expectation<'a>, 'a) => unit = "toBe"
