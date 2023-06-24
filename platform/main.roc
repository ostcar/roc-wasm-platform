platform "wasm"
    requires {} { handler : Request -> Response }
    exposes []
    packages {
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        json.Core.{ jsonWithOptions },
        Decode.{ DecodeResult, fromBytesPartial },
        Encode.{ toBytes },
    ]
    provides [handlerForHost]

handlerForHost : List U8 -> List U8
handlerForHost = \encodedRequest ->
    decoded =
        encodedRequest
        |> fromBytesPartial (jsonWithOptions { fieldNameMapping: SnakeCase })

    when decoded.result is
        Ok request ->
            handler request
            |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
            |> List.append 0

        Err _ ->
            "Invalid request" |> Str.toUtf8

Request : {
    body : Str,
}

Response : {
    body : Str,
    statusCode : U16,
}
