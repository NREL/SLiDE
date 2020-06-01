using DataFrames
using Dates

"""
    function datatype(str::String)
This function evaluates an input string as a DataType if it is defined.
Otherwise, it will return false.
See: (thread on discourse.julialang.org)[https://discourse.julialang.org/t/parse-string-to-datatype/7118/9]
"""
function datatype(str::String)
    # type = :($(Symbol(titlecase(str))))
    type = :($(Symbol(str)))
    return isdefined(SLiDE, type) ? eval(type) : nothing
end


Base.broadcastable(x::InvertedIndex{T}) where {T<:Any} = [x];

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
    convert_type(::Type{T}, x::Any)
    convert_type(::Dict{Any,Any}, df::DataFrame, value_col::Symbol; kwargs...)
Converts `x` into the specified `Type{T}`.

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

function convert_type(::Type{Dict}, df::DataFrame; drop_cols = [], value_col::Symbol = :Float)
    # Find and save the column containing values and that/those containing keys.
    # If no value column indicator is specified, find the first DataFrame column of floats.
    value_col == :Float && (value_col = find_oftype(df, AbstractFloat)[1])
    key_cols = setdiff(names(df), convert_type.(Symbol, ensurearray(drop_cols)), [value_col])
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

# [@printf("%-8s %s\n", T, fieldnames(T)[T.types .== Any]) for T in subtypes(Edit) if Any in T.types]

"""
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


istype(df::DataFrame, T::DataType) = broadcast(<:, eltypes(dropmissing(df)), T)


"""
    find_oftype(df::DataFrame, T::DataType)
    find_oftype(df::Dict, T::DataType)
"""
find_oftype(df::DataFrame, T::DataType) = names(df)[istype(df, T)]
find_oftype(df::DataFrame, T::InvertedIndex{DataType}) = names(df)[.!istype(df, T.skip)]

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
    cols = names(df)
    df = sort(DataFrame(Tuple.(permute(unique.(eachcol(df))))))
    return edit_with(df, Rename.(names(df), cols))
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
    xperm = eachcol(sort(DataFrame(Tuple.(permute(values(x))))))
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