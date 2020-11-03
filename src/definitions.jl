# Build options.
const DEFAULT_SAVE_BUILD = true
const DEFAULT_OVERWRITE = false
const DEFAULT_DATASET = "default"
const BUILD_STEPS = ["partition", "share", "share_i", "calibrate", "disagg"];
const PARAM_DIR = "parameters"
const SET_DIR = "sets"

# CALIBRATION
DEFAULT_PENALTY_NOKEY = 1e4
DEFAULT_LOWER_BOUND = 0.1
DEFAULT_UPPER_BOUND = 5

# NUMERICAL
const DEFAULT_TOL = 1e-6
const DEFAULT_SMALL = missing
const DEFAULT_ROUND_DIGITS = 10

# STATE MODEL
const SUB_ELAST = Dict()
SUB_ELAST[:va] = 1
SUB_ELAST[:y] = 0
SUB_ELAST[:m] = 0
SUB_ELAST[:a] = 0
SUB_ELAST[:mar] = 0
SUB_ELAST[:d] = 2
SUB_ELAST[:f] = 4

const TRANS_ELAST = Dict(:x => 4)