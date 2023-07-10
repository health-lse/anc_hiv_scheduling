"""
ANC cleaning pipeline
It loads the csv files, read the table information in each file and clean the contents.
"""

from clean_utils import *
import pandas as pd
import numpy as np
from os import listdir


def get_csv_data(file_names, treat_control):
    csv_data = pd.DataFrame()
    for csv in file_names:
        facility_df = pd.read_csv(f"{cleaned_files_path}/{csv}")
        facility_df["us"] = int(csv.replace("facility_", "").replace(".csv", ""))
        csv_data = pd.concat([csv_data, facility_df])

    rename_cols = {"us_id":"1_us_id",
                "time_arrived":"4_time_arrived",
                "time_entered":"5_time_entered",
                "time_left":"6_time_left"}
    csv_data = csv_data.rename(columns=rename_cols)
    csv_data = csv_data[["file_name", "1_us_id", "day", "us",
                    "4_time_arrived", "5_time_entered",
                    "6_time_left", "9_time_scheduled_cleaned"]]

    # merge with treatment
    csv_data["facility"] = csv_data["us"]
    tc_df = pd.read_stata(treat_control)
    tc_df = tc_df[["facility_cod", "treatment"]]
    csv_data = csv_data.merge(tc_df, left_on="facility", right_on="facility_cod", 
                how = "left")

    # rename columns
    csv_data["time_arrived"] = csv_data["4_time_arrived"]
    csv_data["time_entered"] = csv_data["5_time_entered"]
    csv_data["time_left"] = csv_data["6_time_left"]
    csv_data["time_scheduled"] = csv_data["9_time_scheduled_cleaned"]

    # clean columns
    csv_data.loc[:,"time_arrived"] = (csv_data["time_arrived"]
                                        .astype(str)
                                        .apply(clean_time_with_h))
    csv_data.loc[:,"time_entered"] = (csv_data["time_entered"]
                                        .astype(str)
                                        .apply(clean_time_with_h))
    csv_data.loc[:,"time_left"] = (csv_data["time_left"]
                                        .astype(str)
                                        .apply(clean_time_with_h))
    csv_data.loc[:,"time_scheduled"] = (csv_data["time_scheduled"]
                                        .astype(str)
                                        .apply(clean_time_with_h))

    csv_data = csv_data[pd.to_numeric(csv_data['time_arrived'], errors='coerce').notnull()]
    csv_data = csv_data[pd.to_numeric(csv_data['time_entered'], errors='coerce').notnull()]
    csv_data = csv_data[pd.to_numeric(csv_data['time_left'], errors='coerce').notnull()]

    time_cols = ['time_arrived','time_entered','time_left']
    csv_data.loc[:, time_cols] = csv_data[time_cols].applymap(float)

    csv_data["time_arrived"] = csv_data["time_arrived"].astype(int)
    csv_data["time_entered"] = csv_data["time_entered"].astype(int)
    csv_data["time_left"] = csv_data["time_left"].astype(int)
    return csv_data


def validate_times(final):
    final = final[(final["time_arrived"].astype(str).str.len() > 2) &
            (final["time_arrived"].astype(str).str.len() < 5)]
    final = final[(final["time_entered"].astype(str).str.len() > 2) &
            (final["time_entered"].astype(str).str.len() < 5)]
    final = final[(final["time_left"].astype(str).str.len() > 2) &
            (final["time_left"].astype(str).str.len() < 5)]


    final["waiting_time_temp"] = final["time_entered"] - final["time_arrived"]
    final = final.query("waiting_time_temp >= 0")

    final = final[final["time_arrived"] >= 600]
    final = final[final["time_entered"] <= 1600]
    final = final[final["time_left"] <= 1600]
    return final


