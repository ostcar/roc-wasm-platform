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

mainForHost : List U8 -> (List U8 -> List U8)
mainForHost = \encodedArg ->
    decoded =
        encodedArg
        |> fromBytesPartial (jsonWithOptions { fieldNameMapping: SnakeCase })

    when decoded.result is
        Ok arg ->
            fnS = main arg
            
            \s ->
                decodedS = fromBytesPartial s (jsonWithOptions { fieldNameMapping: SnakeCase })
                when decodedS.result is
                    Ok argS ->
                        fnS argS
                        |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
                        |> List.append 0
                    
                    Err _ ->
                        "Invalid second argument" 
                        |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
                        |> List.append 0

                

        Err _ ->
            \_ -> 
                "Invalid argument" 
                |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
                |> List.append 0
