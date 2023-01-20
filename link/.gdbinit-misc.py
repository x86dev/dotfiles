#!/bin/python
from __future__ import print_function
import gdb

# Taken from: https://stackoverflow.com/questions/1262639/multiple-commands-in-gdb-separated-by-some-sort-of-delimiter
class Cmds(gdb.Command):
  """run multiple commands separated by ';'"""
  def __init__(self):
    gdb.Command.__init__(
      self,
      "cmds",
      gdb.COMMAND_DATA,
      gdb.COMPLETE_SYMBOL,
      True,
    )

  def invoke(self, arg, from_tty):
    for fragment in arg.split(';'):
      # from_tty is passed in from invoke.
      # These commands should be considered interactive if the command
      # that invoked them is interactive.
      # to_string is false. We just want to write the output of the commands, not capture it.
      gdb.execute(fragment, from_tty=from_tty, to_string=False)
      print()

Cmds()
