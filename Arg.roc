interface Arg
    exposes [
        FromHost,
        ToHost,
    ]
    imports []

FromHost a : a | a has Decoding
ToHost b : b | b has Encoding
