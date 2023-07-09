platform "wasm"
    requires {} { main : Str -> Task ok err }
    exposes [
        Task,
    ]
    packages {
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        json.Core.{ jsonWithOptions },
        Decode.{ fromBytesPartial },
        Task.{ Task },
    ]
    provides [mainForHost]

mainForHost = \encodedArg ->
    decoded =
        encodedArg
        |> fromBytesPartial (jsonWithOptions { fieldNameMapping: SnakeCase })

    when decoded.result is
        Ok arg ->
            main arg

        Err err ->
            Task.err err
