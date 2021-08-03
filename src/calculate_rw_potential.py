import os
import argparse
import h5py
import numpy as np
from python.random_walker import random_walker

parser = argparse.ArgumentParser(description='Calculate the RW potential of a graph')
parser.add_argument('path', type=str, metavar='PATH',
                    help='filename of the seeded graph file')
parser.add_argument('-o', type=str, metavar='PATH',
                    help='output file')
args = parser.parse_args()

with h5py.File(args.path, "r") as f:
    n, edges, weights = f["n"][()], f["edges"][()], f["weights"][()]
    seeds = f["seeds"][()]

rw_pot = random_walker(n, edges, weights, seeds, mode="bf")

os.makedirs(os.path.dirname(args.o), exist_ok=True)

# Remove the hdf5 file if it exists, to avoid errors from h5py
try:
    os.remove(args.o)
except OSError:
    pass

with h5py.File(args.o, "w") as f:
    f.create_dataset("potential", data=rw_pot[0])
