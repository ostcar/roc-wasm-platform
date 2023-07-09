interface Task
    exposes [
        Task, 
        fromEffect, 
        toEffect, 
        ok, 
        err,
        doSomething,
        await,
    ]
    imports [
        json.Core.{ jsonWithOptions },
        Effect.{ Effect },
        Encode.{ toBytes },
        Decode.{ fromBytesPartial },
    ]

Task ok err := Effect (Result ok err)

ok : a -> Task a *
ok = \a -> @Task (Effect.always (Ok a))

err : a -> Task * a
err = \a -> @Task (Effect.always (Err a))

fromEffect : Effect (Result ok err) -> Task ok err
fromEffect = \effect -> @Task effect

toEffect : Task ok err -> Effect (Result ok err)
toEffect = \@Task effect -> effect

doSomething : Str, a -> Task ok DecodeError | a has Encoding, ok has Decoding
doSomething = \name, rawArg ->
    Effect.doEffect (name |> toJson |> Box.box) (rawArg |> toJson |> Box.box)
    |> Effect.map (\result ->
        result
            |> fromBytesPartial (jsonWithOptions {fieldNameMapping: SnakeCase}) 
            |> .result
    )
    |> Task.fromEffect

toJson : a -> List U8 | a has Encoding
toJson = \value ->
    value
    |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
    |> List.append 0

await : Task a b, (a -> Task c b) -> Task c b
await = \task, transform ->
    effect = Effect.after
        (toEffect task)
        \result ->
            when result is
                Ok a -> transform a |> toEffect
                Err b -> err b |> toEffect

    fromEffect effect
