#!/bin/bash

set -e

GRABCUT_BETAS="${GRABCUT_BETAS:-$BETAS}"

# First argument must be the image name
function potential_plot {
    betas="${GRABCUT_BETAS:-0 1 2 5 10 20}"
	python src/plot_potentials.py \
    	--karger "results/karger_potentials/grabcut/$1" \
    	--rw "results/rw_potentials/grabcut/$1" \
    	--watershed "results/watershed/grabcut/$1" \
    	--betas "$betas" \
    	-o "fig/potentials/$1.png"
}

# If an argument is supplied, only create pipeline for that image
if [[ ! -z "$1" ]]; then
    potential_plot "$1"
    exit 0
fi

for image in $(find data/images -type f -name "*.jpg" -printf "%f\n" | sed 's/\.jpg$//1')
do
    potential_plot "$image"
done
