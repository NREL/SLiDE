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
(!!!!) add docs here.
"""
Base.broadcastable(x::InvertedIndex{T}) where {T <: Any} = [x];


"""
    Base.split(x::Missing)
    Base.split(x::Number)
Extends `split` to ignore missing fields.
"""
Base.split(str::Missing) = str
Base.split(str::Missing, splitter::Any) = str
Base.split(x::Symbol) = Symbol.(split(string(x)))


"""
    Base.strip(x::Missing)
    Base.strip(x::Number)
Extends `strip` to ignore missing fields and numbers.
"""
Base.strip(x::String) = replace(x, r"^\s*\"*|\"*\s*$" => "")
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
Converts `x` into the specified `Type{xT}`.

Consider extending [convert](https://docs.julialang.org/en/v1/base/base/#Base.convert)
function (!!!!)

# Arguments
- `::Type{T}`: target DataType.
- `x<:Any`: value to convert.

# Keywords
Options available when converting a DataFrame into a dictionary of keys pointing to a value:
- `drop_cols = []`: Columns not to include in
    the keys. By default, no columns are dropped.
- `value_col::Symbol = :end`: If converting

# Returns
Data in specified type
"""
convert_type(::Type{T}, x::Any) where T <: AbstractString = string(x)
convert_type(::Type{T}, x::Dates.Date) where T <: Integer = Dates.year(x)

convert_type(::Type{Map}, x::Group) = Map(x.file, [x.from], x.to, [x.input], x.output, :inner)
convert_type(::Type{CSVInput}, x::DataInput) = CSVInput(x.name, x.descriptor)
convert_type(::Type{CSVInput}, x::SetInput) = CSVInput(x.name, "set")

convert_type(::Type{T}, x::AbstractString) where T <: AbstractString = string(strip(x))

function convert_type(::Type{T}, x::AbstractString) where T <: Integer
    return convert_type(T, convert_type(Float64, x))
end

function convert_type(::Type{T}, x::AbstractString) where T <: Real
    return parse(T, reduce(replace, ["," => "", "\"" => ""], init=x))
end

convert_type(::Type{T}, x::Symbol) where T <: Real = convert_type(T, convert_type(String, x))

function convert_type(::Type{DataFrame}, x::Array{Any,2})
    col = Symbol.(replace(x[1,:], "" => missing))
    data = x[2:end,:]
    return DataFrame(data, col, makeunique = true)
end

convert_type(::Type{DataFrame}, lst::Array{Dict{Any,Any},1}) = [DataFrame.(lst)...;]

function convert_type(::Type{DataFrame}, arr::JuMP.Containers.DenseAxisArray; cols=[])
    cols = ensurearray(cols)
    
    val = JuMP.value.(arr.data)
    ind = permute(arr.axes);
    val = collect(Iterators.flatten(val));

    df = hcat(DataFrame(ensuretuple.(ind)), DataFrame([val], [:value]))
    return edit_with(df, Rename.(propertynames(df)[1:length(cols)], cols))
end

function convert_type(::Type{Dict}, df::DataFrame; drop_cols=[], value_col::Symbol=:Float)
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

convert_type(::Type{Array{T}}, x::Any) where T <: Any = convert_type.(T, x)
convert_type(::Type{Array{T,1}}, x::Any) where T <: Any = convert_type.(T, x)

# !!!! WARNING: DEPRECIATED.
convert_type(::Type{Array}, d::Dict) = [collect(values(d))...;]

convert_type(::Type{Array{Tuple}}, df::DataFrame) = ensuretuple.(eachrow(df))
convert_type(::Type{T}, x::Missing) where T <: Real = x;
convert_type(::Type{T}, x::Missing) where T <: AbstractString = x
convert_type(::Type{Any}, x::AbstractString) = "missing" == lowercase(x) ? missing : x
convert_type(::Type{Any}, x::Any) = x

convert_type(::Type{T}, x::Any) where T = T(x)

convert_type(::Type{Bool}, x::AbstractString) = lowercase(x) == "true" ? true : false

