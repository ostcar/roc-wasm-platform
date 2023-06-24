# GORoc

An example to use roc with go by using wasm.


1. Make sure the zig-cache is removed

```
rm -r platform/zig-cache
```

2. Call roc

```
roc build --target=wasm32
```

You now have a file called `wasm.wasm`


3. Build the go code

```
go build
```

You now have a binary called `goroc` that contains the wasm-file


4. Run it

```
./goroc
```

It starts an http-server on port 8090


5. Call it

You can access it with `curl`:

```
curl localhost:8090 -d "hello to roc"
```


# Issues

* You have to build roc from source: https://github.com/roc-lang/roc/issues/5573
* You have to remove the zig-cache before calling roc
* You get some false positive `UNUSED DEFINITION` warnings: https://github.com/roc-lang/roc/issues/5597
