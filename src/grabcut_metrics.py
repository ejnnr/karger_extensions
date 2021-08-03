import os
import json
import h5py
import numpy as np
import skimage.io
from sklearn import metrics


def entropy(x):
    p1 = np.sum(x) / len(x)
    p = np.array([p1, 1 - p1])
    return -np.sum(p * np.log(p))


def VOI(x, y):
    return entropy(x) + entropy(y) - 2 * metrics.mutual_info_score(x, y)


scores = {
    "RAI": metrics.adjusted_rand_score,
    "accuracy": (lambda x, y: np.sum(x == y) / len(x)),
    "VOI": VOI
    }

methods = ["karger", "RW", "watershed", "power_watershed"]
data = {method: {score: [] for score in scores} for method in methods}
betas = {
    "karger": 10,
    "RW": 20,
    "watershed": 10,
    "power_watershed": 10,
}

segmentations = {}

for path in (f.name for f in os.scandir("results/karger_potentials/grabcut") if f.is_dir()):
    gt = (skimage.io.imread("data/ground_truth/" + path + ".bmp", as_gray=True).ravel() > 0)
    with h5py.File("results/karger_potentials/grabcut/" + path + "/" + str(betas["karger"]) + ".h5", "r") as f:
        segmentations["karger"] = (f["potential"][:] < 0.5).ravel()
        seeds = f["seeds"][()]
    with h5py.File("results/rw_potentials/grabcut/" + path + "/" + str(betas["RW"]) + ".h5", "r") as f:
        segmentations["RW"] = (f["potential"][:] < 0.5).ravel()
    with h5py.File("results/watershed/grabcut/" + path + "/" + str(betas["watershed"]) + ".h5", "r") as f:
        segmentations["watershed"] = (f["potential"][:] - 1).ravel()
    with h5py.File("results/power_watershed/grabcut/" + path + "/" + str(betas["power_watershed"]) + ".h5", "r") as f:
        segmentations["power_watershed"] = (f["potential"][:] < 0.5).ravel()

    mask = (seeds == 0)
    for method, seg in segmentations.items():
        for score, func in scores.items():
            data[method][score].append(func(seg[mask], gt[mask]))

N = 49
error = {k: {k_: np.std(v_)/np.sqrt(N) for k_, v_ in v.items()} for k, v in data.items()}
data = {k: {k_: np.mean(v_) for k_, v_ in v.items()} for k, v in data.items()}

with open('results/grabcut.json', 'w', encoding='utf-8') as f:
    json.dump({"data": data, "errors": error}, f, ensure_ascii=False, indent=4)
