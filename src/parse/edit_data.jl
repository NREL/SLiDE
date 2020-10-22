"""
    edit_with(y::Dict{Any,Any}; kwargs...)
    edit_with(df::DataFrame, editor::T) where T<:Edit
    edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    edit_with(file::T, y::Dict{Any,Any}; kwargs...)
    edit_with(files::Array{T,N} where N, y::Dict{Any,Any}; kwargs...) where T<:File
This function edits the input DataFrame `df` and returns the resultant DataFrame.

# Arguments
- `df::DataFrame` on which to perform the edit.
- `editor::T where T<:Edit`: DataType containing information about which edit to perform.
    The following edit options are available and detailed below. If given a dictionary of
    edits, they will be made in this order:
    - [`SLiDE.Drop`](@ref): Remove information from the DataFrame -- either an entire column
        or rows containing specified values.
    - [`SLiDE.Rename`](@ref): Change column name `from` -> `to`.
    - [`SLiDE.Group`](@ref): Use to edit files containing data in successive dataframes with
        an identifying header cell or row.
    - [`SLiDE.Match`](@ref): Extract values from the specified column into a column or
        columns based on the specified regular expression.
    - [`SLiDE.Melt`](@ref): Normalize the dataframe by 'melting' columns into rows, 
        lengthening the dataframe by duplicating values in the column `on` into new rows and
        defining 2 new columns:
        1. `var` with header names from the original dataframe.
        2. `val` with column values from the original dataframe.
    - [`SLiDE.Add`](@ref): Add new column `col` filled with `val`.
    - [`SLiDE.Map`](@ref): Define an `output` column containing values based on those in an
        `input` column. The mapping columns `from` -> `to` are contained in a .csv `file` in
        the coremaps directory. The columns `input` and `from` should contain the same
        values, as should `output` and `to`.
    - [`SLiDE.Replace`](@ref): Replace values in `col` `from` -> `to`.
    - [`SLiDE.Operate`](@ref): Perform an arithmetic operation across multiple DataFrame columns or rows.
    - [`SLiDE.Describe`](@ref): This DataType is required when multiple DataFrames will be
        appended into one output file (say, if multiple sheets from an XLSX file are
        included). Before the DataFrames are appended, a column `col` will be added and
        filled with the value in the file descriptor.
    - [`SLiDE.Order`](@ref): Rearranges columns in the order specified by `cols` and sets
        them to the specified type.
- `file::T where T <: File`: Data file containing information to read.
- `files::Array{T} where T <: File`: List of data files.
- `y::Dict{Any,Any}`: Dictionary containing all editing structures among other values read
    from the yaml file. Dictionary keys must correspond EXACTLY with SLiDE.Edit DataType
    names, or the edits will not be made.

# Returns
- `df::DataFrame` including edit(s)
"""
function edit_with(df::DataFrame, x::Add)
    df = copy(df)
    # If adding the length of a string...
    if typeof(x.val) == String && occursin("length", x.val)
        m = match(r"(?<col>\S*) length", x.val)

        # If this is not indicating a column length to add, add the value and exit.
        if (m === nothing || !(Symbol(m[:col]) in propertynames(df)))
            df[!, x.col] .= x.val
            return df
        end
        # If possible, return the length of characters  in the string.
        col_len = Symbol(m[:col])
        df[!, x.col] .= [ismissing(val_len) ? missing : length(convert_type(String, val_len))
            for val_len in df[:,col_len]]
    else
        df[!, x.col] .= x.val
    end
    return df
end

