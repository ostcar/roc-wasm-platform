# js effects using javascript with effects

The javascript defines some effects:
* console_log: to print something on the console
* time: to get the current time
* localstorage_set: to save something to local storage
* localstorage_get: to get something from the local storage

The example shows, how to use this effects from roc 


## Build the wasm-file

```bash
roc build --target=wasm32
```

This crates the file `echo.wasm` from the roc code with the wasm-platform.

If you are using zig 0.9.1 make sure to remove the zig cache before running `roc build`.


## Run the webserver

```bash
python -m http.server 8080
```

Now open your browser at <http://localhost:8080>
