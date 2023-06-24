package main

import (
	"bytes"
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"runtime"
	"sync"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
	"github.com/tetratelabs/wazero/imports/wasi_snapshot_preview1"
	"github.com/tetratelabs/wazero/sys"
)

//go:embed wasm.wasm
var wasm []byte

func main() {
	ctx, cancel := InterruptContext()
	defer cancel()

	if err := run(ctx); err != nil {
		log.Printf("Error: %v", err)
		os.Exit(1)
	}
}

func run(ctx context.Context) error {
	wasmPool, close, err := newWasmRuntimePool(ctx, wasm, runtime.NumCPU())
	if err != nil {
		return fmt.Errorf("creating wasm pool: %w", err)
	}
	defer close()

	srv := &http.Server{
		Addr:        ":8090",
		Handler:     handler(wasmPool),
		BaseContext: func(net.Listener) context.Context { return ctx },
	}

	wait := make(chan error)
	go func() {
		<-ctx.Done()
		if err := srv.Shutdown(context.Background()); err != nil {
			wait <- fmt.Errorf("HTTP server shutdown: %w", err)
			return
		}
		wait <- nil
	}()

	fmt.Printf("Start Server on %s\n", srv.Addr)
	if err := srv.ListenAndServe(); err != http.ErrServerClosed {
		return fmt.Errorf("HTTP Server failed: %w", err)
	}

	return <-wait
}

func handler(pool *wasmRuntimePool) http.HandlerFunc {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error reading body: %v", err), 500)
			return
		}
		defer r.Body.Close()

		wasmRequest := struct {
			Body string `json:"body"`
		}{
			Body: string(body),
		}

		encodedRequest, err := json.Marshal(wasmRequest)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error encoding data: %v", err), 500)
			return
		}

		runtime := pool.Get()

		encodedResponse, err := runtime.call(r.Context(), encodedRequest)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error: %v", err), 500)
			pool.Done(runtime)
			return
		}
		pool.Done(runtime)

		var wasmResponse struct {
			Body       string `json:"body"`
			StatusCode int    `json:"status_code"`
		}

		if err := json.Unmarshal(encodedResponse, &wasmResponse); err != nil {
			http.Error(w, fmt.Sprintf("Error decoding response: %v", err), 500)
			return
		}

		w.WriteHeader(wasmResponse.StatusCode)
		w.Write([]byte(wasmResponse.Body))
	})
}

// InterruptContext works like signal.NotifyContext. It returns a context that
// is canceled, when a signal is received.
//
// It listens on os.Interrupt. If the signal is received two
// times, os.Exit(2) is called.
func InterruptContext() (context.Context, context.CancelFunc) {
	ctx, cancel := context.WithCancel(context.Background())
	go func() {
		sig := make(chan os.Signal, 1)
		signal.Notify(sig, os.Interrupt)
		<-sig
		cancel()
		<-sig
		os.Exit(2)
	}()
	return ctx, cancel
}

type wasmRuntimePool struct {
	pool chan *wasmRuntime
}

func newWasmRuntimePool(ctx context.Context, wasm []byte, amount int) (*wasmRuntimePool, func(), error) {
	p := wasmRuntimePool{
		pool: make(chan *wasmRuntime, amount),
	}

	closeFuncList := make([]func(), amount)

	for i := 0; i < amount; i++ {
		r, close, err := newWasmRuntime(ctx, wasm)
		if err != nil {
			return nil, nil, fmt.Errorf("creating runtime %d: %w", i, err)
		}

		closeFuncList[i] = close
		p.pool <- r
	}

	allClose := func() {
		for _, f := range closeFuncList {
			f()
		}
	}

	return &p, allClose, nil
}

func (p *wasmRuntimePool) Get() *wasmRuntime {
	return <-p.pool
}

func (p *wasmRuntimePool) Done(w *wasmRuntime) {
	p.pool <- w
}

type wasmRuntime struct {
	mu sync.Mutex

	wasmRuntime wazero.Runtime
	memory      api.Memory

	alloc   api.Function
	callRoc api.Function
}

func newWasmRuntime(ctx context.Context, wasm []byte) (*wasmRuntime, func(), error) {
	wazRuntime := wazero.NewRuntime(ctx)

	// TODO: Why is this necessary?
	if _, err := wasi_snapshot_preview1.Instantiate(ctx, wazRuntime); err != nil {
		return nil, nil, fmt.Errorf("instantiate wasi: %w", err)
	}

	_, err := wazRuntime.NewHostModuleBuilder("env").
		NewFunctionBuilder().WithFunc(logString).Export("print_roc_string").
		NewFunctionBuilder().WithFunc(rocPanic).Export("roc_panic").
		Instantiate(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("create host module: %w", err)
	}

	module, err := wazRuntime.Instantiate(ctx, wasm)
	if err != nil {
		return nil, nil, fmt.Errorf("instantiate: %w", err)
	}

	allocUint8 := module.ExportedFunction("allocUint8")
	if allocUint8 == nil {
		return nil, nil, fmt.Errorf("can not find function allocUint8")
	}

	callRoc := module.ExportedFunction("run_roc")
	if callRoc == nil {
		return nil, nil, fmt.Errorf("can not find cuntion run_roc")
	}

	r := wasmRuntime{
		memory:  module.Memory(),
		alloc:   allocUint8,
		callRoc: callRoc,
	}

	close := func() {
		wazRuntime.Close(ctx)
	}

	return &r, close, nil
}

func (r *wasmRuntime) call(ctx context.Context, input []byte) ([]byte, error) {
	r.mu.Lock()
	defer r.mu.Unlock()

	result, err := r.alloc.Call(ctx, uint64(len(input)))
	if err != nil {
		var errExitCode *sys.ExitError
		if !errors.As(err, &errExitCode) || errExitCode.ExitCode() != 0 {
			return nil, fmt.Errorf("allocate in wasm: %w", err)
		}
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("alloc did not return anything")
	}

	offset := result[0]

	if ok := r.memory.Write(uint32(offset), input); !ok {
		return nil, fmt.Errorf("write out of memory")
	}

	result, err = r.callRoc.Call(ctx, offset, uint64(len(input)))
	if err != nil {
		var errExitCode *sys.ExitError
		if !errors.As(err, &errExitCode) || errExitCode.ExitCode() != 0 {
			return nil, fmt.Errorf("call wasm: %w", err)
		}
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("no return value")
	}

	pointer := result[0]

	v, err := readUntilZero(r.memory, uint32(pointer))
	if err != nil {
		return nil, fmt.Errorf("reading return value: %w", err)
	}

	return v, nil
}

func logString(_ context.Context, m api.Module, offset, byteCount uint32) {
	buf, ok := m.Memory().Read(offset, byteCount)
	if !ok {
		fmt.Printf("Memory.Read(%d, %d) out of range", offset, byteCount)
		os.Exit(2)
	}
	fmt.Print(string(buf))
}

func rocPanic(_ context.Context, m api.Module, offset, byteCount uint32) {
	panic("TODO")
}

func readUntilZero(memory api.Memory, start uint32) ([]byte, error) {
	const size = 1024
	buf := new(bytes.Buffer)
	for {
		b, ok := memory.Read(start, size)
		if !ok {
			return nil, fmt.Errorf("momory read out of range")
		}

		n := bytes.IndexByte(b, 0)
		if n < 0 {
			buf.Write(b)
			start += size
			continue
		}

		buf.Write(b[:n])
		return buf.Bytes(), nil
	}
}
