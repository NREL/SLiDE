"""
    edit_with(y::Dict{Any,Any}; kwargs...)
    edit_with(df::DataFrame, editor::T) where T<:Edit
    edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    edit_with(file::T, y::Dict{Any,Any}; kwargs...)
    edit_with(files::Array{T,N} where N, y::Dict{Any,Any}; kwargs...) where T<:File

This function edits the input DataFrame `df` and returns the resultant DataFrame.

# Arguments

- `df::DataFrame`: The DataFrame on which to perform the edit.
- `editor::T where T<:Edit`: DataType containing information about which edit to perform. The following edit options are available and detailed below:
    - [`SLiDE.Add`](@ref): Add new column `col` filled with `val`.
    - [`SLiDE.Describe`](@ref): This DataType is required when multiple DataFrames will be
        appended into one output file (say, if multiple sheets from an XLSX file are
        included). Before the DataFrames are appended, a column `col` will be added and
        filled with the value in the file descriptor.
    - [`SLiDE.Group`](@ref): Use to edit files containing data in successive dataframes with
        an identifying header cell or row.
    - [`SLiDE.Map`](@ref): Define an `output` column containing values based on those in an
        `input` column. The mapping columns `from` -> `to` are contained in a .csv `file` in
        the coremaps directory. The columns `input` and `from` should contain the same
        values, as should `output` and `to`.
    - [`SLiDE.Melt`](@ref): Normalize the dataframe by 'melting' columns into rows, 
        lengthening the dataframe by duplicating values in the column `on` into new rows and
        defining 2 new columns:
        1. `var` with header names from the original dataframe.
        2. `val` with column values from the original dataframe.
    - [`SLiDE.Order`](@ref): Rearranges columns in the order specified by `cols` and sets
        them to the specified type.
    - [`SLiDE.Rename`](@ref): Change column name `from` -> `to`.
    - [`SLiDE.Replace`](@ref): Replace values in `col` `from` -> `to`.
- `file::T where T <: File`: Data file containing information to read.
- `files::Array{T} where T <: File`: List of data files.
- `y::Dict{Any,Any}`: Dictionary containing all editing structures among other values read
    from the yaml file. Dictionary keys must correspond EXACTLY with SLiDE.Edit DataType
    names, or the edits will not be made.

# Keywords

- `shorten::Bool = false` or `shorten::Int`: if an integer length is specified, the
    DataFrame will be shortened to the input value. This is meant to aid troubleshooting
    during development.

# Returns

- `df::DataFrame`: including edit(s)
"""
function edit_with(df::DataFrame, x::Add)
    df[!, x.col] .= x.val
    return df
end

function edit_with(df::DataFrame, x::Drop)
    # Ternary operator:
    # https://discourse.julialang.org/t/style-question-ternary-operator-or-short-circuit-operator-or-if-end/34224/2
    !(x.col in names(df)) && (return df)
    if x.val === "all"  # Drop entire column to remove dead weight right away.
        df = df[:, setdiff(names(df), [x.col])]
    else  # Drop rows using an operation or based on a value.
        if x.val === missing
            dropmissing!(df, x.col)
        elseif x.val === "unique"
            unique!(df, x.col)
        else
            df = if x.operation == "occursin"
                df[.!broadcast(datatype(x.operation), x.val, df[:,x.col]), :]
            else
                df[.!broadcast(datatype(x.operation), df[:,x.col], x.val), :]
            end
        end
    end
    return df
end

function edit_with(df::DataFrame, x::Group)
    # First, add a column to the original DataFrame indicating where the data set begins.
    cols = unique(push!(names(df), x.output))
    df[!,:start] = (1:size(df)[1]) .+ 1

    # Next, create a DataFrame describing where to "split" the input DataFrame.
    # Editing with a map will remove all rows that do not contain relevant information.
    # Add a column indicating where each data set STOPS, assuming all completely blank rows
    # were removed by read_file().
    df_split = edit_with(copy(df), Map(x.file, [x.from], [x.to], [x.input], [x.output]); kind = :inner);
    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    # Add a new, blank output column to store identifying information about the data block.
    # Then, fill this column based on the identifying row numbers in df_split.
    df[!,x.output] .= ""
    [df[row[:start]:row[:stop], x.output] .= row[x.output] for row in eachrow(df_split)]

    # Finally, remove header rows (these will be blank in the output column),
    # as well as the column describing where the sub-DataFrames begin.
    df = df[df[:,x.output] .!= "", :]
    return df[:, cols]
