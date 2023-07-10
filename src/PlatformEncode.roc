interface PlatformEncode
    exposes [
        toJson,
        fromJson,
    ]
    imports [
        
        json.Core.{ json, jsonWithOptions },
        Encode.{ toBytes },
        Decode.{ fromBytesPartial },
    ]

toJson : a -> List U8 | a has Encoding
toJson = \value ->
    value
    |> toBytes (jsonWithOptions { fieldNameMapping: SnakeCase })
    |> List.append 0

fromJson = \value ->
    #fromBytesPartial value (jsonWithOptions { fieldNameMapping: SnakeCase })
    fromBytesPartial value json
    |> .result
