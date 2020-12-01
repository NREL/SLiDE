x = 0  # defined globally
for ii in 1:5
    x *= ii  # defined locally within the loop
end

x = 0
[x *= ii for ii in 1:5]

function testerror()
    x = 0  # defined globally
for ii in 1:5
    x *= ii  # defined locally within the loop
end
return x
end
testerror();

function testerror2(x)
    # x = 0  # defined globally
for ii in 1:5
    x *= ii  # defined locally within the loop
end
return x
end
x=0
testerror2(x)


function testerror3(x)
    # x = 0  # defined globally
#    x = 0
    [x *= ii for ii in 1:5]
return x
end
x=0
testerror3(x)

"""
Function to sort model years and produce first, last years and booleans

Usage:
years = [2017, 2016, 2019, 2018]
(years, yrl, yrf, islast, isfirst, yrdiff) = yrsbool(years)
"""
function yrsbool(years::Array{Int,1})
    years = sort(years)
    yrlast = years[length(years)]
    yrfirst = years[1]
    islast = Dict(years[k] => (years[k] == yrlast ? 1 : 0) for k in keys(years))
    isfirst = Dict(years[k] => (years[k] == yrfirst ? 1 : 0) for k in keys(years))
    yrdiff = Dict(years[k+1] => years[k+1]-years[k] for k in 1:(length(years)-1))
    return (years, yrlast, yrfirst, islast, isfirst, yrdiff)
end

years = [2017, 2016, 2019, 2018]
(years, yrl, yrf, islast, isfirst, yrdiff) = yrsbool(years)
