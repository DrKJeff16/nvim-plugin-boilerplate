# -*- coding: utf-8 -*-
"""Template plugin."""
import pynvim
from typing import NoReturn


@pynvim.plugin
class MyPlugin(object):
    """MyPlugin object."""

    nvim: pynvim.nvim

    def __init__(self, nvim: pynvim.Nvim):
        pass

    @pynvim.command("MyPluginFoo", nargs=0)
    def foo(self) -> NoReturn:
        """Executes the ``MyPluginFoo`` command."""
        pass

# vim: set ts=4 sts=4 sw=4 et ai si sta:
