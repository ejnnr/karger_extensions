#!/bin/bash

set -e

# First argument must be the folder name, second one the graph name
function karger {
	echo "Karger for $1"
	JULIA_NUM_THREADS=4 julia src/julia/calculate_potential.jl \
		"$1" "${KARGER_RUNS:-100}"
}

function karger_multi {
	echo "Karger for $1"
	JULIA_NUM_THREADS=4 julia src/julia/calculate_all_potentials.jl "$1" "${KARGER_RUNS:-100}"
}

function rw {
	echo "RW for $1"
	python src/calculate_rw_potential.py \
		"results/graphs/$1.h5" \
		-o "results/rw_potentials/$1.h5"
}
function rw_multi {
	echo "RW for $1"
	python src/calculate_all_rw_potentials.py \
		"results/graphs/$1.h5" \
		-o "results/rw_potentials/$1.h5"
}

function watershed {
	echo "Watershed for $1"
	julia src/julia/calculate_watershed.jl "$1"
}

function power_watershed {
	echo "Power Watershed for $1"
	julia src/julia/calculate_power_watershed.jl "$1"
}

function power_watershed_multi {
	echo "Power Watershed for $1"
	julia src/julia/calculate_power_watershed_multi.jl "$1"
}

# argument should be a directory, either 'grabcut' or 'usps'
function all {
	for file in $(find results/graphs/$1 -type f -path "*.h5" -printf "%P\n" | sed 's/\.h5$//1')
	do
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
	done
}

if [[ ! -z "$1" ]]; then
    all "$1"
    exit 0
fi

for dataset in usps grabcut; do
    all "$dataset"
done