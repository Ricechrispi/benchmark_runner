import json
import subprocess
import argparse
import logging

import reader as reader_module
from reader import CnfReader

logger = logging.getLogger(__name__)
logger.setLevel("DEBUG")
# create console handler and set level to debug
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
# create formatter
formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
# add formatter to ch
ch.setFormatter(formatter)
# add ch to logger
logger.addHandler(ch)


# This is directly adapted nesthdb code to run a single solver
def call_solver(cfg, solver_name, instance, run_id=0):
    logger.info(f"Call solver: {solver_name} with instance {instance}")

    assert ("path" in cfg)
    solver = [cfg["path"]]

    if "args" in cfg:
        solver.extend(cfg["args"].split(" "))
    if "output_parser" in cfg:
        solver_parser = cfg["output_parser"]
        solver_parser_cls = getattr(reader_module, solver_parser["class"])
    else:
        solver_parser = {"class": "CnfReader", "args": {"silent": True}, "result": "models"}
        solver_parser_cls = CnfReader

    logger.info(f"Call string: {' '.join(solver)} {instance}")
    # actually run the solver
    psat = subprocess.Popen(solver + [instance], stdout=subprocess.PIPE)
    output = solver_parser_cls.from_stream(psat.stdout, **solver_parser["args"])
    psat.wait()
    psat.stdout.close()
    raw_result = getattr(output, solver_parser["result"])
    if raw_result is not None:
        result = raw_result
    else:
        result = -1

    if psat.returncode == 245 or psat.returncode == 250:
        raise logger.error(f"Unexpected returncode of solver: {psat.returncode}.")

    return result, psat.returncode

def parse_args():
    # The specific arguments for the algorithms are defined in the provided param_file.
    parser = argparse.ArgumentParser()
    parser.add_argument("algo", choices=["d4", "dpmc", "sharpsat_td", "ganak", "miniC2D", "sharpsat_marcthurley"])
    parser.add_argument("--instance", dest="instance", type=str)
    parser.add_argument("--param_file", dest="param_file", type=str, default="parameters.json")
    parser.add_argument("--run_id", dest="run_id", type=int, default=0)
    args = parser.parse_args()
    return args

def main():
    args = parse_args()

    with open(args.param_file) as c_file:
        cfg = json.load(c_file)

    logger.info(f"Benchmarking solver: {args.algo}")
    result, returncode = call_solver(cfg[args.algo], args.algo, args.instance, args.run_id)
    logger.info(f"Benchmarking over. models: {result}, returncode: {returncode}")
    exit(returncode)

if __name__ == "__main__":
    main()
