open Test

test("String", () => {
  expect("hello")->toBe("hello")
})

test("3 * 3", () => {
  expect(3 * 3)->toBe(9)
})
