# Build options.
const DEFAULT_SAVE_BUILD = false
const DEFAULT_OVERWRITE = false
const DEFAULT_DATASET = "state_model"
const BUILD_STEPS = ["partition", "share", "share_i", "calibrate", "disagg"];
const PARAM_DIR = "parameters"
const SET_DIR = "sets"

# CALIBRATION
const DEFAULT_PENALTY_NOKEY = 1e4
const DEFAULT_CALIBRATE_LOWER_BOUND = 0.1
const DEFAULT_CALIBRATE_UPPER_BOUND = 5

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