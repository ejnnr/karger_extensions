#!/bin/bash

set -e

# First argument must be the folder name, second one the graph name
function karger {
    mkdir -p "results/karger/$1"
	JULIA_NUM_THREADS=4 julia src/julia/calculate_potential.jl \
		"$1" 1000
}

function karger_multi {
    mkdir -p "results/karger/$1"
	JULIA_NUM_THREADS=4 julia src/julia/calculate_all_potentials.jl "$1" 100
}

function rw {
    mkdir -p "results/rw/$1"
	python src/calculate_rw_potential.py \
		"data/graphs/$1.h5" \
		-o "results/rw_potentials/$1.h5"
}
function rw_multi {
    mkdir -p "results/rw/$1"
	python src/calculate_all_rw_potentials.py \
		"data/graphs/$1.h5" \
		-o "results/rw_potentials/$1.h5"
}

function watershed {
    mkdir -p "results/watershed/$1"
	julia src/julia/calculate_watershed.jl "$1"
}

function power_watershed {
    mkdir -p "results/power_watershed/$1"
	julia src/julia/calculate_power_watershed.jl "$1"
}

function power_watershed_multi {
    mkdir -p "results/power_watershed/$1"
	julia src/julia/calculate_power_watershed_multi.jl "$1"
}

# argument should be a directory, either 'grabcut' or 'usps'
function all {
	for file in $(find data/graphs/$1 -type f -path "*.h5" -printf "%P\n" | sed 's/\.h5$//1')
		if [[ "$1" == grabcut ]]; then
			karger "$1/$file"
			rw "$1/$file"
			# we use the beta=10 version for watershed
			# doesn't really matter which one, the point is that
			# we only need to run it for one beta value
			if [[ "$file" == */10 ]]; then
				watershed "$1/$file"
				power_watershed "$1/$file"
			fi
		elif [[ "$1" == usps ]]; then
			karger_multi "$1/$file"
			rw_multi "$1/$file"
			if [[ "$file" == */10 ]]; then
				watershed "$1/$file"
				power_watershed_multi "$1/$file"
			fi
		else
			echo "Invalid dataset: $1"
			echo "Expected 'grabcut' or 'usps'"
			exit 1
		fi
	do
	done
}

if [[ ! -z "$1" ]]; then
    all "$1"
    exit 0
fi

for dataset in "usps grabcut"; do
    all "$dataset"
done