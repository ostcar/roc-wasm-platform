package platform_test

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"testing"

	"github.com/tetratelabs/wazero"
	"github.com/tetratelabs/wazero/api"
	"github.com/tetratelabs/wazero/imports/wasi_snapshot_preview1"
	"github.com/tetratelabs/wazero/sys"
	"golang.org/x/sync/errgroup"
)

func TestBuildAndRun(t *testing.T) {
	ctx := context.Background()
	wasm, err := buildWasm(t.TempDir(), rocSaysHello)
	if err != nil {
		t.Fatalf("creating wasm module: %v", err)
	}

	runtime, close, err := newWasmRuntime(ctx, wasm)
	if err != nil {
		t.Fatalf("create wasm runtime: %v", err)
	}
	defer close()

	t.Run("run once", func(t *testing.T) {
		encoded, err := json.Marshal("hello from test")
		if err != nil {
			t.Fatalf("json marshal: %v", err)
		}

		got, err := runtime.call(ctx, encoded)
		if err != nil {
			t.Fatalf("call wasm: %v", err)
		}

		var decoded string
		if err := json.Unmarshal(got, &decoded); err != nil {
			t.Fatalf("decoding got: %v", err)
		}

		expect := "Hello from roc: hello from test"
		if string(decoded) != expect {
			t.Errorf("got:\n%s\nexpected:\n%s", decoded, expect)
		}
	})

	t.Run("Run many times", func(t *testing.T) {
		const amount = 10.000

		encoded, err := json.Marshal("hello from test")
		if err != nil {
			t.Fatalf("json marshal input: %v", err)
		}

		expected, err := json.Marshal("Hello from roc: hello from test")
		if err != nil {
			t.Fatalf("json marshal expected: %v", err)
		}

		eg := new(errgroup.Group)
		for i := 0; i < amount; i++ {
			eg.Go(func() error {
				got, err := runtime.call(ctx, encoded)
				if err != nil {
					return fmt.Errorf("call wasm: %w", err)
				}

				if string(got) != string(expected) {
					return fmt.Errorf("%s != %s", got, expected)
				}

				return nil
			})
		}

		if err := eg.Wait(); err != nil {
			t.Fatal(err)
		}
	})
}

func buildWasm(path string, rocCode string) ([]byte, error) {
	pwd, err := os.Getwd()
	if err != nil {
		return nil, fmt.Errorf("get pwd: %w", err)
	}

	if err := os.Chdir(path); err != nil {
		return nil, fmt.Errorf("chdir: %w", err)
	}

	rocCode = strings.ReplaceAll(rocCode, "PWD", pwd)
	if err := os.WriteFile(filepath.Join(path, "main.roc"), []byte(rocCode), 0o666); err != nil {
		return nil, fmt.Errorf("write roc code: %w", err)
	}

	cmd := exec.Command("roc", "build", "--target=wasm32")
	if output, err := cmd.CombinedOutput(); err != nil {
		return nil, fmt.Errorf("running roc: %s\n%w", output, err)
	}

	wasm, err := os.ReadFile(filepath.Join(path, "test.wasm"))
	if err != nil {
		return nil, fmt.Errorf("reading wasm file: %w", err)
	}

	return wasm, nil
}

const rocSaysHello = `app "test"
    packages {
        pf: "PWD/../src/main.roc",
        # The json import is necessary for the moment: https://github.com/roc-lang/roc/issues/5598
        json: "https://github.com/lukewilliamboswell/roc-json/releases/download/0.1.0/xbO9bXdHi7E9ja6upN5EJXpDoYm7lwmJ8VzL7a5zhYE.tar.br",
    }
    imports [
        pf.Arg,
    ]
    provides [main] to pf


main : Arg.FromHost Str -> Arg.ToHost Str
main = \arg -> "Hello from roc: \(arg)"
`

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
