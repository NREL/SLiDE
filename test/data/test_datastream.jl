path = ["data"]

csvreading = CSVInput(name = "test_datastream.csv", descriptor = "1997");

xlsxreading = [
    XLSXInput(name = "test_datastream.xlsx", sheet = "1999", range = "A7:J14", descriptor = "1999"),
    XLSXInput(name = "test_datastream.xlsx", sheet = "2000", range = "A7:J14", descriptor = "2000")];

############################################################################################

describing = Describe(col = :year);

ordering = Order(
    col = [:year, :from_code, :from_desc, :to_code, :to_desc, :value, :units],
    type = [Int, String, String, String, String, Int, String]);

renaming = [
    Rename(from = :IOCode, to = :from_code),
    Rename(from = :Name,   to = :from_desc)];

melting = Melt(
    on = [:from_desc],
    var = :to_desc,
    val = :value,
    type = Any);

adding = [
    Add(col = :region, val = "Colorado"),
    Add(col = :units, val = "millions of us dollars (USD)")];

mapping = Map(
        file = "regions.csv",
        from = [:from],
        to = [:to],
        input = [:region],
        output = [:region]);

replacing = [
    Replace(col = :value, from = "...",   to = 0),
    Replace(col = :value, from = missing, to = 0)];