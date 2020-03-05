

# match(r"(?<aggr>.*)\&(?<sect>.*)", v)

# m=match(r"(?<hour>\d+):(?<minute>\d+)","12:45")

# Define tuple of inputs:
regions = ["co","md","nd","wi"]
sectors = ["agr","fof"]
other = ["a","b"]

inp = tuple(regions, sectors, other)

# Define dictionary missing some keys:
k = vcat(collect(Base.Iterators.product(inp...))...)
d = Dict(k => 1.0 for k in k[1:end-2])

function fill_zero(source::Tuple, tofill::Dict)

    # Assume all possible permutations of keys should be present
    # and determine which are missing.
    allkeys = vcat(collect(Base.Iterators.product(source...))...)
    missingkeys = setdiff(allkeys, collect(keys(tofill)))

    # Add 
    [push!(tofill, fill=>0) for fill in missingkeys]
    return tofill
end

fill_zero(inp, d)

# GSP FULL_CODE -> STATE_CODE, COUNTY_CODE
str = "01001"
match(r"(?<state_code>\d{2})(?<county_code>\d*)", str)

# NASS NAICS_CODE -> NAICS_CODE
str = "NAICS CLASSIFICATION: (111)"
match(r"\((?<naics_code>.*)\)", str)

str = "1114 Mushrooms, Nursery & Related Products"
match(r"(?<naics_industry_group_code>\d*) (?<naics_industry_group_desc>.*)", str)