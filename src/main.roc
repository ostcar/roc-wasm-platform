platform "wasm"
    requires {} { main : a -> (b -> c) | a has Decoding, b has Decoding, c has Encoding }
    exposes []
    packages {
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        json.Core.{ jsonWithOptions },
        Decode.{ DecodeResult, fromBytesPartial },
        Encode.{ toBytes },
    ]
    provides [mainForHost]

# # TODO: Make callback (List U8 -> Job) and make Job a enum where one option is just value
# Job : {
#     callback: (List U8 -> List U8),
#     name: List U8,
#     value: List U8,
# }

Job : List U8 -> List U8

mainForHost : List U8 -> Job
mainForHost = \encodedArg ->
    decoded =
        encodedArg
        |> fromBytesPartial (jsonWithOptions { fieldNameMapping: SnakeCase })

    when decoded.result is
        Ok arg ->
            main arg
            |> callback
                    
        Err _ ->
            # {
            #     callback: \_ -> [],
            #     name: "Error" |>Str.toUtf8,
            #     value:             
            #         "Invalid argument" 
            #         |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
            #         |> List.append 0,
            # }
            rawArgument = Str.fromUtf8 encodedArg|> Result.withDefault "Can not decode"
            \_ -> "Invalid first argument:  --\(rawArgument)--" |> toJson


callback : (b -> c) -> Job | b has Decoding, c has Encoding
callback = \mainCallback ->
    convertedFn : List U8 -> List U8
    convertedFn = \encodedArg ->
        decoded = 
            encodedArg
            |> fromBytesPartial (jsonWithOptions { fieldNameMapping: SnakeCase })

        when decoded.result is
            Ok arg ->
                mainCallback arg
                |> toJson
            
            Err _ ->
                "Invalid second argument" 
                |> toJson

    # {
    #     callback: convertedFn,
    #     name: Str.toUtf8 "DoSomething",
    #     value: [],
    # }
    convertedFn


toJson : a -> List U8 | a has Encoding
toJson = \value -> 
        value
        |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
        |> List.append 0
