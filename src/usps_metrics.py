import os
import json
import h5py
import numpy as np
from scipy.special import xlogy
from sklearn import metrics
from sklearn.metrics.cluster import pair_confusion_matrix

scores = {
    "accuracy": (lambda x, y: np.sum(x == y) / len(x)),
    }

methods = ["karger", "RW", "watershed", "power_watershed"]
ls = [20, 40, 100, 200]
betas = {
    "karger": 2,
    "RW": 5,
    "watershed": 10,
    "power_watershed": 10,
}
N = 20
data = {l:
        {method:
         {score: [] for score in scores}
         for method in methods}
        for l in ls}
error = {l:
         {method:
          {score: [] for score in scores}
          for method in methods}
         for l in ls}

segmentations = {}

for l in ls:
    for i in range(N):
        path = f"{l}_{i}"
        with h5py.File(f"results/karger_potentials/usps/{path}/{betas['karger']}.h5", "r") as f:
            segmentations["karger"] = f["segmentation"][()]
        with h5py.File(f"results/graphs/usps/{path}/{betas['watershed']}.h5", "r") as f:
            seeds = f["seeds"][()]
            gt = f["ground_truth"][()]
        with h5py.File(f"results/rw_potentials/usps/{path}/{betas['RW']}.h5", "r") as f:
            segmentations["RW"] = f["segmentation"][()]
        with h5py.File(f"results/watershed/usps/{path}/{betas['watershed']}.h5", "r") as f:
            segmentations["watershed"] = f["potential"][()]
        with h5py.File(f"results/power_watershed/usps/{path}/{betas['power_watershed']}.h5", "r") as f:
            segmentations["power_watershed"] = f["segmentation"][()]

        mask = (seeds == 0)
        for method, seg in segmentations.items():
            for score, func in scores.items():
                data[l][method][score].append(func(gt[mask], seg[mask]))

    error[l] = {k: {k_: np.std(v_)/np.sqrt(N) for k_, v_ in v.items()} for k, v in data[l].items()}
    data[l] = {k: {k_: np.mean(v_) for k_, v_ in v.items()} for k, v in data[l].items()}

with open('results/power_watershed_usps.json', 'w', encoding='utf-8') as f:
    json.dump({"data": data, "errors": error}, f, ensure_ascii=False, indent=4)
