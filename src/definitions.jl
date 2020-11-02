# Build options.
const DEFAULT_SAVE_BUILD = true
const DEFAULT_OVERWRITE = false
const DEFAULT_DATASET = "default"
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