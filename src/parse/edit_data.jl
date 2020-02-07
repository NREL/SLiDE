"""
    edit_with(df::DataFrame, x::Add)
This method adds a new column `col` to the DataFrame `df` and adds the value `val`.
"""
function edit_with(df::DataFrame, x::Add)
    df[!, x.col] .= x.val
    return df
end

"""
    edit_with(df::DataFrame, x::Group)
This method is useful for editing files where data might be grouped in successive dataframes
with an identifying header cell or row.

UPDATE?
"""

# Example:
# ```jldoctest
# julia> using SLiDE, DataFrames

# julia> df = DataFrame(sector = ["Colorado", "A", "B", "Wisconsin", "A", "B"],
#                       value = ["", 1, 2, "", 3, 4])
# 6×2 DataFrame
# │ Row │ sector    │ value │
# │     │ String    │ Any   │
# ├─────┼───────────┼───────┤
# │ 1   │ Colorado  │       │
# │ 2   │ A         │ 1     │
# │ 3   │ B         │ 2     │
# │ 4   │ Wisconsin │       │
# │ 5   │ A         │ 3     │
# │ 6   │ B         │ 4     │

# julia> x = Group(file = "regions.csv", from = :from, to = :to,
#                  input = :sector, output = :region);

# julia> df = SLiDE.edit_with(df, x)
# 4×3 DataFrame
# │ Row │ sector │ value │ region │
# │     │ String │ Any   │ String │
# ├─────┼────────┼───────┼────────┤
# │ 1   │ A      │ 1     │ co     │
# │ 2   │ B      │ 2     │ co     │
# │ 3   │ A      │ 3     │ wi     │
# │ 4   │ B      │ 4     │ wi     │
# ```

function edit_with(df::DataFrame, x::Group)
    
    # First, add a column to the original DataFrame to indicate where the DataFrame group
    # begins.
    cols = unique(push!(names(df), x.output))
    df[!,:start] = (1:size(df)[1]) .+ 1

    # Next, create a DataFrame describing where to "split" the input DataFrame.
    # Editing with a map will remove all rows that do not contain relevant information.
    df_split = edit_with(df, Map(x.file, x.from, x.to, x.input, x.output));
    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    # 
    df[!,x.output] .= ""
    [df[row[:start]:row[:stop], x.output] .= row[x.output] for row in eachrow(df_split)]

    # Finally, remove header rows (these will be blank in the output column),
    # as well as the column describing where the sub-DataFrames begin.
    df = df[df[:,x.output] .!= "", :]
    return df[:, cols]

end

"""
    edit_with(df::DataFrame, x::Join)
This method edits `df` by joining...
"""
function edit_with(df::DataFrame, x::Join)

    # Read the map file from data/coremaps. Use the Rename method of edit_with() to
    # prepend the column names of the mapping DataFrame with the Join prefix.
    df_map = read_file(x)
    df_map = edit_with(df_map, Rename.(names(df_map), Symbol.(x.prefix, "_", names(df_map))))

    df[!, x.on] .= strip.(df[:, x.on])
    df = join(df, df_map, on = x.on, makeunique = true)

    return df
end

"""
    edit_with(df::DataFrame, x::Map)
This method adds an `output` column containing values based on those in an `input`
column. The mapping columns `from` -> `to` are contained in a .csv `file` in the core_maps
directory. The columns `input` and `from` should contain the same values, as should `output`
and `to`.
"""
function edit_with(df::DataFrame, x::Map)

    # Save the column names in the input dataframe and add the output column. This will
    # avoid including unnecessary output columns from the map file in the result.
    cols = unique(push!(names(df), x.output))

    # Read the map file from data/coremaps.
    df_map = read_file(x)
    
    # Rename the input column in the DataFrame to edit to match that in the mapping df.
    # This approach was taken as opposed to editing the mapping df to avoid errors in case
    # the input and output column names are the same. Such is the case if mapping is used to
    # edit column values for consistency without adding a new column to the DataFrame.
    # Remove excess blank space from the input column to ensure consistency when mapping.
    # Use the DataFrame join operation to merge the two dataframes.
    df = edit_with(df, Rename(x.input, x.from))
    df[!, x.from] .= strip.(df[:, x.from])
    df = join(df, df_map, on = x.from, makeunique = true)

    # Return the DataFrame with the columns saved at the top of the method.
    df = x.input == x.output ? edit_with(df, Rename(x.to, x.output)) :
        edit_with(df, Rename.([x.from, x.to], [x.input, x.output]))
    
    return df[:, cols]

    # !!!! Alternate method
    # dict_map = Dict(k => v for (k, v) in zip(df_map[!, xfrom], df_map[!, xto]))
    # df[!, x.output] = map(x -> dict_map[x], df[!, x.input])

end

"""
    edit_with(df::DataFrame, x::Melt)
This method normalizes the dataframe by 'melting' columns into rows, lengthening the
dataframe by duplicating values in the column `on` into new rows and defining 2 new columns:

1. `var` with header names from the original dataframe.
2. `val` with column values from the original dataframe.

This operation can only be performed once per dataframe.
"""
function edit_with(df::DataFrame, x::Melt)
    on = intersect(x.on, names(df))  # Ensure all "melt" columns are in df.
    df = melt(df, on, variable_name = x.var, value_name = x.val)
    df[!, x.var] .= convert_type.(String, df[:, x.var])
    return df
end

"""
    edit_with(df::DataFrame, editor::Rename)
This method renames the columns in the DataFrame `df` `from` -> `to`.
"""
function edit_with(df::DataFrame, x::Rename)
    x.from in names(df) ? rename!(df, x.from => x.to) : nothing
    return df
end

"""
    edit_with(df::DataFrame, x::Replace)
This method replaces values in `col` `from` -> `to`.
"""
function edit_with(df::DataFrame, x::Replace)
    x.col in names(df) ? df[!, x.col][df[:, x.col] .== x.from] .= x.to : nothing
    return df
end

"""
    edit_with(df::DataFrame, lst::Array{T}) where {T<:Edit}
This method iterates through a list of editors and returns the DataFrame `df` after all
edits have been made.
"""
function edit_with(df::DataFrame, lst::Array{T}) where {T<:Edit}
    [df = edit_with(df, x) for x in lst]
    return df
end