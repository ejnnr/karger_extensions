# Extensions of Karger's Algorithm

## Requirements
The easiest way to set up all required packages is to user the
[Docker image](https://hub.docker.com/repository/docker/ejenner/karger_extensions)
we provide. It contains the code, all the preprocessed datasets and all
required packages. To quickly get started (you don't even need to clone this repo):
```
# docker pull ejenner/karger_extensions
# docker run --rm -it ejenner/karger_extensions bash
```
Then inside the Docker container, run `poetry shell`. At this point,
you can skip to [How to run experiments](#how-to-run-experiments) below.

Alternatively, you may want to mount the `src/` and `scripts/` directory
into the Docker container from your local repository (if you want to
make changes to the code). And you might want to mount the `results/` directory
to sync results between the Docker container and your local repo.
In that case, you could do:
```
# docker pull ejenner/karger_extensions:dependencies
# docker run --rm -it \
  --mount type=bind,src=$(pwd)/src,target=/karger_extensions/src \
  --mount type=bind,src=$(pwd)/scripts,target=/karger_extensions/scripts \
  --mount type=bind,src=$(pwd)/results,target=/karger_extensions/results \
  ejenner/karger_extensions:dependencies bash
```
(the `:dependencies` tag contains the packages and the data but *not* the code).
Then again run `poetry shell` and skip to [How to run experiments](#how-to-run-experiments).

If you don't want to use the Docker image, you will need to first install
the required dependencies:
- Julia with the `StatsBase.jl` and `HDF5` packages
- Python 3 with packages:
  - `numpy`
  - `scipy`
  - `scikit-learn`
  - `scikit-image`
  - `matplotlib`
  - `h5py`

We provide a [`poetry`](https://python-poetry.org/) lockfile for all Python packages.
So if you have installed `poetry`, you may run `poetry install` inside this repository
to create a new virtual environment with exactly the same versions of these packages
that we tested the code with. Run `poetry shell` afterwards to activate the new
environment.

Without Docker, you will also need to download the datasets, see the next section.

## Datasets
Run `scripts/prepare_datasets.sh` to download and preprocess all datasets. In addition
to the [Grabcut](https://www.robots.ox.ac.uk/~vgg/data/iseg/) and
[USPS](https://web.stanford.edu/~hastie/StatLearnSparsity_files/DATA/zipcode.html)
datasets, this will download precomputed HED edge weights for the Grabcut images.
If you want to recreate these yourself, you can use https://github.com/sniklaus/pytorch-hed
and save them inside `data/hed`.

## How to run experiments
TL;DR: to replicate all of our results, run `scripts/all.sh`.
However, this runs a lot of experiments you might not need
(in particular, it uses many different beta values).
The results will be written to `results/grabcut.json`
and `results/usps.json` for the metrics and to `fig` for the figures.
This will use the optimal beta values we found.

In more detail, the pipeline consists of the following steps:
- `scripts/create_graphs.sh`: calculate the graph weights based on
  the Grabcut / USPS images
- `scripts/potentials.sh`: run the four different algorithms
  and calculate the potentials / segmentations they predict for
  all existing graphs (generated in the previous step)
- `scripts/metrics.sh`: Calculate the metrics we report in the paper
  for the Grabcut and USPS dataset
- `scripts/potential_plots.sh`: create plots of the Karger and RW
  potentials for all Grabcut images (for different beta values)
- `scripts/segmentation_plots.sh`: create comparison plots of the
  segmentation results of the four algorithm for all Grabcut images

`potentials` requires `create_graphs` to be run first, and the other
three scripts all requires `potentials` to be run first.

`create_graphs.sh`, `potentials.sh` and `metrics.sh` all take an optional
argument, which can be either `usps` or `grabcut`. If given, only that dataset
is processed, otherwise, both datasets are. The plotting scripts only apply
to Grabcut anyway.

`create_graphs` takes into account a `BETAS` environment variable
if it exists, which you can use to specify which beta values to
generate graphs for. For example,
```
BETAS="10 20 30" scripts/create_graphs.sh
```
You can also specify `GRABCUT_BETAS` and `USPS_BETAS` separately.
`potentials.sh` will automatically detect which graphs exist and
apply the algorithms to all the ones that do.

`metrics.sh` and `segmentation_plots.sh` by default use the optimal
beta values we report in our paper. If you want segmentations or
results for other beta values, you need to change the corresponding
Python/Bash files.

Finally, `potential_plots.sh` also respects the `BETAS` and `GRABCUT_BETAS`
environment variable (which in this case are synonymous).
It will plot potentials for the specified beta values, but the
Karger/RW results with those beta values already need to exist beforehand!

The default value everywhere is `BETAS=0 1 2 5 10 20`, which is required
to reproduce the potential plot from the paper (and also suffices
for all the metrics).

In addition to the beta values, you can also configure the number of runs
used for Karger's algorithm by setting `KARGER_RUNS`, e.g.
```
KARGER_RUNS=200 scripts/potentials.sh
```
This is only relevant for `potentials.sh`. The default is 100, as a
tradeoff to keep errors reasonably low but also keep the runtime down.

## Overview of repository contents
- `scripts/`: bash scripts to easily prepare the data and run all experiments
- `data/`: place for the datasets, can be populated automatically with `scripts/prepare_datasets.sh`
- `results/`: place where the scripts will store intermediate and final results
- `src`: all the source files. You don't need to interact with these directly
  if you only want to run our experiments, use `scripts/` instead.
