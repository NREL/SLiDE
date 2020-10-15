# using DataFrames
# using Dates
# using Base

"""
    function datatype(str::String)
This function evaluates an input string as a DataType if it is defined.
Otherwise, it will return false.
See: (thread on discourse.julialang.org)[https://discourse.julialang.org/t/parse-string-to-datatype/7118/9]
"""
function datatype(str::String)
    type = :($(Symbol(str)))
    return isdefined(SLiDE, type) ? eval(type) : nothing
end

"""
    Base.broadcastable(x::InvertedIndex{T}) where {T<:Any}
!!!!
"""
Base.broadcastable(x::InvertedIndex{T}) where {T<:Any} = [x];

"""
    Base.split(x::Missing)
    Base.split(x::Number)
Extends `split` to ignore missing fields.
"""
Base.split(str::Missing) = str
Base.split(str::Missing, splitter::Any) = str

"""
    Base.strip(x::Missing)
    Base.strip(x::Number)
Extends `strip` to ignore missing fields and numbers.
"""
# Base.strip(x::String) = replace(x, r"^\s*\"*|\"*\s*$" => "")
Base.strip(x::Missing) = x
Base.strip(x::Number) = x

"""
    Base.lowercase(x::Symbol)
Extends `lowercase` to handle other data types.
"""
Base.lowercase(x::Int) = x
Base.lowercase(x::Symbol) = Symbol(lowercase(string(x)))
Base.lowercase(x::Missing) = missing

"""
    Base.titlecase(x::Symbol)
Extends `titlecase` to handle other data types.
"""
Base.titlecase(x::Int) = x
Base.titlecase(x::Symbol) = Symbol(titlecase(string(x)))
Base.titlecase(x::Missing) = missing

"""
    Base.uppercase(x::Symbol)
Extends `uppercase` to handle other data types.
"""
Base.uppercase(x::Int) = x
Base.uppercase(x::Symbol) = Symbol(uppercase(string(x)))
Base.uppercase(x::Missing) = missing

"""
    Base.uppercasefirst(x::Symbol)
Extends `uppercasefirst` to handle other data types.
"""
Base.uppercasefirst(x::Int) = x
Base.uppercasefirst(x::Symbol) = Symbol(uppercasefirst(string(x)))
Base.uppercasefirst(x::Missing) = missing

"""
    Base.occursin(x::Symbol, y::Symbol)
    Base.occursin(x::String, y::Symbol)
Extends `occursin` to work for symbols. Potentially helpful for DataFrame columns.
"""
Base.occursin(x::Symbol, y::Symbol) = occursin(string(x), y)
Base.occursin(x::String, y::Symbol) = occursin(x, string(y))

"""
"""
function dropvalue!(df::DataFrame, x::Float64)
    cols = find_oftype(df, typeof(x));
    if isnan(x); [filter!(row -> .!isnan.(row[col]), df) for col in cols]
    else;        [filter!(row -> row[col] .!== x, df) for col in cols]
    end
    return df
end

dropvalue(df::DataFrame, x::Float64) = dropvalue!(copy(df), x)

"""
    dropzero!(df::DataFrame)
Returns a DataFrame without zero values in columns of type AbstractFloat.
"""
dropzero!(df::DataFrame) = dropvalue!(df, 0.0)
dropzero(df::DataFrame) = dropzero!(copy(df))

dropnan!(df::DataFrame) = dropvalue!(df, NaN)
dropnan(df::DataFrame) = dropnan!(copy(df))


"""
    convert_type(::Type{T}, x::Any)
    convert_type(::Dict{Any,Any}, df::DataFrame, value_col::Symbol; kwargs...)
Converts `x` into the specified `Type{xT}`.

Consider extending [convert](https://docs.julialang.org/en/v1/base/base/#Base.convert)
function (!!!!)

# Arguments
- `::Type{T}`: target DataType.
- `x<:Any`: value to convert.

# Keyword Arguments
Options available when converting a DataFrame into a dictionary of keys pointing to a value:
- `drop_cols = []`: Columns not to include in
    the keys. By default, no columns are dropped.
- `value_col::Symbol = :end`: If converting

# Returns
Data in specified type
"""
convert_type(::Type{T}, x::Any) where T<:AbstractString = string(x)
convert_type(::Type{T}, x::Date) where T<:Integer = Dates.year(x)

convert_type(::Type{Map}, x::Group) = Map(x.file, [x.from], x.to, [x.input], x.output, :inner)

convert_type(::Type{T}, x::AbstractString) where T<:AbstractString = string(strip(x))

function convert_type(::Type{T}, x::AbstractString) where T<:Integer
    return convert_type(T, convert_type(Float64, x))
end

function convert_type(::Type{T}, x::AbstractString) where T<:Real
    return parse(T, reduce(replace, ["," => "", "\"" => ""], init = x))
end

convert_type(::Type{T}, x::Symbol) where T<:Real = convert_type(T, convert_type(String, x))

convert_type(::Type{DataFrame}, lst::Array{Dict{Any,Any},1}) = [DataFrame.(lst)...;]

function convert_type(::Type{DataFrame}, arr::JuMP.Containers.DenseAxisArray; cols = [])
    cols = ensurearray(cols)
    
    val = JuMP.value.(arr.data)
    ind = permute(arr.axes);
    val = collect(Iterators.flatten(val));

    df = hcat(DataFrame(ensuretuple.(ind)), DataFrame([val], [:value]))
    return edit_with(df, Rename.(propertynames(df)[1:length(cols)], cols))