end

function edit_with(df::DataFrame, x::Map; kind = :left)
    # Save all input column names, read the map file, and isolate relevant columns.
    # # This prevents duplicate columns in the final DataFrame.
    cols = unique([names(df); x.output])
    df_map = copy(read_file(x))
    df_map = unique(df_map[:,unique([x.from; x.to])])
    
    # If there are duplicate columns in from/to, differentiate between the two to save results.
    duplicates = intersect(x.from, x.to)
    if length(duplicates) > 0
        (ii_from, ii_to) = (occursin.(duplicates, x.from), occursin.(duplicates, x.to));
        x.from[ii_from] = Symbol.(x.from[ii_from], :_0)
        [df_map[!,Symbol(col, :_0)] .= df_map[:,col] for col in duplicates]
    end
    
    # Rename columns in the mapping DataFrame to temporary values in case any of these
    # columns were already present in the input DataFrame.
    temp_to = Symbol.(string.("to_", 1:length(x.to)))
    temp_from = Symbol.(string.("from_", 1:length(x.from)))
    df_map = edit_with(df_map, Rename.([x.to; x.from], [temp_to; temp_from]))

    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since (!!!! assuming all missing values were dropped), all values
    # in the mapping DataFrame should be the same.
    [df[!,col] .= convert_type.(unique(typeof.(skipmissing(df_map[:,col_map]))), df[:,col])
        for (col_map, col) in zip(temp_from, x.input)]

    df = join(df, df_map, on = Pair.(x.input, temp_from); kind = kind, makeunique = true)
  
    # Remove all output column names that might already be in the DataFrame. These will be
    # overwritten by the columns from the mapping DataFrame. Finally, remane mapping "to"
    # columns from their temporary to output values.
    df = df[:, setdiff(names(df), x.output)]
    df = edit_with(df, Rename.(temp_to, x.output))
    return df[:,cols]
end

function edit_with(df::DataFrame, x::Match)
    # Ensure all row values are strings and can be matched with a Regex, and do so.
    # Temporarily remove missing values, just in case.
    col = edit_with(copy(df), Replace(x.input, missing, ""))[:,x.input]
    m = match.(x.on, convert_type.(String, col))
    
    # Add empty columns for all output columns not already in the DataFrame.
    # Where there is a match, fill empty cells. If values in the input column,
    # leave cells without a match unchanged.
    df = edit_with(df, Add.(setdiff(x.output, names(df)), ""))
    [m[ii] != nothing && ([df[ii,out] = m[ii][out] for out in x.output])
        for ii in 1:length(m)]
    return df
end

function edit_with(df::DataFrame, x::Melt)
    on = intersect(x.on, names(df))
    df = melt(df, on, variable_name = x.var, value_name = x.val)
    df[!, x.var] .= convert_type.(String, df[:, x.var])
    return df
end

function edit_with(df::DataFrame, x::Operate)
    # If it is a ROW-WISE operation,
    if x.axis == :row
        df = by(df, x.input, x.output => datatype(x.operation))
        df = edit_with(df, Rename.(setdiff(names(df), x.input), ensurearray(x.output)))
    end

    # If it is a COLUMN-WISE operation, 
    if x.axis == :col
        # Isolate columns to be operated on.
        # Append original columns that might be replaced "_0" to preserve information.
        df_val = convert_type.(Float64, copy(df[:,x.input]))
        x.output in x.input && (df = edit_with(df, Rename(x.output, Symbol(x.output, :_0))))
        df[!,x.output] .= broadcast(datatype(x.operation), [col for col in eachcol(df_val)]...)

        # Adjust labeling columns: If both from/to descriptive columns are distinct and
        # in the DataFrame, Replace the column values from -> to.
        for (from, to) in zip(x.from, x.to)
            if length(intersect(names(df), [from,to])) == 2
                df_comment = dropmissing(unique(df[:, [from; to]]))
                df[!, Symbol(from, :_0)] .= df[:,from]
                df = edit_with(df, Replace.(from, df_comment[:,from], df_comment[:,to]))
            end
        end
    end
    # !!!! How to handle floating point arithmetic? (ex: 1.1 + 0.1 = 1.2000000000000002)
    df[!,x.output] .= round.(df[:,x.output], digits=11)
    return df
