module Parse

using DataFrames

"""
    append_with(df::DataFrame, d::Dict)
"""
function append_with(df::DataFrame, d::Dict) end

"""
    group_with(df::DataFrame, d::Dict)
"""
function group_with(df::DataFrame, d::Dict) end

"""
    join_with(df::DataFrame, d::Dict)
"""
function join_with(df::DataFrame, d::Dict) end

"""
    map_with(df::DataFrame, d::Dict)
"""
function map_with(df::DataFrame, d::Dict) end

"""
    melt_with(df::DataFrame, d::Dict)
"""
function melt_with(df::DataFrame, d::Dict) end

"""
    rename_with(df::DataFrame, d::Dict)
"""
function rename_with(df::DataFrame, d::Dict) end

"""
    append_with(df::DataFrame, d::Dict)
"""
function replace_with(df::DataFrame, d::Dict) end

"""
    set_with(df::DataFrame, d::Dict)
"""
function set_with(df::DataFrame, d::Dict) end

end # module