#!/bin/bash

set -e

function metric {
    if [[ "$1" == grabcut ]]; then
        python src/grabcut_metrics.py
    elif [[ "$1" == usps ]]; then
        python src/usps_metrics.py
    else
        echo "Invalid dataset: $1"
        echo "Expected 'grabcut' or 'usps'"
        exit 1
    fi
}

if [[ ! -z "$1" ]]; then
    metric "$1"
    exit 0
fi

for dataset in "usps grabcut"; do
    metric "$dataset"
done