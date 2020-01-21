path = ["data"]

csvreading = CSVInput(name = "test_datastream.csv", descriptor = "1997");

xlsxreading = [XLSXInput(name = "test_datastream.xlsx", sheet = "1999", range = "B7:J15", descriptor = "1999"),
               XLSXInput(name = "test_datastream.xlsx", sheet = "2000", range = "B7:J15", descriptor = "2000")];

############################################################################################

renaming = [
    Rename(from = :IOCode, to = :from_industry_code),
    Rename(from = :Name,   to = :from_industry_desc)];

melting = Melt(on = :from_industry_desc, var = :to_industry_desc, val = :value, type = Any);

mapping = [
    Map(file = "bea_all.csv", from = :desc, to = :code, input = :from_industry_desc, output = :from_industry_code),
    Map(file = "bea_all.csv", from = :desc, to = :code, input = :to_industry_desc,   output = :to_industry_code)];

adding = Add(col = :units, val = "millions of us dollars (USD)");

replacing = Replace(col = :value, from = "...", to = "0");