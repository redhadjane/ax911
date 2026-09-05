#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
benchmark_dir="$(mktemp -d "${TMPDIR:-/tmp/}hop-benchmark.XXXXXX")"
trap 'rm -rf "$benchmark_dir"' EXIT
# Compare the exact first pilot's committed parser with the current source.
baseline=d9f06c9a5c6b7b43940e83eb54c91cda3a6914c9
git -C "$project_dir" fetch --no-tags --depth=1 origin "$baseline"
git -C "$project_dir" show "$baseline:ios/Sources/HOPCore.swift" > "$benchmark_dir/Baseline.swift"
cp "$project_dir/scripts/benchmark-core.swift" "$benchmark_dir/main.swift"
swiftc -O "$benchmark_dir/Baseline.swift" "$benchmark_dir/main.swift" -o "$benchmark_dir/baseline"
swiftc -O -D HOP_CACHE_BENCH "$project_dir/Sources/HOPCore.swift" "$benchmark_dir/main.swift" -o "$benchmark_dir/current"
printf '%s\n' 'FIRST PILOT (synthetic macOS benchmark, not iPhone timings)'
"$benchmark_dir/baseline"
printf '%s\n' 'PERFORMANCE UPDATE (identical synthetic payload and iterations)'
"$benchmark_dir/current"
