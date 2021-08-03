import argparse
import os
import h5py
import matplotlib.pyplot as plt
import skimage.io
import numpy as np

parser = argparse.ArgumentParser(description='Plot an image with its segmentations')
parser.add_argument('--karger', type=str, metavar='PATH',
                    help='filename of the karger potential, including beta value')
parser.add_argument('--hed', type=str, metavar='PATH',
                    help='filename of the HED file')
parser.add_argument('--rw', type=str, metavar='PATH',
                    help='filename of the RW potential, including beta value')
parser.add_argument('--watershed', type=str, metavar='PATH',
                    help='filename of the watershed segmentation, including beta value')
parser.add_argument('--pw', type=str, metavar='PATH',
                    help='filename of the power watershed potential, including beta value')
parser.add_argument('-o', type=str, metavar='PATH',
                    help='output filename')
args = parser.parse_args()

with h5py.File(args.karger + ".h5", "r") as f:
    karger_pot = f["potential"][()]
    image = f["image"][()]
    seeds = f["seeds"][()].reshape(image.shape[:2])
with h5py.File(args.rw + ".h5", "r") as f:
    rw_pot = f["potential"][()]
with h5py.File(args.pw + ".h5", "r") as f:
    pw_pot = f["potential"][()]
hed = skimage.io.imread(args.hed, as_gray=True)

plt.rcParams.update({'font.size': 14})
plt.figure(figsize=(15, 2.7))

N = 6

plt.subplot(1, N, 1)
plt.imshow(image, interpolation="none")
plt.imshow(np.ma.masked_where(seeds == 0, seeds), interpolation="none", cmap="gray")
plt.axis("off")
plt.title("Seeds")
plt.subplot(1, N, 2)
plt.imshow(image, interpolation="none")
plt.imshow(hed, interpolation="none", cmap="gray")
plt.axis("off")
plt.title("Edges (HED)")
plt.subplot(1, N, 3)
plt.imshow(image, interpolation="none")
plt.contour(karger_pot.reshape(image.shape[0:2]) > 0.5, levels=np.array([0.5]), colors="lime", linewidths=3)
plt.axis("off")
plt.title("Karger")
plt.subplot(1, N, 4)
plt.imshow(image, interpolation="none")
plt.contour(rw_pot.reshape(image.shape[0:2]) > 0.5, levels=np.array([0.5]), colors="lime", linewidths=3)
plt.axis("off")
plt.title("RW")
plt.subplot(1, N, 5)
plt.imshow(image, interpolation="none")
plt.contour(pw_pot.reshape(image.shape[0:2]) > 0.5, levels=np.array([0.5]), colors="lime", linewidths=3)
plt.axis("off")
plt.title("PW")

with h5py.File(args.watershed + ".h5", "r") as f:
    watershed = f["potential"][()]
plt.subplot(1, N, 6)
plt.imshow(image, interpolation="none")
plt.contour(watershed.reshape(image.shape[0:2]), levels=np.array([1.5]), colors="lime", linewidths=3)
plt.axis("off")
plt.title("Watershed")
plt.tight_layout()
os.makedirs(os.path.dirname(args.o), exist_ok=True)
plt.savefig(args.o)
