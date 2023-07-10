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

doEffect : List U8, List U8 -> Effect (List U8)
