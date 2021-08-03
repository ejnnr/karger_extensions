import os
import sys
import h5py
import numpy as np
from sklearn.neighbors import kneighbors_graph
import scipy

np.random.seed(0)
os.makedirs("results/graphs/usps", exist_ok=True)

n = 7291
beta = float(sys.argv[1])
with h5py.File("data/usps.h5", "r") as f:
    data = f["data"][:] * 255
    labels = f["labels"][:].astype(np.int64)
    # Ugly hack: we want to use the 0 label later as "no seed"
    labels += 1

graph = kneighbors_graph(data, 10, mode="distance", include_self=False)
rows, cols, vals = scipy.sparse.find(graph)
vals = vals ** 2
max_dist = np.max(vals)
edges = np.stack([rows, cols], axis=0)
weights = np.exp(-beta * vals / max_dist)

for l in [20, 40, 100, 200]:
    for i in range(20):
        mask = np.full(n, False)
        mask[:l] = True
        np.random.shuffle(mask)
        # reshuffle until every label is present
        while set(labels[mask]) != set(range(1, 11)):
            np.random.shuffle(mask)
        seeds = np.zeros(n, dtype=np.int64)
        seeds[mask] = labels[mask]

        os.makedirs(f"results/graphs/usps/{l}_{i}", exist_ok=True)
        # Remove the hdf5 file if it exists, to avoid errors from h5py
        try:
            os.remove(f"results/graphs/usps/{l}_{i}/{int(beta)}.h5")
        except OSError:
            pass

        with h5py.File(f"results/graphs/usps/{l}_{i}/{int(beta)}.h5", "w") as f:
            f.create_dataset("n", data=n)
            f.create_dataset("edges", data=edges)
            f.create_dataset("weights", data=weights)
            f.create_dataset("seeds", data=seeds)
            f.create_dataset("ground_truth", data=labels)
