#!/bin/bash

set -e

TRACE_FLAGS="--trace-depth 3 --trace -DTRACE_ON -CFLAGS '-DTRACE_ON'"
verilator -DBENCH -Wno-fatal --timing --top-module tb -cc -exe ${TRACE_FLAGS} bench.cpp gal.v tb.v
cd obj_dir
make -f Vtb.mk
cd ..