end

function edit_with(df::DataFrame, x::Order)
    # If not all columns are present, return the DataFrame as is. Such is the case when a
    # descriptor column must be added when appending multiple data sets in one DataFrame.
    if size(intersect(x.col, names(df)))[1] < size(x.col)[1]
        return df
    # If all of the columns are present in the original DataFrame,
    # reorder the DataFrame columns and set them to the specified type.
    else
        df = df[!, x.col]  # reorder
        [df[!, c] .= convert_type.(t, df[!, c]) for (c, t) in zip(x.col, x.type)]  # convert
        return df
    end
end

function edit_with(df::DataFrame, x::Rename)
    x.from in names(df) && (rename!(df, x.from => x.to))
    x.to == :upper && (df = edit_with(df, Rename.(names(df), uppercase.(names(df)))))
    x.to == :lower && (df = edit_with(df, Rename.(names(df), lowercase.(names(df)))))
    return df
end

function edit_with(df::DataFrame, x::Replace)
    !(x.col in names(df)) && (return df)
    df[!,x.col] .= if x.to === "upper"
        uppercase.(df[:,x.col])
    elseif x.to === "lower"
        lowercase.(df[:,x.col])
    else
        replace(df[:,x.col], x.from => x.to)
    end
    return df
end

function edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    [df = edit_with(df, x) for x in lst]
    return df
end

function edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    return edit_with(df, Add(x.col, file.descriptor))
end

function edit_with(file::T, y::Dict{Any,Any}; shorten = false) where T<:File
    df = read_file(y["Path"], file; shorten = shorten)
    # Specify the order in which edits must occur. "Drop" is included twice, once at the
    # beginning and once at the end. First, drop entire columns. Last, drop specific values.
    EDITS = ["Rename", "Group", "Match", "Melt", "Add", "Map", "Replace", "Drop", "Operate"]

    # Find which of these edits are represented in the yaml file of defined edits.
    KEYS = intersect(EDITS, collect(keys(y)))
    "Drop" in KEYS && pushfirst!(KEYS, "Drop")

    [df = edit_with(df, y[k]) for k in KEYS]
    
    # Add a descriptor to identify the data from the file that was just added.
    # Then, reorder the columns and set them to the correct types.
    # This ensures consistency when concattenating.
    "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
    "Order" in keys(y)    && (df = edit_with(df, y["Order"]))
    return df
end

function edit_with(files::Array{T}, y::Dict{Any,Any}; shorten = false) where T<:File
    return [[edit_with(file, y; shorten = shorten) for file in files]...;]
end

function edit_with(y::Dict{Any,Any}; shorten = false)
    # Find all dictionary keys corresponding to file names and save these in a list.
    file = convert_type(Array, find_oftype(y, File))
    df = edit_with(file, y; shorten = shorten)
    return _sort_datastream(df)
end

"""
"""
function _sort_datastream(df::DataFrame)
    colidx = 1:size(df,2)
    isvalue = istype(df, AbstractFloat)
    ii = colidx[.!isvalue]

    # If it's a mapping dataframe...
    if length(ii) == length(setdiff(names(df),[:factor]))
        ii = intersect(sortperm(length.(unique.(eachcol(df)))), ii)
        splice!(ii, 2:1, colidx[isvalue])
    end
    return sort(df, ii)
end


