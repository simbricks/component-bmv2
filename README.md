# component-bmv2

The [bmv2](https://github.com/p4lang/behavioral-model) P4 software switch packaged for
[SimBricks](https://www.simbricks.io/). The `bmv2/` submodule is a SimBricks fork that adds a
SimBricks network adaptor (`src/bm_sim/dev_mgr_simbricks.cpp`), so `simple_switch` can be attached
to a SimBricks simulation over unix sockets instead of real interfaces.

This repo produces two conda packages:

| Package | Contents |
| --- | --- |
| `simbricks-bmv2-sim-bin` | the compiled `simple_switch` binary, its CLI tooling, and a compiled example P4 program, all under `$CONDA_PREFIX/opt/bmv2` |
| `simbricks-bmv2-sim-py` | `simbricks.components.bmv2.simulation.BMV2Net`, the orchestration-framework integration |

## Using it

```bash
conda install -c https://conda.simbricks.io/latest simbricks-bmv2-sim-bin
```

`simbricks-bmv2-sim-py` is pulled in automatically. Then, in a SimBricks simulation:

```python
from simbricks.components.bmv2.simulation import BMV2Net

net = BMV2Net(simulation)
net.add(switch_spec)                 # exactly one EthSwitch
# net.p4_path = "/path/to/my_program.json"   # defaults to the shipped basic.json
```

`BMV2Net` resolves the switch binary and the example P4 program from `$BMV2_PREFIX` if set,
otherwise from `$CONDA_PREFIX/opt`.

## Local development (no packaging)

Editable install of the python half:

```bash
make bmv2-python-develop
```

Compile and install bmv2 anywhere you like — everything lands under `<PREFIX>/opt/bmv2`:

```bash
make bmv2-install PREFIX=$PWD/install
export BMV2_PREFIX=$PWD/install/opt
```

`BMV2_PREFIX` is what makes `BMV2Net` pick up your local build instead of a conda-installed one.

The build needs the SimBricks C library (headers + `libsimbricks.a`). It defaults to the active
conda environment, where the `simbricks-lib` package installs them; override for another toolchain:

```bash
make bmv2-install PREFIX=$PWD/install \
  SIMBRICKS_INC_DIR=/path/to/include SIMBRICKS_LIB_DIR=/path/to/lib
```

Other useful targets: `bmv2-build` (compile only), `bmv2-clean`, `conda-packages`
(optionally with `OUTPUT_FOLDER=./conda-out`), `pypi-build`, `pypi-publish`.

Note that `PREFIX` is baked in when bmv2 is configured, so changing it re-runs `configure`
automatically.

## Notes

- Thrift is a hard requirement: bmv2 only declares `bin_PROGRAMS = simple_switch` inside
  `if COND_THRIFT`, so without it no binary is built at all. nanomsg is not available on
  conda-forge, so the nanomsg event logger and the remote debugger are disabled.
- The shipped `share/p4/basic.json` is a compiled p4c program whose `ipv4_lpm` table has **no
  entries** — a switch started with it drops traffic until the table is populated at runtime with
  `$CONDA_PREFIX/opt/bmv2/bin/simple_switch_CLI`.
