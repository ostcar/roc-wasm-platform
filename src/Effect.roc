hosted Effect
    exposes [
        Effect,
        after,
        map,
        always,
        forever,
        loop,
        doEffect,        
    ]
    imports []
    generates Effect with [after, map, always, forever, loop]

doEffect : Box (List U8), Box (List U8) -> Effect (Box (List U8))
