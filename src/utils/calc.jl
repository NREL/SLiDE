using CSV
using DataFrames
using DelimitedFiles
using YAML
using Query

"""
    sum_over(df::DataFrame, col::Array{Symbol,1}; kwargs...)
    sum_over(df::DataFrame, col::Symbol; kwargs...)
This function sums a DataFrame over the specified column(s) and returns either
a list of values or the full DataFrame.

# Arguments:
- `df::DataFrame`: DataFrame to sum.
- `col::Symbol` or `col::Array{Symbol,1}`: columns over which to sum.

# Keyword Arguments:
- `values_only::Bool = true`: Should the function return a list of values or an altered DataFrame?
    - Set to `true` (default) if populating an existing DataFrame including all of the
        columns in the input DataFrame (in the same order) with the exception of that/those
        in `col`.
    - Set to `false` if modifying or copying the input DataFrame.

# Returns:
- `lst::Array{Float64,1}` of summed values in the order determined by the descriptor columns
    if `values_only = true` (default)
- `df::DataFrame`: Modified input DataFrame if `values_only = false`
"""
function sum_over(df::DataFrame, col::Array{Symbol,1}; values_only = true, keepkeys = false)

    inp_keys = df[:,find_oftype(df, Not(AbstractFloat))]
    val_cols = find_oftype(df, AbstractFloat)
    by_cols = setdiff(names(df), [col; val_cols])

    df = by(df, by_cols, Pair.(val_cols, sum))
    df = edit_with(df, Rename.(setdiff(names(df), by_cols), val_cols))

    keepkeys && (df = join(inp_keys, df, on = by_cols, kind = :left))
    return values_only ? df[:,val_cols[1]] : df
end

function sum_over(df::DataFrame, col::Symbol; values_only = true, keepkeys = false)
    return sum_over(df, [col]; values_only = values_only, keepkeys = keepkeys)
end