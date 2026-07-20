# Copyright 2026 Max Planck Institute for Software Systems,
# National University of Singapore, and SimBricks UG (haftungsbeschränkt)
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

from __future__ import annotations

import os

import typing_extensions as tpe

from simbricks.orchestration.instantiation import base as inst_base
from simbricks.orchestration.simulation import base as sim_base
from simbricks.orchestration.simulation import net as sim_net
from simbricks.orchestration.system import eth as sys_eth
from simbricks.utils import base as utils_base


class BMV2Net(sim_net.NetSim):
    """The bmv2 P4 software switch (simple_switch) as a SimBricks network simulator."""

    def __init__(
        self,
        simulation: sim_base.Simulation,
        executable: str | None = None,
        p4_path: str | None = None,
    ) -> None:
        # The switch and the example P4 program are installed side by side. With
        # the simbricks-bmv2-sim-bin conda package they live under $CONDA_PREFIX;
        # $BMV2_PREFIX overrides that for a local `make bmv2-install PREFIX=<p>`,
        # where it should be set to <p>/opt.
        bmv2_prefix = os.environ.get("BMV2_PREFIX")
        if bmv2_prefix is not None:
            base = f"{bmv2_prefix}/"
        else:
            conda_prefix = os.environ.get("CONDA_PREFIX", "")
            base = f"{conda_prefix}/opt/"

        if executable is None:
            executable = f"{base}bmv2/bin/simple_switch"
        if p4_path is None:
            p4_path = f"{base}bmv2/share/p4/basic.json"

        super().__init__(
            simulation=simulation,
            executable=executable,
        )
        self.p4_path: str = p4_path

    def add(self, switch_spec: sys_eth.EthSwitch):
        utils_base.has_expected_type(switch_spec, sys_eth.EthSwitch)
        if len(self._components) >= 1:
            raise Exception("can only add a single switch component to the BMV2Net")
        super().add(switch_spec)

    def toJSON(self) -> dict:
        json_obj = super().toJSON()
        json_obj["p4_path"] = self.p4_path
        return json_obj

    @classmethod
    def fromJSON(cls, simulation: sim_base.Simulation, json_obj: dict) -> tpe.Self:
        instance = super().fromJSON(simulation, json_obj)
        instance.p4_path = utils_base.get_json_attr_top(json_obj, "p4_path")
        return instance

    def run_cmd(self, inst: inst_base.Instantiation) -> str:
        channels = self.get_channels()
        eth_latency, sync_period, run_sync = (
            sim_base.Simulator.get_unique_latency_period_sync(channels=channels)
        )

        sockets = self._get_socks_by_all_comp(inst=inst)
        listen, connect = sim_base.Simulator.split_sockets_by_type(sockets)

        if len(listen) > 0:
            raise Exception("BMV2Net does currently not support listening sockets")

        cmd = (
            f"{self._executable}"
            f" --use-simbricks --sync-interval {sync_period}"
            f" --link-latency {eth_latency}"
        )

        if run_sync:
            cmd += " --sync-eth"

        # simple_switch identifies a port by `<port>@<iface>`; the SimBricks
        # adaptor interprets the interface name as the unix socket to connect to.
        for port, sock in enumerate(connect):
            cmd += f" -i {port}@{sock._path}"

        # The compiled P4 program is a required positional argument.
        cmd += f" {self.p4_path}"

        return cmd
