import os
import argparse
import h5py
import skimage.io
import numpy as np
from python.image import graph_from_hed

parser = argparse.ArgumentParser(description='Convert images into graphs')
parser.add_argument('path', type=str, metavar='PATH',
                    help='filename of the image file')
parser.add_argument('--hed', type=str, metavar='PATH',
                    help='filename of the hed edge file')
parser.add_argument('-s', type=str, metavar='PATH',
                    help='filename of the seeds image')
parser.add_argument('-o', type=str, metavar='PATH',
                    help='output file')
parser.add_argument('--beta', type=float, default=130,
                    help='beta parameter for the weights')
args = parser.parse_args()

image = skimage.io.imread(args.path).astype(float)
image /= image.max()
hed = skimage.io.imread(args.hed).astype(float)
hed /= hed.max()
seeds = skimage.io.imread(args.s, as_gray=True)
seeds = np.digitize(seeds, np.array([0.01, 0.4]))

n, edges, weights = graph_from_hed(hed, beta=args.beta)

# Remove the hdf5 file if it exists, to avoid errors from h5py
try:
    os.remove(args.o)
except OSError:
    pass

with h5py.File(args.o, "w") as f:
    f.create_dataset("image", data=image)
    f.create_dataset("n", data=n)
    f.create_dataset("edges", data=edges)
    f.create_dataset("weights", data=weights)
    f.create_dataset("seeds", data=seeds.ravel())
