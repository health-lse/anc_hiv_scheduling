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



#### ANC:
# Load the anc dataset and run the following code
CLEANED_DATA = "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/data/cleaned_data"
anc = pd.read_csv(f"{CLEANED_DATA}/anc_cpn_endline_v20230704.csv")

open_h = (anc.groupby(["facility_cod", "day","treatment","day_of_week"])
 .agg({"time_entered":["min", "max", "count"]})
 .reset_index())
open_h["open"] = open_h["time_entered"]["min"]
open_h["close"] = open_h["time_entered"]["max"]
open_h["nvisits"] = open_h["time_entered"]["count"]
open_h = open_h.drop("time_entered", axis=1)
#open_h = open_h.drop("time_arrived", axis=1)

list_open = open_h['open'].to_list()
list_close = open_h['close'].to_list()
list_wt = []

for (open_, close) in  zip(list_open, list_close):
    list_wt.append(time_diff(close, open_))

open_h["opening_time"] = list_wt
open_h.columns = open_h.columns.droplevel(1)
open_h.to_stata(f"{CLEANED_DATA}/anc_opening_time.dta")

#### HIV:
# for hif pharmacy data there is no time_entered. I will compute the opening time 
#   from consultation_time (which is the time of exit from the pharmacy)
CLEANED_DATA = "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/data/cleaned_data"
hiv = pd.read_stata(f"{CLEANED_DATA}/hiv_endline.dta")

hiv["consultation_time"] = pd.to_numeric(hiv["consultation_time_str"])
open_h = (hiv.groupby(["facility_cod", "day","treatment","day_of_week"])
 .agg({"consultation_time":["min", "max", "count"]})
 .reset_index())
open_h["open"] = open_h["consultation_time"]["min"]
open_h["close"] = open_h["consultation_time"]["max"]
open_h["nvisits"] = open_h["consultation_time"]["count"]
open_h = open_h.drop("consultation_time", axis=1)
#open_h = open_h.drop("time_arrived", axis=1)

list_open = open_h['open'].to_list()
list_close = open_h['close'].to_list()
list_wt = []

for (open_, close) in  zip(list_open, list_close):
    list_wt.append(time_diff(close, open_))

open_h["opening_time"] = list_wt
open_h.columns = open_h.columns.droplevel(1)
open_h.to_stata(f"{CLEANED_DATA}/hiv_opening_time.dta")