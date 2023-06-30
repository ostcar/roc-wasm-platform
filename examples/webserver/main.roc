app "wasm"
    packages {
        # pf: "https://github.com/ostcar/roc-wasm-platform/releases/download/v0.0.1/pDAWfu__jxA39uSF_5wdkg0CY9Zu8aUs4w5-9mY88Xc.tar.br",
        pf: "../../src/main.roc",
        # The json import is necessary for the moment: https://github.com/roc-lang/roc/issues/5598
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        pf.Arg,
    ]
    provides [main] to pf

Request : {
    body : Str,
}

Response : {
    body : Str,
    statusCode : U16,
}

main : Arg.FromHost Request -> Arg.ToHost Response
main = \request -> {
    body: "hello from roc: \(request.body)",
    statusCode: 200,
}
