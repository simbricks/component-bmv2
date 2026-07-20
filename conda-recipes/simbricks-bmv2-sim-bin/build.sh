#!/bin/bash
# MIT License

# Copyright (c) 2026 SimBricks

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -euo pipefail

# conda-build copies the worktree into its own source dir, so any configure/build
# state from a local `make bmv2-build` comes along with it. Drop it so we
# configure and compile cleanly against the conda toolchain and prefix.
make bmv2-clean || true

# Reuse the Makefile so build+install logic lives in one place. Host deps
# (simbricks-lib headers/lib, thrift, boost, gmp, pcap) are in $PREFIX during the
# build; the Makefile installs everything under $PREFIX/opt/bmv2.
make bmv2-install \
  PREFIX="${PREFIX}" \
  BMV2_JOBS="${CPU_COUNT}" \
  SIMBRICKS_INC_DIR="${PREFIX}/include" \
  SIMBRICKS_LIB_DIR="${PREFIX}/lib"
