import Pkg
Pkg.activate(".")
using Revise
using Caesar
using Logging


logger = ConsoleLogger(stdout, Logging.Debug)
old_logger = global_logger(logger)


out, out2 = let fn = "ex01.scm"
    source = open(fn, "r") do sourcefile
        lines = readlines(sourcefile)
        code = join(lines, "\n")
        token_list(code)
    end
    i = 1
    exprs = Array(undef, 0)
    out = source
end
display(out); println();

"""
TODO: Add parse_program function that alternately calls parse_atom and
    parse_combination until the end of the token list.
TODO: Add show/display implementation for expressions to make verifying outputs
    easier.
"""

run_examples()
