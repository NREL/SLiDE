"""
    read_file(path::Array{String,1}, file::CSVInput)
"""
function read_file(path::Array{String,1}, file::CSVInput)
    filepath = joinpath(path..., file.name)
    df = CSV.read(filepath, silencewarnings = true)
    return df
end

"""
    read_file(path::Array{String,1}, x::XLSXInput)
"""
function read_file(path::Array{String,1}, file::XLSXInput)
    filepath = joinpath(path..., file.name)
    xf = XLSX.readdata(filepath, file.sheet, file.range)
    df = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)
    return df
end

"""
    read_file(path::String, x::T) where T<:File
"""
read_file(path::String, x::T) where T<:File = read_file([path], x)


"""
    read_file(file::String)
"""
function read_file(file::String)
    
    if occursin(".yml", file) | occursin(".yaml", file)

        y = YAML.load(open(file))

        # Here, we first list all sub-subtypes of DataStream (DataTypes that are used in
        # editing datasource files). Then, we find where they overlap with keys in the
        # dictionary read from the YAML file.
        TYPES = string.([IU.subtypes.(IU.subtypes(DataStream))...;])
        # !!!! Not sure why only using subtypes without the module name gets UndefVarError.
        KEYS = intersect(TYPES, [k for k in keys(y)]);

        # These are the values to convert into DataFrames
        # (necessary before converting into DataStream types).
        [y[k] = convert_type(DataFrame, y[k]) for k in KEYS]

        # Next, load each key entry into lists of Edit structures.
        # This can generally be passed into the SLiDE.edit_with() function.
        [y[k] = load_from(datatype(k), y[k]) for k in KEYS];
        return y

    elseif occursin(".csv", file)
        df = CSV.read(filepath, silencewarnings = true)
        return df
    end

end