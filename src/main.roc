platform "wasm"
    requires {} { main : a ->  LastTask b | a has Decoding, b has Encoding }
    exposes [
        Task,
    ]
    packages {
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        json.Core.{ jsonWithOptions },
        Decode.{ fromBytesPartial },
        Task.{ Task, LastTask },
        Encode.{ toBytes },
    ]
    provides [mainForHost]

mainForHost = \encodedArg ->
    decoded =
        encodedArg
        |> fromBytesPartial (jsonWithOptions { fieldNameMapping: SnakeCase })

    when decoded.result is
        Ok arg ->
            main arg
            |> Task.mapLast toJson

        Err _ ->
            Task.lastValue ("Something is wrong" |> toJson)


toJson : a -> List U8 | a has Encoding
toJson = \value ->
    value
    |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
    |> List.append 0
