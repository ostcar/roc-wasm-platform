app "echo"
    packages {
        # pf: "https://github.com/ostcar/roc-wasm-platform/releases/download/v0.0.1/pDAWfu__jxA39uSF_5wdkg0CY9Zu8aUs4w5-9mY88Xc.tar.br",
        pf: "../../src/main.roc",

        # The json import is necessary for the moment: https://github.com/roc-lang/roc/issues/5598
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        pf.Task.{ Task },
    ]
    provides [main] to pf

main : Str -> Task Str Str
main = \argument ->
    err <- buildMessage argument |> Task.onErr
    _ <- consoleLog err |> Task.await
    Task.err "Error. See the console"


buildMessage : Str -> Task Str Str
buildMessage = \argument ->
    currentTimeInt <- getTime |> Task.await
    lastCountStr <- localstorageGet "counter" |> Task.await
    lastCount = Str.toI32 lastCountStr |> Result.withDefault 0
    currentCount = lastCount + 1
    _ <- localstorageSet "counter" (Num.toStr currentCount) |> Task.await
    currentTime = formatTime currentTimeInt
    countStr = Num.toStr currentCount
    Task.ok "Hello from roc. The current time is \(currentTime). This is the \(countStr) time I was called. Your message is: \"\(argument)\""


formatTime : (Num *) -> Str
formatTime = \t ->
    # TODO: Do it better!
    Num.toStr t 

consoleLog : Str -> Task {} Str
consoleLog = \str ->
    Task.doSomething "console_log" str
    |> taskStrToNothing
    |> Task.mapErr \s -> "Error console_log: \(s)"

getTime : Task I64 Str
getTime = 
    Task.doSomething "time" {}
    |> Task.mapErr \s -> "Error time: \(s)"

# TODO: This currently only supports Str values. It should be possible to use anything with Encoding.
localstorageSet : Str, Str -> Task {} Str
localstorageSet = \key, value ->
    Task.doSomething "localstorage_set" {key: key, value: value}
    |> taskStrToNothing
    |> Task.mapErr \s -> "Error localstorage_set: \(s)"

localstorageGet : Str -> Task Str Str
localstorageGet = \key ->
    Task.doSomething "localstorage_get" key
    |> Task.mapErr \s -> "Error localstorage_get: \(s)"


# I don't now how to handle an effect that returns nothing (null, or {})
# So for the moment, the effects have to return an empty string that gets
# converted with this.
taskStrToNothing : Task Str err -> Task {} err
taskStrToNothing = \task ->
    transform : Str -> {}
    transform = \_ -> {}
    Task.map task transform
