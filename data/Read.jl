# Import necessary packages.


# Define module and begin.
module Read


using CSV
using DataFrames
using Dates
using XLSX
using YAML

import YAML

"""
    input(filepath::String)
    input(filepath::String, dict::Dict)
This is a generic read function. If there is a dictionary input, the function will use key
values.
"""
function input(filepath::String)
    if occursin(".csv", filepath)
        ans = CSV.read(filepath, silencewarnings = true)
    elseif occursin(".yml", filepath)
        ans = YAML.load(open(filepath))
    end
    return ans
end

function input(filepath::String, dict::Dict)
    if occursin(".csv", filepath)
        ans = CSV.read(filepath, silencewarnings = true)
    elseif occursin(".xlsx", filepath)
        xf = XLSX.readdata(filepath, dict["sheet"], dict["range"])
        ans = DataFrame(xf[2:end,:], Symbol.(xf[1,:]), makeunique = true)
    end
    return ans
end

"""
    convert(string)
Idk figure out how to update this?
"""
convert(to::DataType, x::String) where t == Symbol

end # module