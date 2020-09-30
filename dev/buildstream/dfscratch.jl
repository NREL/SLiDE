using DataFrames
using Statistics

# https://juliadata.github.io/DataFrames.jl/stable/man/joins/

df = DataFrame(i = 1:10, x = rand(10), y = rand(["a", "b", "c"], 10))

