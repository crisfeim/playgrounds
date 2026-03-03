open VanJS
open VanJS_Styling

let make = () => {
    let state = state(true)
    let toggle = () => state.val = !state.val

    div(
        span(state)
            ->startStylePipe
            ->color(() =>state.val ? "red" : "green")
            ->fontWeight(() => state.val ? "normal" : "bold")
            ->fontFamily(() => state.val ? "courier" : "avenir")
            ->backgroundColor(() => state.val ? "white": "orange")
            ->apply
        ,
        button({ "onclick": toggle}, "toggle")
    )
}