def calculate_waiting_time(final):
    list_arrived = final['time_arrived'].to_list()
    list_entered = final['time_entered'].to_list()
    list_wt = []

    for (arrived, entered) in  zip(list_arrived, list_entered):
        list_wt.append(time_diff(entered, arrived))

    final["waiting_time"] = list_wt
    final = final[final["waiting_time"] != -1]
    final = final[final["waiting_time"] >= 0]

    # consultation duration
    list_arrived = final['time_arrived'].to_list()
    list_entered = final['time_entered'].to_list()
    list_left = final['time_left'].to_list()
    list_duration = []

    i = 0
    for (entered, left) in  zip(list_entered, list_left):
        list_duration.append(time_diff(left, entered))
    final["consultation_duration"] = list_duration

    final.loc[final["consultation_duration"] < 0,"consultation_duration"] = np.nan
    return final


def create_day_of_the_week(final):
    # create day_of_week
    final.loc[final["day"].isin([1, 6, 11]), "day_of_week"] = 1
    final.loc[final["day"].isin([2, 7, 12]), "day_of_week"] = 2
    final.loc[final["day"].isin([3, 8]), "day_of_week"] = 3
    final.loc[final["day"].isin([4, 9]), "day_of_week"] = 4
    final.loc[final["day"].isin([5, 10]), "day_of_week"] = 5
    return final


def assign_consultation_reason(anc):
    
    # load consultation reason
    consultation_reason = pd.read_csv(c_reason_csv)
    consultation_reason = consultation_reason[["us_id", "consultation_reason"]]
    anc["us_id"] = anc["1_us_id"]
    anc["file_name"] = anc["file_name"].str.replace(".txt", "")
    anc = anc.drop_duplicates("us_id")

    consultation_reason = consultation_reason.drop_duplicates("us_id")
    return anc.merge(consultation_reason[["us_id", "consultation_reason"]],
            left_on=["us_id"],
            right_on=["us_id"],
            how="left",
            indicator=True)


def clean_time_scheduled_anc(anc):
    anc = anc.drop("1_us_id", axis=1)
    anc.loc[anc["time_scheduled"] == 'nan', "time_scheduled"] = ""
    anc.loc[anc["time_scheduled"].isnull(), "time_scheduled"] = ""
    anc["time_scheduled_cleaned"] = (anc["time_scheduled"].astype(str)
                                                        .apply(clean_time_scheduled)
                                                        .apply(clean_time_scheduled))

    anc["scheduled"] = 0
    anc.loc[anc["time_scheduled_cleaned"] != "", "scheduled"] = 1

    scheduled_by_fac = (anc.query("consultation_reason == 2")
                        .groupby("facility")["scheduled"]
                    .mean().round(2).reset_index())
    scheduled_by_fac = scheduled_by_fac.rename(columns={"scheduled":"scheduled_mean_fac"})

    anc = anc.merge(scheduled_by_fac, left_on="facility", right_on="facility")
    anc["complier"] = (anc["scheduled_mean_fac"] > 0.2).astype(int)
    anc["complier"] = anc["complier"] * anc["treatment"]

    anc["full_complier"] = (anc["scheduled_mean_fac"] > 0.7).astype(int)
    anc["full_complier"] = anc["full_complier"]*anc["treatment"]

    anc["time_arrived_float"] = (anc["time_arrived"]
                                            .apply(time_to_time_float))
    return anc


def select_columns_anc(anc):
    anc = anc[["file_name", "facility", "day", "us_id",
        "treatment", "day_of_week",
        "time_arrived", "time_entered", "time_left", "time_scheduled_cleaned",
        "waiting_time", "consultation_duration", 
        "consultation_reason", "scheduled_mean_fac", "complier", "full_complier",
        "time_arrived_float"]]
    anc["time_scheduled_hours"] = (anc["time_scheduled_cleaned"]
                                            .apply(time_to_time_float))
    return anc


def calculate_std_scheduled_time(anc):
    # compute standard deviation of scheduled time
    std_df = (anc
        .groupby(["facility","day"])
            ["time_scheduled_hours"]
            .std()
        .reset_index()
        .rename(columns={"time_scheduled_hours":"scheduled_std"}))

    return anc.merge(std_df, left_on=["facility", "day"],
                right_on=["facility", "day"], how="inner")


