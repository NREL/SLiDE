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
    if x.col in names(df)
        # Drop an entire column. It is helpful to remove dead weight with the first edit.
        if (typeof(x.val) == String) && occursin(lowercase(x.val), "all")
            df = df[:, setdiff(names(df), [x.col])]

        # Drop rows based on value.
        else
            if typeof(x.val) == String
                occursin(lowercase(x.val), "missing") ? dropmissing!(df, x.col) :
                    occursin(lowercase(x.val), "unique") ? unique!(df, x.col) : nothing
            end
            # Perform generalized drops specified by the operation field.
            # !!!! Add error if broadcast not possible.
            df[!,x.col] .= convert_type.(typeof(x.val), df[:,x.col])
            df = df[.!broadcast(datatype(x.operation), df[:,x.col], x.val), :]
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
    # This prevents duplicate columns in the final DataFrame.
    cols = unique([names(df); x.output])
    df_map = read_file(x)
    df_map = unique(df_map[:,unique([x.from; x.to])])

    # Rename columns in the mapping DataFrame to temporary values in case any of these
    # columns were already present in the input DataFrame.
    temp_to = Symbol.(string.("to_", 1:length(x.to)))
    temp_from = Symbol.(string.("from_", 1:length(x.from)))
    df_map = edit_with(df_map, Rename.([x.to; x.from], [temp_to; temp_from]))

    # Ensure the input and mapping DataFrames are consistent in type. Types from the mapping
    # DataFrame are used since (!!!! assuming all missing values were dropped), all values
    # in the mapping DataFrame should be the same.
    [df[!,col] .= convert_type.(unique(typeof.(df_map[:,col_map])), df[:,col])
        for (col_map, col) in zip(temp_from, x.input)]

    df = join(df, df_map, on = Pair.(x.input, temp_from);
        kind = kind, makeunique = true)
    
    # Remove all output column names that might already be in the DataFrame. These will be
    # overwritten by the columns from the mapping DataFrame. Finally, remane mapping "to"
    # columns from their temporary to output values.
    df = df[:, setdiff(names(df), x.output)]
    df = edit_with(df, Rename.(temp_to, x.output))

    return df[:, cols]
end

function edit_with(df::DataFrame, x::Match)
    # First, ensure that all row values are strings that can be matched with a Regex.
    !all(typeof(df[:,x.input]) .== String) ?
        df[!,x.input] .= convert_type.(String, df[:,x.input]) : nothing
    
    # Add empty columns for all output columns not already in the DataFrame.
    cols = setdiff(x.output, names(df))
    df = edit_with(df, Add.(cols, fill("", size(cols))))

    # Find all matches! Where there is a match, fill in the empty cells.
    m = match.(x.on, df[:, x.input])
    [m[ii] != nothing ? [df[ii,out] = m[ii][out] for out in x.output] : nothing
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
    # Perform operation on columns. Isolate columns to be operated on.
    # Append original columns that might be replaced "_0" to preserve information.
    df_val = convert_type.(Float64, copy(df[:,x.input]))
    x.output in x.input ? df = edit_with(df, Rename(x.output, Symbol(x.output, :_0))) :
        nothing
    df[!,x.output] .= broadcast(datatype(x.operation), [col for col in eachcol(df_val)]...)

    # !!!! SOS how do we deal with floating point arithmetic? (ex: 1.1 + 0.1 = 1.2000000000000002)
    df[!,x.output] .= round.(df[:,x.output], digits=8)

    # Adjust labeling columns.
    for (from, to) in zip(x.from, x.to)
        if from in names(df) && to in names(df) && from !== to
            df_comment = dropmissing(unique(df[:, [from; to]]))
            df[!, Symbol(from, :_0)] .= df[:,from]
            df = edit_with(df, Replace.(from, df_comment[:,from], df_comment[:,to]))
        end
    end
    
    # Reorder DataFrame columns to show all columns involved in the operation last.
    # This could aid in troubleshooting.
    cols = intersect([setdiff(x.input, [x.output]); Symbol(x.output, :_0); x.output;
        reverse(sort([Symbol.(x.from, :_0); x.from])); reverse(sort(x.to))], names(df));
    return df[:,[setdiff(names(df), cols); cols]]
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
    # Explicitly rename the specified column if it exists in the dataframe.
    x.from in names(df) ? rename!(df, x.from => x.to) :

        # If we are, instead, changing the CASE of all column names...
        lowercase(x.to) == :lower ?
            df = edit_with(df, Rename.(names(df), lowercase.(names(df)))) :
            lowercase(x.to) == :upper ?
                df = edit_with(df, Rename.(names(df), uppercase.(names(df)))) :
                nothing
    return df
end

function edit_with(df::DataFrame, x::Replace)
    if x.col in names(df)
        df[!, x.col] .= convert_type.(String, df[:, x.col])
        x.from == "missing" ?
            all(typeof.(df[:,x.col]) .== Missing) ?
                df = edit_with(df, Add(x.col, x.to)) :
                df[ismissing.(df[:,x.col]), x.col] .= x.to :
            df[!, x.col][strip.(string.(df[:,x.col])) .== x.from] .= x.to
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
    df = read_file(y["Path"], file; shorten = shorten);
    
    # Specify the order in which edits must occur. "Drop" is included twice, once at the
    # beginning and once at the end. First, drop entire columns. Last, drop specific values.
    EDITS = ["Rename", "Group", "Match", "Melt", "Add", "Map", "Replace", "Drop", "Operate"]

    # Find which of these edits are represented in the yaml file of defined edits.
    KEYS = intersect(EDITS, [k for k in keys(y)]);
    "Drop" in KEYS ? KEYS = ["Drop"; KEYS] : nothing

    [df = edit_with(df, y[k]) for k in KEYS];
    
    # Add a descriptor to identify the data from the file that was just added.
    # Then, reorder the columns and set them to the correct types.
    # This ensures consistency when concattenating.
    df = "Describe" in keys(y) ? edit_with(df, y["Describe"], file) : df;
    df = "Order" in keys(y) ? edit_with(df, y["Order"]) : df;
    return df
end

function edit_with(files::Array{T}, y::Dict{Any,Any}; shorten = false) where T<:File
    df = DataFrame();
    [df = vcat(df, edit_with(file, y; shorten = shorten)) for file in files]
    return df
end

function edit_with(y::Dict{Any,Any}; shorten = false)
    file = [v for (k,v) in y
        if isarray(v) ? any(broadcast(<:, typeof.(v), File)) : typeof(v)<:File]
    file = length(file) == 1 ? file[1] : vcat(file...)
    df = edit_with(file, y; shorten = shorten)
    
    length(intersect(names(df), [:from,:to])) == 2 ? sort!(df, [:to, :from]) : nothing
    return df
end