using HDF5
using Random
include("./karger.jl")
using .Karger

# USAGE: julia src/julia/calculate_potential.jl filename N
# where N is the number of samples to use and filename just the name (without path or .h5).
# The file has to be an HDF5 file with fields n, edges, weights and seeds. The output
# will be written in a file with the same name in the "potentials" directory

Random.seed!(0)

graph_path = "results/graphs/" * ARGS[1] * ".h5"
result_path = "results/karger_potentials/" * ARGS[1] * ".h5"

n = h5read(graph_path, "n")
edges = h5read(graph_path, "edges")
weights = h5read(graph_path, "weights")
seeds = h5read(graph_path, "seeds")
g = Graph(n, transpose(edges) .+ 1, weights)
mkpath(dirname(result_path))
cp(graph_path, result_path, force=true)
pots = potential(g, parse(Int, ARGS[2]), seeds)
segmentation = Vector{Int}(undef, n)
max_pots = zeros(n)
for (key, pot) in pots
    h5write(result_path, "potential/" * string(key), pot)
    for i in 1:n
        if pot[i] > max_pots[i]
            segmentation[i] = key
            max_pots[i] = pot[i]
        end
    end
end
h5write(result_path, "segmentation", segmentation)
