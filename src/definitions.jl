# BUILD OPTIONS
const DEFAULT_SAVE_BUILD = false
const DEFAULT_OVERWRITE = false
const DEFAULT_VERSION = "1.0"
const DEFAULT_DATASET = "state_model"
const BUILD_STEPS = ["partition", "share", "calibrate", "disagg"];
const PARAM_DIR = "parameters"
const SET_DIR = "sets"

const DATA_DIR = joinpath(SLIDE_DIR,"data")
const READ_DIR = joinpath(SLIDE_DIR,"src","build","readfiles")

# FILES
const SCALE_BLUENOTE_IO = joinpath(DATA_DIR,"coremaps","scale","sector","bluenote.csv")
const SCALE_EEM_IO = joinpath(DATA_DIR,"coremaps","scale","sector","eem_pmt.csv")

# UNITS
const BTU = "trillion btu"
const KWH = "billion kilowatthours"
const USD = "billions of us dollars (USD)"
const USD_PER_KWH = "us dollars (USD) per thousand kilowatthour"
const USD_PER_BTU = "us dollars (USD) per million btu"
const BTU_PER_BARREL = "million btu per barrel"
const POPULATION = "thousand"
const CHAINED_USD = "millions of chained 2009 us dollars (USD)"

# CALIBRATION
const DEFAULT_CALIBRATE_ZEROPENALTY = Dict(
    :io => 1E4,
    :eem => 1E7,
)

# Multipliers for lower and upper bound relative to each respective variables reference parameter
const DEFAULT_CALIBRATE_BOUND = Dict(
    (:io,:lower) => 0.1,
    (:io,:upper) => 5,
    (:eem,:lower) => 0.25,
    (:eem,:upper) => 1.75,
    (:eem,:seds_lower) => 0.75,
    (:eem,:seds_upper) => 1.25,
)

# NUMERICAL
const DEFAULT_TOL = 1e-6
const DEFAULT_SMALL = missing
const DEFAULT_ROUND_DIGITS = 10

# STATE MODEL
const SUB_ELAST = Dict()
SUB_ELAST[:va] = 1      # value-added nest
SUB_ELAST[:y] = 0       # top-level Y nest (VA,M)
SUB_ELAST[:m] = 0       # materials nest
SUB_ELAST[:a] = 0       # top-level A nest for aggregate demand (margins, goods)
SUB_ELAST[:mar] = 0     # margin supply
SUB_ELAST[:d] = 2       # domestic demand aggregation nest (intranational)
SUB_ELAST[:f] = 4       # domestic and foreign demand aggregation nest (international)

# Transportation elasticity: disposition, distribute regional supply to local, national, export
const TRANS_ELAST = Dict(:x => 4)

# Variable lower bound
const MODEL_LOWER_BOUND = 0.00
