from datetime import datetime
def time_diff(final_time, initial_time):
    try:
        final = str(final_time)
        size_f = len(final)
        str_f = final[0:(size_f-2)] + ":" + final[(size_f-2):size_f]

        inital = str(initial_time)
        size_i = len(inital)
        str_i = inital[0:(size_i-2)] + ":" + inital[(size_i-2):size_i]

        FMT = '%H:%M'
        return ((datetime.strptime(str_f, FMT) - datetime.strptime(str_i, FMT))
                    .total_seconds()/60)
    except:
        return -1

assert time_diff(990, 910) == -1   
assert time_diff(920, 910) == 10   #10
assert time_diff(920, 850) == 30   #70 
assert time_diff(940, 910) == 30   #30 
assert time_diff(1320, 920) == 240 #400
assert time_diff(1030, 1000) == 30 #70
assert time_diff(1010, 950) == 20  #60
assert time_diff(1000, 900) == 60  #60




# Load the anc dataset and run the following code


open_h = (anc.groupby(["facility_cod", "day","treatment","day_of_week"])
 .agg({"time_entered":["first", "last"]})
 .reset_index())
open_h["open"] = open_h["time_entered"]["first"]
open_h["close"] = open_h["time_entered"]["last"]
open_h = open_h.drop("time_entered", axis=1)
open_h = open_h.drop("time_arrived", axis=1)

list_open = open_h['open'].to_list()
list_close = open_h['close'].to_list()
list_wt = []

for (open_, close) in  zip(list_open, list_close):
    list_wt.append(time_diff(close, open_))

open_h["opening_time"] = list_wt
open_h.to_stata("/Users/rafaelfrade/arquivos/desenv/lse/anc_rct/data/opening_time.dta")
