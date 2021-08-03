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

# Remove the hdf5 file if it exists, to avoid errors from h5py
try:
    os.remove(args.o)
except OSError:
    pass

with h5py.File(args.o, "w") as f:
    for i in range(rw_pot.shape[0]):
        f.create_dataset("potential/" + str(i + 1), data=rw_pot[i])
    f.create_dataset("segmentation", data=1 + np.argmax(rw_pot, axis=0))
