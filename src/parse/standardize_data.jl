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
    df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
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

############################################################################################

# """
#     add_with(df::DataFrame, editor::Add)
#     add_with(df::DataFrame, editor::Array{Add,1})
# This function adds a new column `col` to the DataFrame `df` and adds the value `val`.
# """
# function add_with(df::DataFrame, editor::Array{Add,1})
#     [df[!, x.col] .= x.val for x in editor]
#     return df
# end

# add_with(df::DataFrame, editor::Add) = add_with(df, [editor])



# """
#     map_with(df::DataFrame, x::Map)
#     map_with(df::DataFrame, editor::Array{Map,1})
# This function adds an `output` column containing values based on those in an `input`
# column. The mapping columns `from` -> `to` are contained in a .csv `file` in the core_maps
# directory. The columns `input` and `from` should contain the same values, as should `output`
# and `to`.
# """
# function map_with(df::DataFrame, x::Map)

#     cols = unique(push!(names(df), x.output))

#     df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
#     df_map = rename_with(df_map, [Rename(x.from, x.input), Rename(x.to, x.output)])

#     df[!, x.input] .= strip.(df[:, x.input])
#     df = join(df, df_map, on = x.input, makeunique = true)

#     return df[:, cols]

# end

# function map_with(df::DataFrame, editor::Array{Map,1})
#     for x in editor
#         df = map_with(df, x)
#     end
#     return df
# end



# """
#     melt_with(df::DataFrame, x::Melt)
#     melt_with(df::DataFrame, editor::Array{Melt,1})
# This function normalizes the dataframe by 'melting' columns into rows, lengthening the
# dataframe by duplicating values in the column `on` into new rows and defining 2 new columns:
#     1. `var` with header names from the original dataframe.
#     2. `val` with column values from the original dataframe.
# This operation can only be performed once per dataframe.
# """
# function melt_with(df::DataFrame, editor::Array{Melt,1})
#     df = melt_with(df, editor[1])
#     return df
# end

# function melt_with(df::DataFrame, x::Melt)
#     df = melt(df, x.on, variable_name = x.var, value_name = x.val)
#     df[!, x.var] .= convert_type.(String, df[:, x.var])
#     return df
# end



# """
#     rename_with(df::DataFrame, editor::Rename)
#     rename_with(df::DataFrame, editor::Array{Rename,1})
# This function renames the columns in the DataFrame `df` `from` -> `to`.
# """
# function rename_with(df::DataFrame, editor::Array{Rename,1})
#     rename!(df, [x.from => x.to for x in editor if x.from in names(df)])
#     return df
# end

# rename_with(df::DataFrame, editor::Rename) = rename_with(df, [editor])



# """
#     replace_with(df::DataFrame, editor::Replace)
#     replace_with(df::DataFrame, editor::Array{Replace,1})
# This function replaces values in `col` `from` -> `to`.
# """
# function replace_with(df::DataFrame, editor::Array{Replace,1})
#     [df[!, x.col][df[:, x.col] .== x.from] .= x.to for x in editor]
#     return df
# end

# replace_with(df::DataFrame, editor::Replace) = replace_with(df, [editor])
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
    df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
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

############################################################################################

# """
#     add_with(df::DataFrame, editor::Add)
#     add_with(df::DataFrame, editor::Array{Add,1})
# This function adds a new column `col` to the DataFrame `df` and adds the value `val`.
# """
# function add_with(df::DataFrame, editor::Array{Add,1})
#     [df[!, x.col] .= x.val for x in editor]
#     return df
# end

# add_with(df::DataFrame, editor::Add) = add_with(df, [editor])



# """
#     map_with(df::DataFrame, x::Map)
#     map_with(df::DataFrame, editor::Array{Map,1})
# This function adds an `output` column containing values based on those in an `input`
# column. The mapping columns `from` -> `to` are contained in a .csv `file` in the core_maps
# directory. The columns `input` and `from` should contain the same values, as should `output`
# and `to`.
# """
# function map_with(df::DataFrame, x::Map)

#     cols = unique(push!(names(df), x.output))

#     df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
#     df_map = rename_with(df_map, [Rename(x.from, x.input), Rename(x.to, x.output)])

#     df[!, x.input] .= strip.(df[:, x.input])
#     df = join(df, df_map, on = x.input, makeunique = true)

#     return df[:, cols]

# end

# function map_with(df::DataFrame, editor::Array{Map,1})
#     for x in editor
#         df = map_with(df, x)
#     end
#     return df
# end



