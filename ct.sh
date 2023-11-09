#!/bin/bash -ex
export RUST_BACKTRACE=1

toolchains=("my_sgx_build" "nightly")
platforms=("x86_64-fortanix-unknown-sgx" "x86_64-unknown-linux-gnu")

for toolchain in "${toolchains[@]}"; do
    for platform in "${platforms[@]}"; do
        echo "toolchain: $toolchain"
        echo "platform: $platform"
        echo ""
        cargo +${toolchain} test --target  ${platform}
        cargo +${toolchain} test --features "net,os-poll" --target  ${platform}
        cargo +${toolchain} test --features "net,os-ext" --target  ${platform}
        cargo +${toolchain} test --features "net,os-poll,os-ext" --target ${platform}
    done
done
exit 0
