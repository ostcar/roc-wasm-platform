app "wasm"
    packages {
        pf: "../../main.roc",
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