function edit_with(df::DataFrame, x::Drop)
    df = copy(df)
    if x.val === "all" && x.operation == "occursin"
        df = edit_with(df, Drop.(propertynames(df)[occursin.(x.col, propertynames(df))], "all", "=="))
    end

    !(x.col in propertynames(df)) && (return df)
    if x.val === "all"  # Drop entire column to remove dead weight right away.
        df = df[:, setdiff(propertynames(df), [x.col])]
    else  # Drop rows using an operation or based on a value.
        if x.val === missing
            dropmissing!(df, x.col)
        # elseif x.val === "unique"
        #     unique!(df, x.col)
        else
            df[!,x.col] .= convert_type.(typeof(x.val), df[:,x.col])
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
    df = copy(df)
    # First, add a column to the original DataFrame indicating where the data set begins.
    cols = unique([propertynames(df); x.output])
    df[!,:start] = (1:size(df)[1]) .+ 1

    # # Next, create a DataFrame describing where to "split" the input DataFrame.
    # # Editing with a map will remove all rows that do not contain relevant information.
    # # Add a column indicating where each data set STOPS, assuming all completely blank rows
    # # were removed by read_file().
    df_split = edit_with(copy(df), convert_type(Map, x); kind = :inner)
    sort!(unique!(df_split), :start)
    df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

    # Add a new, blank output column to store identifying information about the data block.
    # Then, fill this column based on the identifying row numbers in df_split.
    for out in x.output
        df[!,out] .= ""
        [df[row[:start]:row[:stop], out] .= row[out] for row in eachrow(df_split)]
    end

    # Finally, remove header rows (these will be blank in the output column),
    # as well as the column describing where the sub-DataFrames begin.
    df = edit_with(df, Drop.(x.output, "", "=="))
    return df[:, cols]
end

