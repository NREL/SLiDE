"""
    edit_with(df::DataFrame, x::Add)
This method adds a new column `col` to the DataFrame `df` and adds the value `val`.
"""
function edit_with(df::DataFrame, x::Add)
    df[!, x.col] .= x.val
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

    # Read the map file from data/coremaps. Use the Rename method of the edit_with()
    # function to ensure that the target and map dataframe column names are consistent.
    MAP_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")),
        "..", "data", "coremaps"))
    df_map = CSV.read(joinpath(MAP_DIR, x.file), silencewarnings = true)
    df_map = edit_with(df_map, [Rename(x.from, x.input), Rename(x.to, x.output)])
    
    # Remove excess blank space from the input column to ensure consistency when mapping.
    # Use the DataFrame join operation to merge the two dataframes.
    df[!, x.input] .= strip.(df[:, x.input])
    df = join(df, df_map, on = x.input, makeunique = true)

    # Return the DataFrame with the columns saved at the top of the method.
    return df[:, cols]

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
    df = melt(df, x.on, variable_name = x.var, value_name = x.val)
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