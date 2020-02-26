# Define sets #
#  Sets
#       i   canning plants   / seattle, san-diego /
#       j   markets          / new-york, chicago, topeka / ;
plants  = ["seattle","san_diego"]          # canning plants
markets = ["new_york","chicago","topeka"]  # markets

# Define parameters #
#   Parameters
#       a(i)  capacity of plant i in cases
#         /    seattle     350
#              san-diego   600  /
a = Dict(              # capacity of plant i in cases
  "seattle"   => 350,
  "san_diego" => 600,
)
b = Dict(              # demand at market j in cases
  "new_york"  => 325,
  "chicago"   => 300,
  "topeka"    => 275,
)

trmodel = Model()
# Variables
@variables trmodel begin
    x[p in plants, m in markets] >= 0 # shipment quantities in cases
end

# Constraints
@constraints trmodel begin
    supply[p in plants],   # observe supply limit at plant p
        sum(x[p,m] for m in markets)  <=  a[p]
    demand[m in markets],  # satisfy demand at market m
        sum(x[p,m] for p in plants)  >=  b[m]
end