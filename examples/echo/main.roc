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

main = \argument ->
    input <- readStr |> Task.await
    _ <- printStr "argument: \(argument), read input: \(input)" |> Task.attempt
    # For some reason, printStr returns an error. I don't understand it, but we can just ignore it.
    Task.ok "All done"




printStr : Str -> Task {} Str
printStr = \str ->
    Task.doSomething "print_str" str
    |> Task.mapErr \_ -> "Error printStr"

readStr : Task Str Str
readStr =
    Task.doSomething "read_str" {}
    |> Task.mapErr \_ -> "Error readStr"
