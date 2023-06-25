app "wasm"
    packages {
        pf: "platform/main.roc",
        # The json import is necessary for the moment: https://github.com/roc-lang/roc/issues/5598
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        pf.Http,
    ]
    provides [handler] to pf

MyRequest : {
    body : Str,
}

MyResponse : {
    body : Str,
    statusCode : U16,
}

handler : Http.Request MyRequest -> Http.Response MyResponse
handler = \request -> {
    body: "hello from roc: \(request.body)",
    statusCode: 200,
}
