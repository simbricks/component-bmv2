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

PYTHON            ?= python
BMV2_PY_SIM       := bmv2_sim_py
BMV2_DIR          := bmv2
BMV2_JOBS         ?= $(shell nproc)
BMV2_STAMP        := $(BMV2_DIR)/ready

# Everything installs under <PREFIX>/opt/bmv2, so a conda install and a local one
# share one layout. The python side resolves it via $BMV2_PREFIX, else
# $CONDA_PREFIX/opt.
PREFIX            ?= /usr/local
BMV2_INSTALL_DIR  := $(abspath $(PREFIX)/opt/bmv2)

# SimBricks headers + libsimbricks; defaults to the active conda env, where
# simbricks-lib installs them.
SIMBRICKS_INC_DIR ?= $(CONDA_PREFIX)/include
SIMBRICKS_LIB_DIR ?= $(CONDA_PREFIX)/lib

# Optional: redirect conda-build output, e.g. OUTPUT_FOLDER=./conda-out.
OUTPUT_FOLDER     ?=
OUTPUT_FLAG       := $(if $(OUTPUT_FOLDER),--output-folder $(OUTPUT_FOLDER))
# Conda channels searched by `conda build`. The SimBricks channel hosts external
# deps not built here (e.g. simbricks-lib, simbricks-orchestration); conda-forge
# provides the rest. Override to point at a different channel if needed.
SIMB_CONDA_CHANNEL:= -c https://conda.simbricks.io/latest
BASE_BUILD_CMD    := conda build $(SIMB_CONDA_CHANNEL) -m conda-recipes/conda_build_config.yaml $(OUTPUT_FLAG)

.PHONY: all conda-packages pypi-build pypi-publish clean bmv2-python-develop \
	bmv2-sim-py-conda bmv2-configure bmv2-build bmv2-install bmv2-clean \
	bmv2-bin-conda

## --- Python packages -------------------------------------------------------

# Editable install for local development.
bmv2-python-develop:
	$(PYTHON) -m pip install -e ./$(BMV2_PY_SIM)

## --- bmv2 simulator --------------------------------------------------------

# Thrift is mandatory: bmv2 declares simple_switch only inside `if COND_THRIFT`.
# Never add --without-pi/--without-pdfixed -- their AC_ARG_WITH fires for the
# --without- spelling too, which *enables* them. The stamp holds the configured
# prefix, which configure bakes in (it feeds $(pythondir) in the CLI wrappers).
bmv2-configure:
	@if [ "$$(cat $(BMV2_STAMP) 2>/dev/null)" = "$(BMV2_INSTALL_DIR)" ]; then \
	  echo "bmv2: already configured for prefix $(BMV2_INSTALL_DIR)"; \
	else \
	  set -e; \
	  ( cd $(BMV2_DIR) && \
	    ./autogen.sh && \
	    ./configure --prefix="$(BMV2_INSTALL_DIR)" \
	      --with-thrift --without-nanomsg --disable-elogger \
	      --disable-shared --enable-static \
	      CPPFLAGS="-I$(SIMBRICKS_INC_DIR) $$CPPFLAGS" \
	      LDFLAGS="-L$(SIMBRICKS_LIB_DIR)/simbricks $$LDFLAGS" ); \
	  echo "$(BMV2_INSTALL_DIR)" > $(BMV2_STAMP); \
	fi

bmv2-build: bmv2-configure
	$(MAKE) -C $(BMV2_DIR) -j$(BMV2_JOBS)

bmv2-install: bmv2-build
	$(MAKE) -C $(BMV2_DIR) install
	install -d $(BMV2_INSTALL_DIR)/share/p4
	install -m 0644 example-compiled-p4/basic.json $(BMV2_INSTALL_DIR)/share/p4/basic.json

# distclean fails if the tree was never configured, hence the leading `-`.
bmv2-clean:
	-$(MAKE) -C $(BMV2_DIR) distclean
	rm -f $(BMV2_STAMP)

## --- Conda packages --------------------------------------------------------

bmv2-sim-py-conda:
	$(BASE_BUILD_CMD) conda-recipes/simbricks-bmv2-sim-py

bmv2-bin-conda:
	$(BASE_BUILD_CMD) conda-recipes/simbricks-bmv2-sim-bin

conda-packages: bmv2-sim-py-conda bmv2-bin-conda

## --- PyPI packages ---------------------------------------------------------

pypi-build:
	poetry build -C $(BMV2_PY_SIM)

pypi-publish: pypi-build
	poetry publish -C $(BMV2_PY_SIM)

## --- Default target --------------------------------------------------------

# Default: local dev build of both halves.
all: conda-packages

## --- Housekeeping ----------------------------------------------------------

clean: bmv2-clean
	rm -rf $(BMV2_PY_SIM)/dist
