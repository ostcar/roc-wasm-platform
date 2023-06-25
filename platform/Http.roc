interface Http
    exposes [
        Request,
        Response,
    ]
    imports []

Request a : a | a has Decoding
Response a : a | a has Encoding