def save_complier_data(anc):
## SAVE COMPLIER DATASET
    complier = (anc.groupby("facility")
                [["treatment", "complier", "full_complier"]]
                .first()
                .reset_index())
    complier = complier.rename(columns={"facility":"facility_cod"}).set_index("facility_cod")
    complier.loc[[5,9], "complier"] = 1

    complier.to_stata(f"{CLEANED_DATA_PATH}/complier.dta")

def share_10(time_array):
    """returns the percent of obs before 10"""
    total_obs = len(time_array)
    obs_before_10 = np.sum(np.where(time_array >= 1000, 1, 0))
    
    return obs_before_10 / total_obs


def gen_open_hours_df(anc):
    time_array = np.array([600, 800, 1000, 1050, 1200])
    share_10(time_array)

    open_h = (anc.groupby(["facility", "day","treatment","day_of_week"])
    .agg({"time_entered":["first", "last",share_10],
            "time_arrived":share_10})
    .reset_index())
    open_h["open"] = open_h["time_entered"]["first"]
    open_h["close"] = open_h["time_entered"]["last"]
    open_h["consultation_after_10"] = open_h["time_entered"]["share_10"]
    open_h["arrived_after_10"] = open_h["time_arrived"]["share_10"]
    open_h = open_h.drop("time_entered", axis=1)
    open_h = open_h.drop("time_arrived", axis=1)

    list_open = open_h['open'].to_list()
    list_close = open_h['close'].to_list()
    list_wt = []

    for (open_, close) in  zip(list_open, list_close):
        list_wt.append(time_diff(close, open_))

    open_h["opening_time"] = list_wt
    open_h.droplevel(1, axis=1).to_stata(f"{CLEANED_DATA_PATH}/opening_time.dta")


def clean_anc():
    treat_control = f"{AUX}/treatment_hdd.dta"

    # load csv files
    file_names = [f for f in listdir(cleaned_files_path) if "csv" in f]
    anc = (get_csv_data(file_names, treat_control)
                             .pipe(validate_times)
                             .pipe(calculate_waiting_time)
                             .pipe(create_day_of_the_week)
                             .pipe(assign_consultation_reason)
                             .pipe(clean_time_scheduled_anc)
                             .pipe(select_columns_anc)
                             .pipe(calculate_std_scheduled_time))

    anc.loc[anc["facility"].isin([5,39]), "complier"] = 1
    save_complier_data(anc)

    anc["treatment_status"] = "treated"
    anc.loc[anc["treatment"] == 0, "treatment_status"] = "control"

    anc["reason"] = np.nan
    anc.loc[anc["consultation_reason"] == 1, "reason"] = "1st visits"
    anc.loc[anc["consultation_reason"] == 2, "reason"] = "Follow-up"

    facility_characteristics = pd.read_stata(f"{AUX}/facility_characteristics.dta")
    facility_characteristics = facility_characteristics.drop("treatment", axis=1)
    volume_baseline = pd.read_stata(f"{AUX}/facility_volume_baseline.dta")

    anc = anc.merge(facility_characteristics, left_on=["facility"],
            right_on="facility_cod")
    anc = anc.merge(volume_baseline, left_on="facility",
          right_on="facility_cod")

    final_name = "anc_cpn_endline_v20230704"
    anc["time_scheduled_cleaned"] = anc["time_scheduled_cleaned"].astype(str)

    nurses_notna = anc.eval("n_nurses != 0 & n_nurses.notna()")
    anc.loc[nurses_notna, "pat_nurses"] = (anc.loc[nurses_notna, "volume_base_total"]
                                            .div(anc.loc[nurses_notna, "n_nurses"]))
    anc.to_csv(f"{CLEANED_DATA_PATH}/{final_name}.csv",
                index=False, mode="w")
    #anc.to_stata(f"{CLEANED_DATA_PATH}/{final_name}.dta")

    gen_open_hours_df(anc)
    print("ANC cleaned!")

#PATHS
ROOT = "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling/data"

cleaned_files_path = f"{ROOT}/anc/csv_cleaned"
CLEANED_DATA_PATH = f"{ROOT}/cleaned_data"
AUX = f"{ROOT}/aux"

c_reason_csv = f"{AUX}/anc_consultation_reason_20230610.csv"

def __init__():
    clean_anc()

__init__()