# """
#     melt_with(df::DataFrame, x::Melt)
#     melt_with(df::DataFrame, editor::Array{Melt,1})
# This function normalizes the dataframe by 'melting' columns into rows, lengthening the
# dataframe by duplicating values in the column `on` into new rows and defining 2 new columns:
#     1. `var` with header names from the original dataframe.
#     2. `val` with column values from the original dataframe.
# This operation can only be performed once per dataframe.
# """
# function melt_with(df::DataFrame, editor::Array{Melt,1})
#     df = melt_with(df, editor[1])
#     return df
# end

# function melt_with(df::DataFrame, x::Melt)
#     df = melt(df, x.on, variable_name = x.var, value_name = x.val)
#     df[!, x.var] .= convert_type.(String, df[:, x.var])
#     return df
# end



# """
#     rename_with(df::DataFrame, editor::Rename)
#     rename_with(df::DataFrame, editor::Array{Rename,1})
# This function renames the columns in the DataFrame `df` `from` -> `to`.
# """
# function rename_with(df::DataFrame, editor::Array{Rename,1})
#     rename!(df, [x.from => x.to for x in editor if x.from in names(df)])
#     return df
# end

# rename_with(df::DataFrame, editor::Rename) = rename_with(df, [editor])



# """
#     replace_with(df::DataFrame, editor::Replace)
#     replace_with(df::DataFrame, editor::Array{Replace,1})
# This function replaces values in `col` `from` -> `to`.
# """
# function replace_with(df::DataFrame, editor::Array{Replace,1})
#     [df[!, x.col][df[:, x.col] .== x.from] .= x.to for x in editor]
#     return df
# end

# replace_with(df::DataFrame, editor::Replace) = replace_with(df, [editor])
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
    df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
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

############################################################################################

# """
#     add_with(df::DataFrame, editor::Add)
#     add_with(df::DataFrame, editor::Array{Add,1})
# This function adds a new column `col` to the DataFrame `df` and adds the value `val`.
# """
# function add_with(df::DataFrame, editor::Array{Add,1})
#     [df[!, x.col] .= x.val for x in editor]
#     return df
# end

# add_with(df::DataFrame, editor::Add) = add_with(df, [editor])



# """
#     map_with(df::DataFrame, x::Map)
#     map_with(df::DataFrame, editor::Array{Map,1})
# This function adds an `output` column containing values based on those in an `input`
# column. The mapping columns `from` -> `to` are contained in a .csv `file` in the core_maps
# directory. The columns `input` and `from` should contain the same values, as should `output`
# and `to`.
# """
# function map_with(df::DataFrame, x::Map)

#     cols = unique(push!(names(df), x.output))

#     df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
#     df_map = rename_with(df_map, [Rename(x.from, x.input), Rename(x.to, x.output)])

#     df[!, x.input] .= strip.(df[:, x.input])
#     df = join(df, df_map, on = x.input, makeunique = true)

#     return df[:, cols]

# end

# function map_with(df::DataFrame, editor::Array{Map,1})
#     for x in editor
#         df = map_with(df, x)
#     end
#     return df
# end



# """
#     melt_with(df::DataFrame, x::Melt)
#     melt_with(df::DataFrame, editor::Array{Melt,1})
# This function normalizes the dataframe by 'melting' columns into rows, lengthening the
# dataframe by duplicating values in the column `on` into new rows and defining 2 new columns:
#     1. `var` with header names from the original dataframe.
#     2. `val` with column values from the original dataframe.
# This operation can only be performed once per dataframe.
# """
# function melt_with(df::DataFrame, editor::Array{Melt,1})
#     df = melt_with(df, editor[1])
#     return df
# end

# function melt_with(df::DataFrame, x::Melt)
#     df = melt(df, x.on, variable_name = x.var, value_name = x.val)
#     df[!, x.var] .= convert_type.(String, df[:, x.var])
#     return df
# end



# """
#     rename_with(df::DataFrame, editor::Rename)
#     rename_with(df::DataFrame, editor::Array{Rename,1})
# This function renames the columns in the DataFrame `df` `from` -> `to`.
# """
# function rename_with(df::DataFrame, editor::Array{Rename,1})
#     rename!(df, [x.from => x.to for x in editor if x.from in names(df)])
#     return df
# end

# rename_with(df::DataFrame, editor::Rename) = rename_with(df, [editor])



# """
#     replace_with(df::DataFrame, editor::Replace)
#     replace_with(df::DataFrame, editor::Array{Replace,1})
# This function replaces values in `col` `from` -> `to`.
# """
# function replace_with(df::DataFrame, editor::Array{Replace,1})
#     [df[!, x.col][df[:, x.col] .== x.from] .= x.to for x in editor]
#     return df
# end

# replace_with(df::DataFrame, editor::Replace) = replace_with(df, [editor])
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
    df_map = CSV.read(joinpath("..", "data", "coremaps", x.file), silencewarnings = true)
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