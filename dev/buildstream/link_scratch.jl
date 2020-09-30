# [global io[k] = convert_type(Dict, io[k]) for k in keys(io)]

# cols = [intersect(propertynames(df), collect(keys(set))); :share]
# [global shr[k] = shr[k][:,intersect(propertynames(df), [collect(keys(set)); :share])] for k in keys(shr)]