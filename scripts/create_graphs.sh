#!/bin/bash

set -e

# if $BETAS is set, use that as a default value
GRABCUT_BETAS="${GRABCUT_BETAS:-$BETAS}"
USPS_BETAS="${USPS_BETAS:-$BETAS}"

# First argument must be the image name
function img_to_graph {
    echo "Processing $1"
    # these are the beta values required for the potential plots
    betas="${GRABCUT_BETAS:-0 1 2 5 10 20}"
    mkdir -p "results/graphs/grabcut/$1"
    for beta in $betas; do
        python src/img_to_graph.py "data/images/$1.jpg" \
        --hed "data/hed/$1.jpg" \
        -s "data/seeds/$1.png" \
        -o "results/graphs/grabcut/$1/$beta.h5" \
        --beta "$beta"
    done
}

function all {
    if [[ "$1" == grabcut ]]; then
        for image in $(find data/images -type f -name "*.jpg" -printf "%f\n" | sed 's/\.jpg$//1')
        do
            img_to_graph "$image"
        done
    elif [[ "$1" == usps ]]; then
        # these are the beta values used elsewhere
        # (2 and 5 for Karger/RW and 10 for watershed)
        betas="${USPS_BETAS:-2 5 10}"
        for beta in $betas; do
            echo "Processing USPS with beta=$beta"
            python src/usps_graph.py "$beta"
        done
    else
        echo "Invalid dataset: $1"
        echo "Expected 'grabcut' or 'usps'"
        exit 1
    fi
}

if [[ ! -z "$1" ]]; then
    all "$1"
    exit 0
fi

for dataset in usps grabcut; do
    all "$dataset"
done

