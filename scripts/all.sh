#!/bin/bash

set -e

scripts/create_graphs.sh "$1"
scripts/potentials.sh "$1"
scripts/metrics.sh "$1"
scripts/segmentation_plots.sh "$1"
scripts/potential_plots.sh "$1"
