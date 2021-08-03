import h5py
import numpy as np

usps = np.loadtxt("data/zip.train")
data = usps[:, 1:]
# map intensities from [-1, 1] to [0, 1] range
data = (data + 1) / 2
labels = usps[:, 0].astype(int)

with h5py.File("data/usps.h5", "w") as f:
    f.create_dataset("data", data=data)
    f.create_dataset("labels", data=labels)
