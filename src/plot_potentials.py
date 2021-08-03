import argparse
import h5py
import numpy as np
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description='Calculate the RW potential of a graph')
parser.add_argument('--karger', type=str, metavar='PATH',
                    help='filename of the karger potential')
parser.add_argument('--rw', type=str, metavar='PATH',
                    help='filename of the RW potential')
parser.add_argument('--watershed', type=str, metavar='PATH',
                    help='filename of the watershed segmentation')
parser.add_argument('-o', type=str, metavar='PATH',
                    help='output filename')
parser.add_argument('--betas', type=str,
                    help='beta values to plot')
args = parser.parse_args()
args.betas = args.betas.split()

plt.rcParams.update({'font.size': 22})
fig = plt.figure(figsize=(5 * len(args.betas), 8))
for i, beta in enumerate(args.betas):
    with h5py.File(args.karger + "/" + beta + ".h5", "r") as f:
        karger_pot = f["potential"][()]
        image = f["image"][()]
        seeds = f["seeds"][()].reshape(image.shape[:2])
    with h5py.File(args.rw + "/" + beta + ".h5", "r") as f:
        rw_pot = f["potential"][()]

    plt.subplot(2, len(args.betas) + 1, i + 1)
    plt.imshow(karger_pot.reshape(image.shape[0:2]), interpolation="none", cmap="bwr_r",
               vmin=0, vmax=1)
    plt.axis("off")
    plt.title("Karger, β = " + beta)
    plt.subplot(2, len(args.betas) + 1, i + 2 + len(args.betas))
    plt.imshow(rw_pot.reshape(image.shape[0:2]), interpolation="none", cmap="bwr_r",
               vmin=0, vmax=1)
    plt.axis("off")
    plt.title("RW, β = " + beta)

with h5py.File(args.watershed + "/10.h5", "r") as f:
    watershed = f["potential"][()]
plt.subplot(2, len(args.betas) + 1, len(args.betas) + 1)
im = plt.imshow(2 - watershed.reshape(image.shape[0:2]), interpolation="none", cmap="bwr_r",
                vmin=0, vmax=1)
plt.axis("off")
plt.title("Watershed (RW/\n Karger with $\\beta \\to \\infty$)")
plt.subplot(2, len(args.betas) + 1, 2*len(args.betas) + 2)
plt.imshow(image, interpolation="none")
plt.imshow(-np.ma.masked_where(seeds == 0, seeds), interpolation="none", cmap="bwr_r")
plt.title("Seeds")
plt.axis("off")

#fig.subplots_adjust(right=0.87)
cbar_ax = fig.add_axes([0.94, 0.14, 0.02, 0.72])
fig.colorbar(im, cax=cbar_ax)
plt.tight_layout(rect=[0, 0, 0.9, 1])
plt.savefig(args.o)
