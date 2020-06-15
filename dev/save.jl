# Here are little snippets of code that aren't necessarily used anywhere,
# but are worth saving :)

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
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

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# Get dictionary values with some condition.
d = Dict(k => v > 0.0 for (k,v) in d)
[k => v > 0.0 for (k,v) in d]

# * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * 
# Regular expressions
# GSP FULL_CODE -> STATE_CODE, COUNTY_CODE
str = "01001"
match(r"(?<state_code>\d{2})(?<county_code>\d*)", str)

# NASS NAICS_CODE -> NAICS_CODE
str = "NAICS CLASSIFICATION: (111)"
match(r"\((?<naics_code>.*)\)", str)

str = "1114 Mushrooms, Nursery & Related Products"
match(r"(?<naics_industry_group_code>\d*) (?<naics_industry_group_desc>.*)", str)