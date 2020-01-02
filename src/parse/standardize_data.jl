import InfrastructureSystems
const IS = InfrastructureSystems

using DataFrames
using YAML

begin


"""
    add_with(df::DataFrame, editor::Add)
    add_with(df::DataFrame, editor::Array{Add,1})
This function adds a new column `col` to the DataFrame `df` and adds the value `val`.
"""
function add_with(df::DataFrame, editor::Array{Add,1})
    [df[!, x.col] .= x.val for x in editor]
    return df
end

add_with(df::DataFrame, editor::Add) = add_with(df, [editor])



"""
    melt_with(df::DataFrame, x::Melt)
    melt_with(df::DataFrame, editor::Array{Melt,1})
This function normalizes the dataframe by 'melting' columns into rows, lengthening the
dataframe by duplicating values in the column `on` into new rows and defining 2 new columns:
    1. `var` with header names from the original dataframe.
    2. `val` with column values from the original dataframe.
This operation can only be performed once per dataframe.
"""
function melt_with(df::DataFrame, editor::Array{Melt,1})
    df = melt_with(df, editor[1])
    return df
end

function melt_with(df::DataFrame, x::Melt)
    df = melt(df, x.on, variable_name = x.var, value_name = x.val)
    return df
end



"""
    rename_with(df::DataFrame, editor::Rename)
    rename_with(df::DataFrame, editor::Array{Rename,1})
This function renames the columns in the DataFrame `df` `from` -> `to`.
"""
function rename_with(df::DataFrame, editor::Array{Rename,1})
    rename!(df, [x.from => x.to for x in editor if x.from in names(df)])
    return df
end

rename_with(df::DataFrame, editor::Rename) = rename_with(df, [editor])



"""
    replace_with(df::DataFrame, editor::Replace)
    replace_with(df::DataFrame, editor::Array{Replace,1})
This function replaces values in `col` `from` -> `to`.
"""
function replace_with(df::DataFrame, editor::Array{Replace,1})
    [df[!, x.col][df[:, x.col] .== x.from] .= x.to for x in editor]
    return df
end

replace_with(df::DataFrame, editor::Replace) = replace_with(df, [editor])

end