function edit_with(df::DataFrame, x::Map; kind = :left)
    df = copy(df)
    # Save all input column propertynames, read the map file, and isolate relevant columns.
    # # This prevents duplicate columns in the final DataFrame.
    cols = unique([propertynames(df); x.output])
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
    temp_to = Symbol.(:to_, 1:length(x.to))
    temp_from = Symbol.(:from_, 1:length(x.from))
    df_map = edit_with(df_map, Rename.([x.to; x.from], [temp_to; temp_from]))

    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since all values in each column should be of the same type.
    for (col, col_map) in zip(x.input, temp_from)
        try
            new_type = eltype.(eachcol(dropmissing(df_map[:,[col_map]])))
            df[!,col] .= convert_type.(new_type, df[:,col])
        catch
            df_map[!,col_map] .= convert_type.(String, df_map[:,col_map])
        end
    end
    join_cols = Pair.(x.input, temp_from)
    
    x.kind == :inner && (df = innerjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :outer && (df = outerjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :left  && (df = leftjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :right && (df = rightjoin(df, df_map, on = join_cols; makeunique = true))
    x.kind == :semi  && (df = semijoin(df, df_map, on = join_cols; makeunique = true))
    
    # Remove all output column propertynames that might already be in the DataFrame. These will be
    # overwritten by the columns from the mapping DataFrame. Finally, remane mapping "to"
    # columns from their temporary to output values.
    df = df[:, setdiff(propertynames(df), x.output)]
    df = edit_with(df, Rename.(temp_to, x.output))
    return df[:,cols]
end

function edit_with(df::DataFrame, x::Match)
    df = copy(df)
    if x.on == r"expand range"
        ROWS, COLS = size(df)
        cols = propertynames(df)
        df = [[DataFrame(Dict(cols[jj] =>
                cols[jj] == x.input ? _expand_range(df[ii,jj]) : df[ii,jj]
            for jj in 1:COLS)) for ii in 1:ROWS]...;]
    else
        # Ensure all row values are strings and can be matched with a Regex, and do so.
        # Temporarily remove missing values, just in case.
        df[:,x.input] .= convert_type.(String, df[:,x.input])
        col = edit_with(copy(df), Replace(x.input, missing, ""))[:,x.input]
        m = match.(x.on, col)
        
        # Add empty columns for all output columns not already in the DataFrame.
        # Where there is a match, fill empty cells. If values in the input column,
        # leave cells without a match unchanged.
        df = edit_with(df, Add.(setdiff(x.output, propertynames(df)), ""))
        [m[ii] !== nothing && ([df[ii,out] = m[ii][out] for out in x.output])
            for ii in 1:length(m)]
    end
    return df
end

function edit_with(df::DataFrame, x::Melt)
    df = copy(df)
    on = intersect(x.on, propertynames(df))
    df = melt(df, on, variable_name = x.var, value_name = x.val)
    df[!, x.var] .= convert_type.(String, df[:, x.var])
    return df
end

function edit_with(df::DataFrame, x::Operate)
    df = copy(df)
    # If it is a ROW-WISE operation,
    if x.axis == :row
        df = by(df, x.input, x.output => datatype(x.operation))
        df = edit_with(df, Rename.(setdiff(propertynames(df), x.input), ensurearray(x.output)))
    end

    # If it is a COLUMN-WISE operation, 
    if x.axis == :col
        cols = [setdiff(propertynames(df), unique([x.from; x.to; x.input; x.output])); x.output; x.from]

        # Isolate columns to be operated on.
        # Append original columns that might be replaced "_0" to preserve information.
        df_val = convert_type.(Float64, copy(df[:,x.input]))
        x.output in x.input && (df = edit_with(df, Rename(x.output, Symbol(x.output, :_0))))
        df[!,x.output] .= broadcast(datatype(x.operation), [col for col in eachcol(df_val)]...)

        # Adjust labeling columns: If both from/to descriptive columns are distinct and
        # in the DataFrame, Replace the column values from -> to.
        for (from, to) in zip(x.from, x.to)
            if length(intersect(propertynames(df), [from,to])) == 2
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
    df = copy(df)
    # If not all columns are present, return the DataFrame as is. Such is the case when a
    # descriptor column must be added when appending multiple data sets in one DataFrame.
    if size(intersect(x.col, propertynames(df)))[1] < size(x.col)[1]
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
    df = copy(df)
    x.from in propertynames(df) && (df = rename(df, x.from => x.to))
    x.to == :upper && (df = edit_with(df, Rename.(propertynames(df), uppercase.(propertynames(df)))))
    x.to == :lower && (df = edit_with(df, Rename.(propertynames(df), lowercase.(propertynames(df)))))
    return df
end

function edit_with(df::DataFrame, x::Replace)
    df = copy(df)
    !(x.col in propertynames(df)) && (return df)

    if x.from === missing && Symbol(x.to) in propertynames(df)
        df[ismissing.(df[:,x.col]),x.col] .= df[ismissing.(df[:,x.col]), Symbol(x.to)]
        return df
    end

    if x.to === Not && eltype(df[:,x.col]) == Bool
        df[!,x.col] .= .!df[:,x.col]
    end

    df[!,x.col] .= if x.to === "lower"  lowercase.(df[:,x.col])
    elseif x.to === "upper"             uppercase.(df[:,x.col])
    elseif x.to === "uppercasefirst"    uppercasefirst.(lowercase.(df[:,x.col]))
    elseif x.to === "titlecase"         titlecase.(df[:,x.col])
    else
        replace(strip.(copy(df[:,x.col])), x.from => x.to)
    end
    return df
end

function edit_with(df::DataFrame, x::Stack)
    df = copy(df)
    df = [[edit_with(df[:, occursin.(indicator, propertynames(df))],
        [Rename.(propertynames(df)[occursin.(indicator, propertynames(df))], x.col);
            Add(x.var, replace(string(indicator), "_" => " "))]
    ) for indicator in x.on]...;]
    return dropmissing(df)
end

function edit_with(df::DataFrame, lst::Array{T}) where T<:Edit
    [df = edit_with(df, x) for x in lst]
    return df
end

function SLiDE.edit_with(df::DataFrame, x::Describe, file::T) where T<:File
    return select!(edit_with(df, Add(x.col, file.descriptor)), [x.col; propertynames(df)])
end

function edit_with(df::DataFrame, y::Dict{Any,Any})
    # Specify the order in which edits must occur. "Drop" is included twice, once at the
    # beginning and once at the end. First, drop entire columns. Last, drop specific values.
    EDITS = ["Rename", "Group", "Stack", "Match", "Melt", "Add", "Map", "Replace", "Drop", "Operate", "Order"]

    # Find which of thyese edits are represented in the yaml file of defined edits.
    KEYS = intersect(EDITS, collect(keys(y)))
    "Drop" in KEYS && pushfirst!(KEYS, "Drop")
    
    [df = edit_with(df, y[k]) for k in KEYS]
    return df
end

function edit_with(file::T, y::Dict{Any,Any}) where T<:File
    df = read_file(y["PathIn"], file)
    df = edit_with(df, y)
    
    # Add a descriptor to identify the data from the file that was just added.
    # Then, reorder the columns and set them to the correct types.
    # This ensures consistency when concattenating.
    "Describe" in keys(y) && (df = edit_with(df, y["Describe"], file))
    "Order" in keys(y)    && (df = edit_with(df, y["Order"]))
    return df
end

function edit_with(files::Array{T}, y::Dict{Any,Any}) where T<:File
    return [[edit_with(file, y) for file in files]...;]
end

function edit_with(y::Dict{Any,Any})
    # Find all dictionary keys corresponding to file names and save these in a list.
    file = convert_type(Array, find_oftype(y, File))
    df = edit_with(file, y)
    # return _sort_datastream(df)
end

"""
    _sort_datastream(df::DataFrame)
Returns the edited DataFrame, stored in a nicely-sorted order. This is most helpful for
mapping and developing. Sorting isn't *necessary* and we could remove this function to save
some time for users.
"""
function _sort_datastream(df::DataFrame)
    colidx = 1:size(df,2)
    isvalue = istype(df, AbstractFloat) # user a different function!
    ii = colidx[.!isvalue]

    # If it's a mapping dataframe...s
    if length(ii) == length(setdiff(propertynames(df),[:factor]))
        :state_code in propertynames(df) && (ii = intersect(colidx[occursin.(:code, propertynames(df))], ii))
        ii = intersect(sortperm(length.(unique.(eachcol(df)))), ii)
        splice!(ii, 2:1, colidx[isvalue])
    end
    return sort(df, ii)
end

"""
    _expand_range()
"""
function _expand_range(x::T) where T <: AbstractString
    if occursin("-", x)
        if all(string(strip(x)) .!= ["31-33", "44-45", "48-49"])
            x = split(x, "-")
            x = ensurearray(convert_type(Int, x[1]):convert_type(Int, x[1][1:end-1] * x[end][end]))
        end
    else
        x = convert_type(Int, x)
    end
    return x
end

function _expand_range(x::String)
    if match(r"\D", x) !== nothing
        m = String.([m.match for m in collect(eachmatch(r"\D.*?", x))])
        # length(setdiff(m, [",","-"," "])) .== 0 && (x = [_expand_range.(split(x, ","))...;])
        x = length(setdiff(m, [",","-"," "])) .== 0 ? [_expand_range.(split(x, ","))...;] : missing
    else
        x = convert_type(Int, x)
    end
    return x
end

_expand_range(x::Missing) = x
_expand_range(x::Int) = x

"""
    fill_zero(keys_unique::NamedTuple; value_colnames)
    fill_zero(keys_unique::NamedTuple, df::DataFrame)
    fill_zero(df::DataFrame...)
    fill_zero(d::Dict...)
    fill_zero(keys_unique, d::Dict)

This function can be used to fill zeros in either a dictionary or DataFrame.
- Options for dictionary editing:
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
    df = copy(df)
    df_fill = fill_zero(keys_fill)
    df = fill_zero(df, df_fill)[1]
    return df
end

function fill_zero(df::Vararg{DataFrame}; permute_keys::Bool = true)
    df = copy.(ensurearray(df))
    # Save propertynames of columns containing values to fill zeros later.
    # Find descriptor columns to permute OR make consistent across input DataFrames.
    value_colnames = find_oftype.(df, AbstractFloat)
    cols = intersect(setdiff.(propertynames.(df), value_colnames)...)

    # Find a unique list of descriptor keys in the input DataFrame(s). Permute as desired.
    df_fill = sort(unique([[x[:,cols] for x in df]...;]))
    permute_keys && (df_fill = permute(df_fill))
    
    # For each DataFrame in the list, join the input DataFrame to DataFrame keys_all on the
    # descriptor columns shared by both DataFrames. Using a left join will add "missing"
    # where a descriptor was not already present, which will be replaced by zero.
    [df[ii] = edit_with(leftjoin(df_fill, df[ii], on = cols),
        Replace.(value_colnames[ii], missing, 0.0)) for ii in 1:length(df)]
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


"""
    fill_with(keys_unique::NamedTuple, value::Any; kwargs)

Initializes a new DataFrame and fills it with the specified input value.
"""
function fill_with(keys_fill::NamedTuple, value::Any; value_colnames = :value)
    df = fill_zero(keys_fill; value_colnames = value_colnames)
    df = edit_with(df, Replace.(value_colnames, 0.0, value))
    return df
end

"""
    extrapolate_year(df::DataFrame, yr::Array{Int64,1}; kwargs...)
    extrapolate_year(df::DataFrame, set::Any; kwargs...)

# Arguments
- `df::DataFrame` that might be in need of extrapolation.
- `yr::Array{Int64,1}`: List of years overwhich extrapolation is possible (depending on the kwargs)
- `set::Dict` or `set::NamedTuple` containing list of years, identified by the key `:yr`.

# Keyword Arguments
- `backward::Bool = true`: Do we extrapolate backward in time?
- `forward::Bool = true`: Do we extrapolate forward in time?

# Returns
- `df::DataFrame` extrapolated in time.

# Example
Continuing with the DataFrame from [`SLiDE.filter_with`](@ref),

```jldoctest extrapolate_year; setup = :(df = filter_with(read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_use.csv")), (i = ["agr","fbp"], j = ["agr","fbp"])))
julia> df
8×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2016  │ agr    │ agr    │ 60.197  │
│ 6   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 7   │ 2016  │ fbp    │ agr    │ 47.739  │
│ 8   │ 2016  │ fbp    │ fbp    │ 205.21  │

julia> extrapolate_year(df, Dict(:yr => 2014:2017))
16×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2014  │ agr    │ agr    │ 69.42   │
│ 2   │ 2014  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2014  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2014  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2015  │ agr    │ agr    │ 69.42   │
│ 6   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 7   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 8   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 9   │ 2016  │ agr    │ agr    │ 60.197  │
│ 10  │ 2016  │ agr    │ fbp    │ 264.173 │
│ 11  │ 2016  │ fbp    │ agr    │ 47.739  │
│ 12  │ 2016  │ fbp    │ fbp    │ 205.21  │
│ 13  │ 2017  │ agr    │ agr    │ 60.197  │
│ 14  │ 2017  │ agr    │ fbp    │ 264.173 │
│ 15  │ 2017  │ fbp    │ agr    │ 47.739  │
│ 16  │ 2017  │ fbp    │ fbp    │ 205.21  │
```
"""
function extrapolate_year(
    df::DataFrame,
    yr::Array{Int64,1};
    backward::Bool = true,
    forward::Bool = true
)
    df = copy(df)
    yr_diff = setdiff(yr, unique(df[:,:yr]))
    length(yr_diff) == 0 && (return df)
    
    cols = setdiff(propertynames(df), [:yr])
    cols_ans = propertynames(df)

    df_ext = []

    if backward
        yr_min = minimum(df[:,:yr])
        df_min = filter_with(df, (yr = yr_min,))[:,cols]

        yr_back = yr_diff[yr_diff .< yr_min]
        df_back = crossjoin(DataFrame(yr = yr_back), df_min)[:,cols_ans]

        push!(df_ext, df_back)
    end

    if forward
        yr_max = maximum(df[:,:yr])
        df_max = filter_with(df, (yr = yr_max,))[:,cols]

        yr_forward = yr_diff[yr_diff .> yr_max]
        df_forward = crossjoin(DataFrame(yr = yr_forward), df_max)[:,cols_ans]

        push!(df_ext, df_forward)
    end

    return sort([df_ext...; df])
end

function extrapolate_year(
    df::DataFrame,
    set;
    backward::Bool = true,
    forward::Bool = true
)
    extrapolate_year(df, set[:yr]; forward = forward, backward = backward)
end

function extrapolate_year(
    df::DataFrame,
    yr::UnitRange{Int64};
    backward::Bool = true,
    forward::Bool = true
)
    extrapolate_year(df, ensurearray(yr); forward = forward, backward = backward)
end

"""
    extrapolate_region(df::DataFrame; kwargs...)
    extrapolate_region(df::DataFrame, r::Pair; kwargs...)

Fills in missing data in the input DataFrame `df` by filling it with existing information in
`df`. Here, "extrapolate" makes a direct copy of the data.

# Arguments
- `df::DataFrame` that might be in need of extrapolation.
- `r::Pair = "md" => "dc"`: `Pair` indicating a region (`r.first`) to extrapolate to another
    region (`r.second`). A suggested regional extrapolation: MD data will be used to
    approximate DC data in the event that it is missing. To fill multiple regions with data,
    use "md" => ["dc","va"].

# Keyword Argument:
- `overwrite::Bool = false`: If data in the target region `r.second` is already present,
    should it be overwritten?

# Returns
- `df::DataFrame` extrapolated in region.

# Example

```jldoctest extrapolate_region
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_utd.csv"))
8×5 DataFrame
│ Row │ yr    │ r      │ s      │ t       │ value     │
│     │ Int64 │ String │ String │ String  │ Float64   │
├─────┼───────┼────────┼────────┼─────────┼───────────┤
│ 1   │ 2015  │ md     │ agr    │ exports │ 0.0390152 │
│ 2   │ 2015  │ md     │ agr    │ imports │ 0.778159  │
│ 3   │ 2015  │ va     │ agr    │ exports │ 1.11601   │
│ 4   │ 2015  │ va     │ agr    │ imports │ 0.88253   │
│ 5   │ 2016  │ md     │ agr    │ exports │ 0.0330508 │
│ 6   │ 2016  │ md     │ agr    │ imports │ 0.762089  │
│ 7   │ 2016  │ va     │ agr    │ exports │ 1.16253   │
│ 8   │ 2016  │ va     │ agr    │ imports │ 0.86741   │

julia> extrapolate_region(df)
12×5 DataFrame
│ Row │ r      │ yr    │ s      │ t       │ value     │
│     │ String │ Int64 │ String │ String  │ Float64   │
├─────┼────────┼───────┼────────┼─────────┼───────────┤
│ 1   │ dc     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 2   │ dc     │ 2015  │ agr    │ imports │ 0.778159  │
│ 3   │ dc     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 4   │ dc     │ 2016  │ agr    │ imports │ 0.762089  │
│ 5   │ md     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 6   │ md     │ 2015  │ agr    │ imports │ 0.778159  │
│ 7   │ md     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 8   │ md     │ 2016  │ agr    │ imports │ 0.762089  │
│ 9   │ va     │ 2015  │ agr    │ exports │ 1.11601   │
│ 10  │ va     │ 2015  │ agr    │ imports │ 0.88253   │
│ 11  │ va     │ 2016  │ agr    │ exports │ 1.16253   │
│ 12  │ va     │ 2016  │ agr    │ imports │ 0.86741   │
```

If we instead want to copy VA data into DC, specify:

```jldoctest extrapolate_region
julia> extrapolate_region(df, "va" => "dc")
12×5 DataFrame
│ Row │ r      │ yr    │ s      │ t       │ value     │
│     │ String │ Int64 │ String │ String  │ Float64   │
├─────┼────────┼───────┼────────┼─────────┼───────────┤
│ 1   │ dc     │ 2015  │ agr    │ exports │ 1.11601   │
│ 2   │ dc     │ 2015  │ agr    │ imports │ 0.88253   │
│ 3   │ dc     │ 2016  │ agr    │ exports │ 1.16253   │
│ 4   │ dc     │ 2016  │ agr    │ imports │ 0.86741   │
│ 5   │ md     │ 2015  │ agr    │ exports │ 0.0390152 │
│ 6   │ md     │ 2015  │ agr    │ imports │ 0.778159  │
│ 7   │ md     │ 2016  │ agr    │ exports │ 0.0330508 │
│ 8   │ md     │ 2016  │ agr    │ imports │ 0.762089  │
│ 9   │ va     │ 2015  │ agr    │ exports │ 1.11601   │
│ 10  │ va     │ 2015  │ agr    │ imports │ 0.88253   │
│ 11  │ va     │ 2016  │ agr    │ exports │ 1.16253   │
│ 12  │ va     │ 2016  │ agr    │ imports │ 0.86741   │
```

"""
function extrapolate_region(df::DataFrame, r::Pair = "md" => "dc"; overwrite = false)
    df = copy(df)
    if !overwrite
        r = r.first => setdiff(ensurearray(r.second), unique(df[:,:r]))
        length(r.second) == 0 && (return df)
    else
        df = edit_with(df, Drop.(:r, r.second, "=="))
    end
    
    cols = setdiff(propertynames(df), [:r])
    df_close = crossjoin(DataFrame(r = r.second), filter_with(df, (r = r.first,))[:,cols])
    
    return sort([df_close; df])
end

"""
filter_with(df::DataFrame, set::Any; kwargs...)

# Arguments
- `df::DataFrame` to filter.
- `set::Dict` or `set::NamedTuple`: Values to keep in the DataFrame.

# Keyword Arguments
- `extrapolate::Bool = false`: Add missing regions/years to the DataFrame?
    If `extrapolate` is set to true, the following `kwargs` become relevant:
    - When extrapolating over years,
        - `backward::Bool = true`: Do we extrapolate backward in time?
        - `forward::Bool = true`: Do we extrapolate forward in time?
        Currently, "extrapolating" means copying the closest 
    - When extrapolating across regions,
        - `r::Pair = "md" => "dc"`: `Pair` indicating a region (`r.first`) to extrapolate to
            another region (`r.second`). A suggested regional extrapolation: MD data will be
            used to approximate DC data in the event that it is missing.
        - `overwrite::Bool = false`: If data in the target region `r.second` is already present,
            should it be overwritten?

# Returns
- `df::DataFrame` with only the desired keys.

# Examples

```jldoctest filter_with
julia> df = read_file(joinpath(SLIDE_DIR,"docs","src","assets","data","filter_use.csv"))
14×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2015  │ uti    │ agr    │ 4.846   │
│ 6   │ 2015  │ uti    │ fbp    │ 10.102  │
│ 7   │ 2015  │ uti    │ uti    │ 35.093  │
│ 8   │ 2016  │ agr    │ agr    │ 60.197  │
│ 9   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 10  │ 2016  │ fbp    │ agr    │ 47.739  │
│ 11  │ 2016  │ fbp    │ fbp    │ 205.21  │
│ 12  │ 2016  │ uti    │ agr    │ 4.548   │
│ 13  │ 2016  │ uti    │ fbp    │ 9.152   │
│ 14  │ 2016  │ uti    │ uti    │ 27.47   │

julia> df = filter_with(df, (i = ["agr","fbp"], j = ["agr","fbp"]))
8×4 DataFrame
│ Row │ yr    │ i      │ j      │ value   │
│     │ Int64 │ String │ String │ Float64 │
├─────┼───────┼────────┼────────┼─────────┤
│ 1   │ 2015  │ agr    │ agr    │ 69.42   │
│ 2   │ 2015  │ agr    │ fbp    │ 277.179 │
│ 3   │ 2015  │ fbp    │ agr    │ 49.132  │
│ 4   │ 2015  │ fbp    │ fbp    │ 210.998 │
│ 5   │ 2016  │ agr    │ agr    │ 60.197  │
│ 6   │ 2016  │ agr    │ fbp    │ 264.173 │
│ 7   │ 2016  │ fbp    │ agr    │ 47.739  │
│ 8   │ 2016  │ fbp    │ fbp    │ 205.21  │

julia> filter_with(df, (yr = 2016,); drop = true)
4×3 DataFrame
│ Row │ i      │ j      │ value   │
│     │ String │ String │ Float64 │
├─────┼────────┼────────┼─────────┤
│ 1   │ agr    │ agr    │ 60.197  │
│ 2   │ agr    │ fbp    │ 264.173 │
│ 3   │ fbp    │ agr    │ 47.739  │
│ 4   │ fbp    │ fbp    │ 205.21  │
```
"""
function filter_with(
    df::DataFrame,
    set::Any;
    drop::Bool = false,
    extrapolate::Bool = false,
    forward::Bool = true,
    backward::Bool = true,
    r::Pair = "md" => "dc",
    overwrite::Bool = false
)
    cols = propertynames(df)

    # Find keys that reference both column names in the input DataFrame df and
    # values in the set Dictionary. Then, created a DataFrame containing all permutations.
    cols_key = find_oftype(df, Not(AbstractFloat))
    cols_set = intersect(cols_key, collect(keys(set)))
    vals_set = [intersect(unique(df[:,k]), ensurearray(set[k])) for k in cols_set]
    
    if any(length.(vals_set) .== 0)
        cols_err = cols_set[length.(vals_set) .== 0]
        error("Cannot filter DataFrame. No overlap with input set. 
            - Check set key(s): $cols_empty
            - Use extrapolate_year() or extrapolate_region() to extend the dataset")
    end

    # Drop values that are not in the current set.
    df_set = DataFrame(permute(NamedTuple{Tuple(cols_set,)}(vals_set,)))
    df = innerjoin(df, df_set, on = cols_set)
    
    if extrapolate
        :yr in cols_set && (df = extrapolate_year(df, set; forward = forward, backward = backward))
        :r in cols_set  && (df = extrapolate_region(df, r; overwrite = overwrite))
    end

    # If one of the filtered DataFrame columns contains only one unique value, drop it.
    drop && setdiff!(cols, cols_set[length.(unique.(eachcol(df[:,cols_set]))) .=== 1])

    return sort(df[:,cols])
end

# function filter_with(
#     df::DataFrame,
#     set::NamedTuple;
#     drop::Bool = false,
#     extrapolate::Bool = false,
#     forward::Bool = true,
#     backward::Bool = true,
#     r::Pair = "md" => "dc",
#     overwrite::Bool = false
# )
#     if any(typeof.(collect(values(set))) .<: Pair)
#         x = [Rename.(set[k].first, k) for k in keys(set) if typeof(set[k]) <: Pair]
#         df = edit_with(df, x)
#     end
    
#     set = Dict(k => (typeof(set[k]) <: Pair) ? set[k].second : set[k] for k in keys(set))
#     return filter_with(df, set; drop = drop, extrapolate = extrapolate, forward = forward, backward = backward, r = r, overwrite = overwrite)
# end