renaming = [
    Rename(from = :IOCode, to = :from_industry_code),
    Rename(from = :Name,   to = :from_industry_desc)];

melting = Melt(on = :from_industry_desc, var = :to_industry_desc, val = :value, type = Any);

mapping = [
    Map(file = "bea_all.csv", from = :desc, to = :code, input = :from_industry_desc, output = :from_industry_code),
    Map(file = "bea_all.csv", from = :desc, to = :code, input = :to_industry_desc,   output = :to_industry_code)];

adding = Add(col = :units, val = "millions of us dollars (USD)");

replacing = Replace(col = :value, from = "...", to = "0");