# Go Webserver

This is a webserver that uses go as a wasm runtime to call roc code.

## Build the wasm-file

```bash
roc build --target=wasm32
```

This crates the file `wasm.wasm` from the roc code with the wasm-platform.



## Build the go-binary

```
go build
```

This builds the binary `webserver` that contains the wasm file.

It starts a webserver on port 8090. To start it run:

```bash
./webserber
```

To access it with `curl` in a different terminal:

```bash
curl localhost:8090 -d "hello to roc"
```
