#!/bin/bash

set -e

# First argument must be the image name
function segmentation_plot {
	python src/plot_segmentation.py \
		--karger "results/karger_potentials/grabcut/$1/10" \
		--rw "results/rw_potentials/grabcut/$1/20" \
		--watershed "results/watershed/grabcut/$1/10" \
		--pw "results/power_watershed/grabcut/$1/10" \
		--hed "data/hed/$1.jpg" \
    	-o "fig/segmentations/$1.png"
}

# If an argument is supplied, only create pipeline for that image
if [[ ! -z "$1" ]]; then
    segmentation_plot "$1"
    exit 0
fi

for image in $(find data/images -type f -name "*.jpg" -printf "%f\n" | sed 's/\.jpg$//1')
do
    segmentation_plot "$image"
done
