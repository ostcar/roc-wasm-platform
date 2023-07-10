platform "wasm"
    requires {} { main : a -> Task ok err | a has Decoding, ok has Encoding, err has Encoding }
    exposes [
        Task,
    ]
    packages {
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        PlatformEncode.{ toJson, fromJson },
        Task.{ Task },
        Effect.{ Effect },
    ]
    provides [mainForHost]

mainForHost = \encodedArg ->
    when fromJson encodedArg is
        Ok arg ->
            main arg
            |> resolveTask

        Err _ ->
            "Something is wrong" |> resultEffect

resolveTask : Task ok err -> Effect (List U8) | ok has Encoding, err has Encoding
resolveTask = \task ->
    transform : Result ok err -> List U8 | ok has Encoding, err has Encoding
    transform = \result ->
        when result is
            Ok ok ->
                toJson ok

            Err err ->
                toJson err

    task
    |> Task.toEffect
    |> Effect.map transform

resultEffect : a -> Effect (List U8) | a has Encoding
resultEffect = \v ->
    Effect.always (toJson v)
