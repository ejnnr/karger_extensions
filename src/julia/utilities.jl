using StatsBase
using Random

function choose_random_index(weights)
    return sample(1:length(weights), Weights(weights))
end

const UnionFind = Vector{Int}

function UnionFind(n :: Int)
    return collect(1:n)
end

function find(uf :: UnionFind, node :: Int)
    while node != uf[node]
        node, uf[node] = uf[node], uf[uf[node]]
    end
    return node
end

function union!(uf :: UnionFind, node1 :: Int, node2 :: Int)
    root1 = find(uf, node1)
    root2 = find(uf, node2)
    if root1 == root2
        return false
    else
        uf[root2] = root1
        return true
    end
end

function labels(uf :: UnionFind)
    res = zeros(Int, length(uf))
    for i in 1:length(res)
        res[i] = find(uf, i)
    end
    return res
end

function find_components!(edges :: Matrix{Int}, uf :: UnionFind, label_buffer :: Vector{Int}, uf_ :: Vector{Int})
    # Find the connected components of a graph
    uf_ .= uf
    # the cluster array stores whether each node is part of a newly formed
    # cluster (i.e. a plateau), rather than one that was already present in uf
    fill!(label_buffer, 0)

    for i in 1:size(edges, 2)
        u, v = edges[:, i]
        union!(uf_, u, v)
        label_buffer[find(uf, u)] = 1
        label_buffer[find(uf, v)] = 1
    end

    for i in 1:length(uf)
        if label_buffer[find(uf, i)] > 0
            label_buffer[i] = find(uf_, i)
        end
    end

    return label_buffer
end

function find_plateaus!(weights :: Vector{Float64}, edges :: Matrix{Int}, uf :: UnionFind, label_buffer :: Vector{Int}, uf_buffer :: Vector{Int})
    # weights is assumed to be an array of edge weights
    # sorted descendingly and edges the corresponding 2 x M edge array.
    # This function finds the plateaus of maximal edge weights,
    # i.e. the connected subgraphs in which all edges have equal and
    # maximal weight.
    n = length(uf)

    # first, we just figure out how many edges have the same (maximal) weight
    num_edges = 1
    for i in 1:length(weights)
        if weights[i] < weights[1]
            break
        end
        num_edges = i
    end

    # Next, we find the connected components, i.e. the individual plateaus.
    # The is_plateau variable records whether each node belongs to a plateau.
    # But this is only recorded for root nodes, so use is_plateau[find(uf, node_id)].
    # components stores labels for each node, associating it to a connected component
    find_components!(edges[:, 1:num_edges], uf, label_buffer, uf_buffer)
    # dictionary mapping the label of the plateau (which are meaningless
    # integers) to the set of nodes in them
    plateau_nodes = Dict{Int, Set{Int}}()
    for i in 1:n
        node = find(uf, i)
        label = label_buffer[i]
        if label > 0
            if haskey(plateau_nodes, label)
                # we want to add the root node to the set of plateau nodes,
                # not all child nodes (since each cluster should only occur once).
                # So we use node here instead of i.
                push!(plateau_nodes[label], node)
            else
                plateau_nodes[label] = Set([node])
            end
        end
    end

    plateau_nodes_ = Dict{Int, Vector{Int}}()
    for (key, val) in plateau_nodes
        plateau_nodes_[key] = collect(val)
    end

    # and the same for edges; note that we store the index of the edge,
    # not the edge itself
    plateau_edges = Dict{Int, Set{Int}}()
    for i in 1:num_edges
        # each edge belongs to exactly one plateau, namely the one
        # that both of its nodes belong to
        label = label_buffer[edges[1, i]]
        if haskey(plateau_edges, label)
            push!(plateau_edges[label], i)
        else
            plateau_edges[label] = Set([i])
        end
    end
    return plateau_nodes_, plateau_edges, num_edges
end