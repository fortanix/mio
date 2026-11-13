#!/bin/bash -ex
export RUST_BACKTRACE=1

# Each entry is "toolchain:target". Add or remove lines to choose what gets tested.
# Chosen toolchains:
#    - nightly-2023-05-07: older than rustc 1.78.0, compiler_has_send_sgx_types is not defined (check build.rs)
#    - nightly-2025-10-09: newer than rustc 1.78.0, compiler_has_send_sgx_types is defined
#    - mybuild: built from the fortanix/rust fork, supports the fortanixvme target
#
# Note: nightly-2024-02-20 is a nightly 1.78.0 version, so zerocopy (a dev-dep via rand) enables #[diagnostic],
#       but this toolchain doesn't fully support it yet, so test builds fail
combos=(
     "nightly-2023-05-07-x86_64-unknown-linux-gnu:x86_64-fortanix-unknown-sgx"
     "nightly-2023-05-07-x86_64-unknown-linux-gnu:x86_64-unknown-linux-gnu"
     "nightly-2025-10-09-x86_64-unknown-linux-gnu:x86_64-fortanix-unknown-sgx"
     "nightly-2025-10-09-x86_64-unknown-linux-gnu:x86_64-unknown-linux-gnu"
     "mybuild:x86_64-unknown-linux-gnu"
     "mybuild:x86_64-unknown-linux-fortanixvme"
)

feature_sets=(
    ""
    "net"
    "os-ext"
    "os-poll"
    "net,os-poll"
    "net,os-ext"
    "net,os-poll,os-ext"
)

run_tests=0

for combo in "${combos[@]}"; do
    IFS=':' read -r toolchain target <<< "$combo"
    echo "toolchain: $toolchain"
    echo "target: $target"
    echo ""

    # remove the lockfile to avoid incompatibilities between toolchains
    rm -rf Cargo.lock

    # fortanix-vme-runner binds a fixed vsock port (10000), so tests that
    # start their own runner (doctests) can't run in parallel.
    if [[ "$target" == *fortanixvme* ]]; then
        export RUST_TEST_THREADS=1
    else
        unset RUST_TEST_THREADS
    fi

    if [[ "$target" == *sgx* ]]; then
        # make sure the sgx target is installed for this toolchain
        rustup +"$toolchain" target add "$target"
    fi

    # build examples
    cargo +"$toolchain" build --all-targets --example tcp_listenfd_server --features="os-poll net" --target "$target"
    cargo +"$toolchain" build --all-targets --example tcp_server --features="os-poll net" --target "$target"
    cargo +"$toolchain" build --all-targets --example udp_server --features="os-poll net" --target "$target"

    # build and run tests
    for features in "${feature_sets[@]}"; do
        # SGX only builds when `net` and `os-poll` (also enabled by `os-ext`) are both on.
        # Without `os-poll`, mio uses its shell backend, which has no SGX `IoSourceState::register`.
        # Without `net`, the SGX selector can't see `Token`/`Interest`, which are only imported under `net`.
        if [[ "$target" == *sgx* ]]; then
            if [[ "$features" != *,* || ",$features," != *,net,* ]]; then
                continue
            fi
        fi

        cargo +"$toolchain" build --all-targets --features "$features" --target "$target"

        if [ "$run_tests" -ne 0 ]; then
            if [ -z "$features" ]; then
                cargo +"$toolchain" test --target "$target"
            else
                cargo +"$toolchain" test --features "$features" --target "$target"
            fi
        fi
    done
done