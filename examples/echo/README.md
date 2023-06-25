# Echo using javascript

## Build the wasm-file

```bash
roc build --target=wasm32
```

This crates the file `echo.wasm` from the roc code with the wasm-platform.


## Run the webserver

```bash
python -m http.server 8080
```

Now open your browser at <http://localhost:8080>
