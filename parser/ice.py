"""
Standalone Parser
===================================

    This example demonstrates how to generate and use the standalone parser,
    using the ICE example.

    See README.md for more details.
"""

import sys

from ice_parser import Lark_StandAlone, Transformer, v_args

inline_args = v_args(inline=True)

class TreeToIce(Transformer):
    @inline_args
    def string(self, s):
        return s[1:-1].replace('\\"', '"')

parser = Lark_StandAlone(transformer=TreeToIce())

if __name__ == '__main__':
    with open(sys.argv[1]) as f:
        print(parser.parse(f.read()).pretty())
