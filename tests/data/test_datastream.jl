# appending = Append()

renaming = [
    Rename(from = :IOCode, to = :from_industry_code),
    Rename(from = :Name,   to = :from_industry_desc)];

melting = Melt(on = :from_industry_desc, var = :to_industry_desc, val = :value, type = String);

adding = Add(col = :units, val = "millions of us dollars (USD)");

replacing = Replace(col = :value, from = "...", to = 0);

# mapping = Map("regions.csv", from = :from, to = :to, input = :region, output = :region);