end

function convert_type(::Type{Dict}, df::DataFrame; drop_cols = [], value_col::Symbol = :Float)
    # Find and save the column containing values and that/those containing keys.
    # If no value column indicator is specified, find the first DataFrame column of floats.
    value_col == :Float && (value_col = find_oftype(df, AbstractFloat)[1])
    key_cols = setdiff(propertynames(df), convert_type.(Symbol, ensurearray(drop_cols)), [value_col])
    ONEKEY = length(key_cols) == 1

    d = Dict((ONEKEY ? row[key_cols[1]] : (row[key_cols]...,)) => row[value_col]
        for row in eachrow(df))
    return d
end

convert_type(::Type{DataType}, x::AbstractString) = datatype(x)

convert_type(::Type{Array{T}}, x::Any) where T<:Any = convert_type.(T, x)
convert_type(::Type{Array{T,1}}, x::Any) where T<:Any = convert_type.(T, x)
convert_type(::Type{Array}, d::Dict) = [collect(values(d))...;]

convert_type(::Type{T}, x::Missing) where T<:Real = x;
convert_type(::Type{T}, x::Missing) where T<:AbstractString = x
convert_type(::Type{Any}, x::AbstractString) = "missing" == lowercase(x) ? missing : x
convert_type(::Type{Any}, x::Any) = x

convert_type(::Type{T}, x::Any) where T = T(x)

convert_type(::Type{Bool}, x::AbstractString) = lowercase(x) == "true" ? true : false

# [@printf("%-8s %s\n", T, fieldpropertynames(T)[T.types .== Any]) for T in subtypes(Edit) if Any in T.types]

"""
    isarray(x::Any)
Returns true/false if the the DataType or object is an array.
"""
isarray(::Type{Array{T,1}}) where T <: Any = true
isarray(x::Array{T,1}) where T <: Any = true
isarray(::Any) = false

"""
    ensurearray(x::Any)
"""
ensurearray(x::Array{T,1}) where T <: Any = x
ensurearray(x::Tuple{Vararg{Any}}) = collect(x)
ensurearray(x::UnitRange) = collect(x)
ensurearray(x::Any) = [x]

"""
    ensuretuple(x::Any)
Returns `x` in a tuple.
"""
ensuretuple(x::Tuple{Vararg{Any}}) = x
ensuretuple(x::Any) = tuple(x)

"""
"""
istype(df::DataFrame, T::DataType) = broadcast(<:, eltype.(eachcol(dropmissing(df))), T)
# eltype.(eachcol(df))

function hasnames(df::DataFrame, cols::Array{Symbol,1})
    col_in = setdiff(propertynames(df),cols)
    col_out = setdiff(cols, propertynames(df))
    return (length(col_in) == 0) && (length(col_out) == 0)
end

function ensurenames!(df::DataFrame, cols::Array{Symbol,1})
    size(df,2) !== length(cols) && @error("Can only ensure column names of the data frame length")
    cols_in = setdiff(propertynames(df),cols)
    cols_out = setdiff(cols, propertynames(df))

    [rename!(df, col_in => col_out) for (col_in,col_out) in zip(cols_in,cols_out)]
    return df[:,cols]
end
ensurenames(df::DataFrame, cols::Array{Symbol,1}) = ensurenames!(copy(df), cols)

"""
    find_oftype(df::DataFrame, T::DataType)
    find_oftype(df::Dict, T::DataType)
Returns DataFrame column names of the specified type.
"""
find_oftype(df::DataFrame, T::DataType) = propertynames(df)[istype(df, T)]
find_oftype(df::DataFrame, T::InvertedIndex{DataType}) = propertynames(df)[.!istype(df, T.skip)]

function find_oftype(d::Dict, T::DataType)
    return Dict(k => v for (k,v) in d if any(broadcast(<:, typeof.(ensurearray(v)), T)))
end

"""
    permute(x::Any)
This function finds all possible permutations of the input arrays.

# Arguments
- `x::Tuple` or `x::NamedTuple{}` or `x::Array`: list of arrays to permute.
    If `x` is a NamedTuple, its values will be permuted.

# Returns
- `x::Array{Tuple,1}`: list of all possible permutations of the input values.
    If `x` does not contain at least one array, there will be nothing to permute and the function will return `x`.
"""
function permute(df::DataFrame)
    cols = propertynames(df)
    df = sort(DataFrame(ensuretuple.(permute(unique.(eachcol(df))))))
    df = edit_with(df, Rename.(propertynames(df), cols))
    return df
end

function permute(x::Tuple)
    xperm = if length(x) == 1
        sort(unique(x[1]))
    else
        [collect(Base.Iterators.product(sort.(unique.(ensurearray.(x)))...))...;]
    end
    return xperm
end

function permute(x::NamedTuple)
    cols = keys(x)
    xperm = eachcol(sort(DataFrame(Tuple.(ensurearray.(permute(ensurearray.(values(x))))))))
    return NamedTuple{Tuple(cols,)}(xperm,)
end

function permute(x::Array)
    xperm = if any(isarray.(x))
        permute(Tuple(x))
    elseif length(unique(length.(x))) .== 1 && all(length.(x) .> 1)
        permute(unique.(eachcol(DataFrame(x))))
    else
        sort(unique(x))
    end
    return xperm
end