"""
    fill_zero(keys_unique::NamedTuple; value_colnames)
    fill_zero(keys_unique::NamedTuple, df::DataFrame)
    fill_zero(df::DataFrame...)
    fill_zero(d::Dict...)
    fill_zero(keys_unique, d::Dict)

# Arguments
- `keys_unique::Tuple`: A list of arrays whose permutations should be included in the
    resultant dictionary.
- `keys_unique::NamedTuple`: A list of arrays whose permutations should be included in the
    resultant dictionary. The NamedTuple's keys correspond to the DataFrame columns where
    they will be stored.
- `d::Dict...`: The dictionary/ies to edit.
- `df::DataFrame...`: The DataFrame(s) to edit.

# Keyword Arguments
- `value_colnames::Any = :value`: "value" column labels to add and set to zero when creating
    a new DataFrame. Default is `:value`.

# Usage
This function can be used to fill zeros in either a dictionary or DataFrame.
- Options for DataFrame editing:
    - If only (a) dictionary/ies is/are input, the dictionaries will be edited such that
        they all contain all permutations of their key values. All dictionaries in a
        resultant list of dictionaries will be the same length.
    - If a dictionary is input with a list of keys, it will be edited to ensure that it
        includes all permutations.
    - If only a list of keys is input, a new dictionary will be created, containing all key
        permutations with values initialized to zero.
- Options for DataFrame editing:
    - If only (a) DataFrame(s) is/are input, the DataFrame(s) will be edited such that
        they all contain all permutations of their key values. All DataFrames in a
        resultant list of DataFrames will be the same length.
    - If a DataFrame is input with a NamedTuple, it will be edited to ensure that it
        includes all permutations of the NamedTuple's values.
    - If only a NamedTuple is input, a new DataFrame will be created, containing all key
        permutations with values initialized to zero.

# Returns
- `d::Dict...` if input included dictionaries and/or Tuples
- `df::DataFrame...` if input included DataFrames and/or NamedTuples
"""
function fill_zero(keys_fill::NamedTuple; value_colnames = :value)
    df_fill = DataFrame(permute(keys_fill))
    return edit_with(df_fill, Add.(convert_type.(Symbol, value_colnames), 0.))
end

function fill_zero(keys_fill::Tuple; permute_keys::Bool = true)
    permute_keys && (keys_fill = permute(keys_fill))
    return Dict(k => 0. for k in keys_fill)
end

function fill_zero(d::Vararg{Dict}; permute_keys::Bool = true)
    d = copy.(ensurearray(d))
    # Find all keys present in the input dictionary/ies and ensure all are present.
    keys_fill = unique([collect.(keys.(d))...;])
    d = [fill_zero(keys_fill, x; permute_keys = permute_keys) for x in d]
    return length(d) == 1 ? d[1] : Tuple(d)
end

function fill_zero(keys_fill::NamedTuple, df::DataFrame)
    df_fill = fill_zero(keys_fill)
    df = fill_zero(copy(df), df_fill)[1]
    return df
end

function fill_zero(df::Vararg{DataFrame}; permute_keys::Bool = true)
    df = copy.(ensurearray(df))
    # Save names of columns containing values to fill zeros later.
    # Find descriptor columns to permute OR make consistent across input DataFrames.
    value_colnames = find_oftype.(df, AbstractFloat)
    cols = intersect(setdiff.(names.(df), value_colnames)...)

    # Find a unique list of descriptor keys in the input DataFrame(s). Permute as desired.
    # https://discourse.julialang.org/t/style-question-ternary-operator-or-short-circuit-operator-or-if-end/34224
    df_fill = sort(unique([[x[:,cols] for x in df]...;]))
    permute_keys && (df_keys_all = permute(df_fill))
    
    # For each DataFrame in the list, join the input DataFrame to DataFrame keys_all on the
    # descriptor columns shared by both DataFrames. Using a left join will add "missing"
    # where a descriptor was not already present, which will be replaced by zero.
    # 
    # !!!! After edit_with(df, Replace) is generalized to be type-agnostic,
    # [df[ii] = edit_with(join(df_keys_all, df[ii], on = cols, kind = :left),
    #     Replace.(value_colnames[ii], missing, 0.0)) for ii in 1:length(df)]
    for ii in 1:length(df)
        df[ii] = join(df_keys_all, df[ii], on = cols, kind = :left)
        [df[ii][ismissing.(df[ii][:,col]),col] .= 0. for col in value_colnames[ii]]
    end
    return length(df) == 1 ? df[1] : Tuple(df)
end

function fill_zero(keys_fill::Any, d::Dict; permute_keys::Bool = true)
    d = copy(d)
    # If permuting keys, find all possible permutations of keys that should be present
    # and determine which are missing. Then add missing keys to the dictionary and return.
    permute_keys && (keys_fill = permute(keys_fill))
    keys_missing = setdiff(keys_fill, collect(keys(d)))

    [push!(d, k => 0.) for k in keys_missing]
    return d
end