using Complementarity
using CSV
using DataFrames
using JuMP
using Revise
using XLSX
using YAML

using SLiDE  # see src/SLiDE.jl

DATA_DIR = abspath(joinpath(dirname(Base.find_package("SLiDE")), "..", "data"));
READ_MAP = joinpath(DATA_DIR, "readfiles", "1_map");

y = SLiDE.read_file(joinpath(READ_MAP, "naics_01.yml"));
dfa = SLiDE.edit_with(y);
CSV.write(joinpath(y["PathOut"]...), dfa);


y = SLiDE.read_file(joinpath(READ_MAP, "naics_02.yml"));
# dfb = SLiDE.read_file(y["Path"], y["XLSXInput"]);
# dfb = SLiDE.edit_with(dfb, y["Rename"]);
dfb = SLiDE.edit_with(y);
CSV.write(joinpath(y["PathOut"]...), dfb);


y = SLiDE.read_file(joinpath(READ_MAP, "naics_03.yml"));
dfc = SLiDE.edit_with(y);
CSV.write(joinpath(y["PathOut"]...), dfc);

y = SLiDE.read_file(joinpath(READ_MAP, "naics_04.yml"));
# dfd = SLiDE.read_file(y["Path"], y["XLSXInput"]);
dfd = SLiDE.edit_with(y);
CSV.write(joinpath(y["PathOut"]...), dfc);

############################################################################################
y = SLiDE.read_file(joinpath(READ_MAP, "naics_margins.yml"));
dfm = SLiDE.read_file(y["Path"], y["XLSXInput"]);
dfm = SLiDE.edit_with(dfm, y["Rename"]);

dfind = dfm[:,1:2];
dfcom = dfm[:,3:4];
dfbea = SLiDE.read_file(y["Map"]);

# df = copy(dfc[:,1:2])
# x = y["Group"]

# # First, add a column to the original DataFrame indicating where the data set begins.
# cols = unique(push!(names(df), x.output))
# df[!,:start] = (1:size(df)[1]) .+ 1

# # Next, create a DataFrame describing where to "split" the input DataFrame.
# # Editing with a map will remove all rows that do not contain relevant information.
# # Add a column indicating where each data set STOPS, assuming all completely blank rows
# # were removed by read_file().
# df_split = SLiDE.edit_with(copy(df), Map(x.file, x.from, x.to, x.input, x.output); kind = :inner);
# sort!(unique!(df_split), :start)
# df_split[!, :stop] .= vcat(df_split[2:end, :start] .- 2, [size(df)[1]])

# # Add a new, blank output column to store identifying information about the data block.
# # Then, fill this column based on the identifying row numbers in df_split.
# df[!,x.output] .= ""
# [df[row[:start]:row[:stop], x.output] .= row[x.output] for row in eachrow(df_split)]

# df = df[df[:,x.output] .!= "", :]
# return df[:, cols]

############################################################################################
