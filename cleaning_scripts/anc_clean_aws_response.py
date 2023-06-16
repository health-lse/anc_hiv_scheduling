"""
ANC cleaning pipeline
It loads aws json files, read the table information in each file and clean the contents.
"""

from util.clean_utils import *
import pandas as pd
import numpy as np
from os import listdir


def get_csv_data(file_names):
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
    treat_control = f"{lse}/adm_data/art_intervention/test/bases_auxiliares/treatment_hdd.dta"
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
    # merge with consultation reason
    c_reason_csv = f"{cleaned_data_path}/anc_consultation_reason_20230610.csv"

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

    complier.to_stata(f"{stata_path}/complier.dta")

def clean_anc():
    # load csv files
    file_names = [f for f in listdir(cleaned_files_path) if "csv" in f]
    anc = (get_csv_data(file_names).pipe(validate_times)
                             .pipe(calculate_waiting_time)
                             .pipe(create_day_of_the_week)
                             .pipe(assign_consultation_reason)
                             .pipe(clean_time_scheduled_anc)
                             .pipe(select_columns_anc)
                             .pipe(calculate_std_scheduled_time))

    anc.loc[anc["facility"].isin([5,39]), "complier"] = 1
    save_complier_data(anc)

    
    final_name = "anc_cpn_endline_v20230611"
    anc.to_csv(f"{cleaned_data_path}/{final_name}.csv",
                index=False, mode="w")
    anc["time_scheduled_cleaned"] = anc["time_scheduled_cleaned"].astype(str)
    #anc.to_stata(f"{stata_path}/{final_name}.dta")
    print("ANC cleaned!")


#PATHS
lse = "/Users/rafaelfrade/arquivos/desenv/lse"
root = "/Users/rafaelfrade/arquivos/desenv/lse/ocr"
cleaned_files_path = f"{root}/files_to_review/csv_cleaned"
cleaned_data_path = f"{root}/cleaned_data"
stata_path = f"{lse}/anc_rct/data"

def __init__():
    clean_anc()

__init__()