convert_type(::Type{UnitRange}, x::AbstractArray) = x[1]:x[end]
convert_type(::Type{UnitRange}, x::Any) = convert_type(UnitRange, ensurearray(x))

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
# Returns
- `x`::AbstractArray
"""
ensurearray(x::Array{T,1}) where T <: Any = x
ensurearray(x::Tuple{Vararg{Any}}) = collect(x)
ensurearray(x::UnitRange) = collect(x)
ensurearray(x::Base.ValueIterator) = [collect(x)...;]
ensurearray(x::DataFrameRow) = ensurearray(values(x))
ensurearray(x::Any) = [x]


"""
    ensuretuple(x::Any)
# Returns
- `x`::Tuple
"""
ensuretuple(x::Tuple{Vararg{Any}}) = x
ensuretuple(x::DataFrameRow) = Tuple(x)
ensuretuple(x::Any) = tuple(x)
# !!!! add examples showing dimensionality to the documentation.


"""
    ensurefinite(x::Float64)
# Returns
- `x`, replacing `NaN` or `Inf` values with `0.0`.
"""
ensurefinite(x::Float64) = (isnan(x) || x==Inf) ? 0.0 : x


"""
"""
istype(df::DataFrame, T::DataType) = broadcast(<:, findtype(df), T)

findtype(df::DataFrame) = eltype.(eachcol(dropmissing(df)))
findtype(x::AbstractArray) = eltype(skipmissing(x))


"""
    find_oftype(df::DataFrame, T::DataType)
    find_oftype(df::Dict, T::DataType)
Returns DataFrame column names of the specified type.
"""
find_oftype(df::DataFrame, T::DataType) = propertynames(df)[istype(df, T)]
find_oftype(df::DataFrame, T::InvertedIndex{DataType}) = propertynames(df)[.!istype(df, T.skip)]

function find_oftype(d::Dict, T::DataType)
    return Dict(k => v for (k, v) in d if any(broadcast(<:, typeof.(ensurearray(v)), T)))
end


"""
    add_permutation!(set, x)
This function adds a permutation of existing set keys to the input dictionary.
If the dictionary does not contiain all of the sets specified in `x`,
the function will produce an error.

# Arguments
- `set::Dict` dictionary to update with permutations
- `x::Tuple{Symbol,1}`: set keys to permute
"""
function add_permutation!(set::Dict, x::Tuple)
    if !(x in keys(set))
        missing_keys = setdiff(ensurearray(x), keys(set))
        if !isempty(missing_keys)
            @error("Cannot create a composite $x. Key(s) $missing_keys missing from set.")
        end
        set[x] = sort(permute([[set[k] for k in x]...,]))
        end
    return set[x]
end


"""
# Returns
- `val::Array{Symbol,1}` of input DataFrame propertynames indicating values, which are
    defined as columns that DO contain `AbstractFloat` or `Bool` DataTypes.
"""
findvalue(df::DataFrame) = [find_oftype(df, AbstractFloat); find_oftype(df, Bool)]


"""
# Returns
- `idx::Array{Symbol,1}` of input DataFrame propertynames indicating indices, which are
    defined as columns that do NOT contain `AbstractFloat` or `Bool` DataTypes.
"""
findindex(df::DataFrame) = setdiff(propertynames(df), findvalue(df))


"""
# Returns
- `utx::Array{Symbol,1}` of input DataFrame propertynames with "units" in the name.
"""
findunits(df::DataFrame) = propertynames_with(df, :units)
# This function is a bit niche, but will be used heavily in the EEM.
# Should maybe keep it internal.


"""
"""
function propertynames_with(df::DataFrame, id::Symbol)
    col = propertynames(df)
    return col[occursin.(id,col)]
end


"""
Appends inputs, maintaining type of first input (currently only works for symbols)
"""
append(x::Array{Symbol,1}) = Symbol(Symbol.(x[1:end-1], :_)..., x[end])
append(x1::Symbol, x2::Any) = Symbol(x1,:_,x2)
append(x1::Symbol, x2::Vararg{Any,N}) where N = append(Symbol.([x1; ensurearray(x2)]))

append(x::Tuple) = append(ensurearray(x))

append(x::Array{String,1}) = string(string.(x[1:end-1], :_)..., x[end])
append(x1::String, x2::Any) = string(x1,:_,x2)
append(x1::String, x2::Vararg{Any,N}) where N = append(string.([x1; ensurearray(x2)]))

append(x1::Nothing, x2::Vararg{Any,N}) where N = append(x2)
append(x::Any) = x
# !!!! clean up this function.