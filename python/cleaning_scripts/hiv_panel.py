"""
    Code to transform MOZART data into panel format
"""

import pandas as pd
import numpy as np
import datetime as dt
from hiv_panel_utils import *

# When intervention started in maputo
intervention_maputo = dt.datetime(2020, 10, 26)

# When intervention started in gaza/inhambane
intervention_ig = dt.datetime(2020, 12, 7)

interv_date_maputo = dt.datetime(2020, 10, 26)
interv_date_gaza = dt.datetime(2020, 12, 7)

start_dates_maputo, start_dates_gaza = get_start_dates_array(interv_date_maputo,
                                                             interv_date_gaza)

def to_panel_df(df, periods, start_dates, computing_function):
    n_months = len(start_dates)
    nid = df.index[0]
    #days_without_med = get_days_without_med_by_month(df,
    #                                             start_dates)
    days_without_med = computing_function(df,start_dates)

    panel = pd.DataFrame({#"nid":np.tile(nid,n_months-2),
                  "period":periods,
                  "days_without_med":days_without_med})
    panel["treatment"] = df["treatment"].iloc[0]
    panel["province"] = df["province"].iloc[0]
    panel["facility_cod"] = df["facility_cod"].iloc[0]
    panel["pac_sex"] = df["pac_sex"].iloc[0]
    panel["pac_age"] = df["pac_age"].iloc[0]
    panel["pac_start_date_arv"] = df["pac_start_date_arv"].iloc[0]
    panel["pac_start_date_arv"] = df["pac_start_date_arv"].iloc[0]

    return panel

def to_panel_maputo(df):
    months=range(1,6)
    return to_panel_df(df, months, start_dates_maputo,
                      get_days_without_med_by_month)

def to_panel_gaza(df):
    months=range(1,6)
    return to_panel_df(df, months, start_dates_gaza,
                      get_days_without_med_by_month)

def to_panel_maputo_old_cohort(df):
    periods=range(1,7)
    start_dates_maputo_old, start_dates_gaza_old = get_days_maputo_gaza_old()
    return to_panel_df(df, periods, start_dates_maputo_old,
                      get_days_without_med_old_cohort)

def to_panel_gaza_old_cohort(df):
    periods=range(1,7)
    start_dates_maputo_old, start_dates_gaza_old = get_days_maputo_gaza_old()
    return to_panel_df(df, periods, start_dates_gaza_old,
                      get_days_without_med_old_cohort)


def get_months_to_period_old_cohort():
    months_to_period_old_cohort = {}
    # post-treatment
    for i in range(3):
        months_to_period_old_cohort[i*3]=i
        months_to_period_old_cohort[i*3+1]=i
        months_to_period_old_cohort[i*3+2]=i
    # before-treatment
    for i in range(1,5):
        months_to_period_old_cohort[-i*3]=-i
        months_to_period_old_cohort[-i*3+1]=-i
        months_to_period_old_cohort[-i*3+2]=-i

    for i in range(8):
        months_to_period_old_cohort[i*3]=i
        months_to_period_old_cohort[i*3+1]=i
        months_to_period_old_cohort[i*3+2]=i

    return months_to_period_old_cohort

def get_days_without_med_old_cohort(df,start_dates):
    dict_start_periods_old_cohort = get_dict_start_periods_old_cohort()
    start_dates_maputo_old, start_dates_gaza_old = get_days_maputo_gaza_old()
    months_to_period_old_cohort = get_months_to_period_old_cohort()

    first_treated_month = df["month_order"].iloc[0]

    first_period_1st_day = get_start_date_old_cohort(first_treated_month,
                              dict_start_periods_old_cohort,
                              start_dates_maputo_old)

    df["pickup_day"] = (df["pick_up"] - first_period_1st_day).dt.days

    first_treated_period = months_to_period_old_cohort[first_treated_month]
    first_treated_period = first_treated_period + 4

    nans = np.tile(np.nan, first_treated_period)

    pickup_days = df["pickup_day"].values
    quantities = df["qtt"].values
    total_periods = len(start_dates)

    period_start_days_numeric = get_start_days(start_dates,
                                               first_treated_period)

    array_days_without_med = compute_days_without_med(pickup_days,
                                                      quantities,
                                                      period_start_days_numeric)

    filled_array = np.concatenate( (nans, array_days_without_med) )
    return filled_array

def get_dict_start_periods_old_cohort():
    dict_start_periods_old_cohort = {}

    # post-treatment
    for i in range(0,8):
        dict_start_periods_old_cohort[-12 + i*3]=i
        dict_start_periods_old_cohort[-12 + i*3 + 1]=i
        dict_start_periods_old_cohort[-12 + i*3 + 2]=i
    return dict_start_periods_old_cohort

def create_panels():
    """
        reads the dataset with pickups and transform it into the panel format
    """
    # change path to your local path
    path_to_data_folder = f"/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling"
    path_cleaned_data = f"{path_to_data_folder}/data/cleaned_data/mozart"

    treat_df = pd.read_stata(f"{path_to_data_folder}/data/aux/treatment_hdd.dta")

    print("reading mozart data...")
    adm = pd.read_csv(f"{path_cleaned_data}/data_merge_pre_stata.csv", sep="\t")
    adm = adm.rename(columns={"hdd.x":"hdd",
                            "trv_date_pickup_drug":"pick_up"})
    adm["pick_up"] = pd.to_datetime(adm["pick_up"])
    adm = adm.query("pick_up > '2019-08-01'")

    new_label_maputo = {"province": {"MaputoCidade": "Maputo Cidade",
                                    "MaputoProvíncia": "Maputo Província"}}
    adm.replace(new_label_maputo , inplace = True)
    adm = adm[~adm.eval("trv_quantity_taken > 360")]
    adm = adm[adm.eval("trv_quantity_taken.notna()")]

    adm = adm.merge(treat_df, on="hdd",
                    suffixes=('', '_y'),indicator=True)
    
    adm = adm.query("trv_quantity_taken > 0") # 4k observations
    #adm["diff"] = adm["trv_diff_actual_expected_duratio"]
    adm["pick_up"] = pd.to_datetime(adm["pick_up"])
    adm["post"] = 0
    adm["maputo"] = 0
    adm.loc[adm['province']
            .isin(['Maputo Cidade', 'Maputo Província']),
            'maputo'] = 1

    adm.loc[((adm['maputo'] == 1) & (adm['pick_up'] >= '2020-10-26')),'post'] = 1
    adm.loc[((adm['maputo'] == 0) & (adm['pick_up'] >= '2020-12-07')),'post'] = 1

    adm["pickup_order_from_first"] = (adm.groupby("nid")["pick_up"]
                                        .rank(method="first", ascending=True))

    ## PRE/POST pickups
    post = adm.query("post == 1")[["nid", "pick_up"]]
    pre  = adm.query("post == 0")[["nid", "pick_up"]]

    post['pickup_order'] = (post.groupby("nid")["pick_up"]
                        .rank(method="first", ascending=True))
    pre['pickup_order'] = (pre.groupby("nid")["pick_up"]
                        .rank(method="first", ascending=False))
    pre["pickup_order"] = pre["pickup_order"]*(-1)
    pre_post = pd.concat([pre, post], axis=0)
    adm = pre_post.merge(adm, left_on=["nid", "pick_up"], right_on=["nid", "pick_up"])

    ## PRE/POST months
    maputo = adm.query("maputo == 1")[["nid", "pick_up"]]
    inhambane_gaza  = adm.query("maputo == 0")[["nid", "pick_up"]]

    maputo["month_order"] = maputo["pick_up"].apply(diff_maputo)
    inhambane_gaza["month_order"] = inhambane_gaza["pick_up"].apply(diff_gaza_inhambane)

    maputo_ig = pd.concat([maputo, inhambane_gaza], axis=0)

    adm = maputo_ig.merge(adm, left_on=["nid", "pick_up"], right_on=["nid", "pick_up"])

    adm = adm.query("month_order <= 11")
    adm["qtt"] = adm["trv_quantity_taken"]

    adm["treatment_status"] = "tratamento"
    adm.loc[adm["treatment"] == 0, "treatment_status"] = "controlo"
    adm = adm.set_index("nid")
    adm["new_patient"] = 0
    new_patient_query = "pickup_order_from_first == 1 & month_order >= 0"

    new_patient_nid = adm.query(new_patient_query).index
    adm.loc[new_patient_nid,"new_patient"] = 1
    adm=adm.reset_index()

    new = adm.query("new_patient == 1 & month_order <= 5")
    new["month_order"] = new["month_order"].astype(int)
    new["pick_up"] = pd.to_datetime(new["pick_up"],format="%Y-%m-%d")

    nids_not_30 = (new[
        ~(new["qtt"] == 30)
        ]["nid"]
    .unique())

    # remove nids that have at least 1 pickup that is not 30
    new_30 = new[~new["nid"].isin(nids_not_30)]

    # remove nids that have more than 1 pickup in a single day.
    duplicated_pickups = (new_30[new_30[["nid","pickup_order"]].duplicated()]
        ["nid"]).unique()
    new_30 = new_30[~new_30["nid"].isin(duplicated_pickups)]

    #new = 
    new_maputo = new_30.query("maputo == 1").sort_values("pick_up")
    new_gaza = new_30.query("maputo == 0").sort_values("pick_up")

    print("generating panel for maputo new patients ...")
    panel_maputo_all = (new_maputo.set_index("nid")
        .groupby("nid")
        .apply(to_panel_maputo)
        .reset_index())

    print("generating panel for gaza new patients ...")
    panel_gaza_all = (new_gaza.set_index("nid")
        .groupby("nid")
        .apply(to_panel_gaza)
        .reset_index())

    panel_30 = pd.concat([panel_maputo_all,panel_gaza_all])
    panel_30["mpr"] = (30 - panel_30["days_without_med"])/30

    panel_30["treatment_status"] = "treatment"
    panel_30.loc[panel_30["treatment"] == 0, "treatment_status"] = "control"

    panel_30.drop("level_1",axis=1).to_stata(f"{path_cleaned_data}/panel_new_30.dta")
    print("panel for new patients in the 30 day regimen generated")

    #dict_start_periods_old_cohort = get_dict_start_periods_old_cohort()

    new = adm.query("new_patient == 1 & month_order <= 5")
    new["month_order"] = new["month_order"].astype(int)
    new["pick_up"] = pd.to_datetime(new["pick_up"],format="%Y-%m-%d")

    duplicated_pickups = (new[new[["nid","pickup_order"]].duplicated()]
        ["nid"]).unique()
    new = new[~new["nid"].isin(duplicated_pickups)]

    new_maputo = new.query("maputo == 1").sort_values("pick_up")
    new_gaza = new.query("maputo == 0").sort_values("pick_up")

    print("generating panel for maputo - old patients")
    panel_maputo_all = (new_maputo.set_index("nid")
        .groupby("nid")
        .apply(to_panel_maputo)
        .reset_index())

    print("generating panel for gaza - old patients")
    panel_gaza_all = (new_gaza.set_index("nid")
        .groupby("nid")
        .apply(to_panel_gaza)
        .reset_index())

    panel_all = pd.concat([panel_maputo_all,panel_gaza_all])
    panel_all["mpr"] = (30 - panel_all["days_without_med"])/30

    #panel_all["treatment_status"] = "tratamento"
    #panel_all.loc[panel_all["treatment"] == 0, "treatment_status"] = "controlo"

    panel_all["treatment_status"] = "treatment"
    panel_all.loc[panel_all["treatment"] == 0, "treatment_status"] = "control"


    panel_all.loc[panel_all["days_without_med"].notnull(),"delay_7"] = 0
    filter_7_29 = panel_all["days_without_med"].between(8,29,inclusive="both")
    panel_all.loc[filter_7_29, "delay_7"] = 1

    panel_all.drop("level_1",axis=1).to_stata(f"{path_cleaned_data}/panel_new_all.dta")

    adm["month_order"] = adm["month_order"].astype(int)

    adm = adm.set_index("nid")
    query_period="new_patient == 0 & month_order >= -12 & month_order <= 8 & pickup_order_from_first == 1"
    index_period = (adm.query(query_period).index)

    old = adm.loc[index_period].reset_index()
    adm = adm.reset_index()
    old["pick_up"] = pd.to_datetime(old["pick_up"],format="%Y-%m-%d")

    # remove nids that have more than 1 pickup in a single day.
    duplicated_pickups = (old[old[["nid","pickup_order"]].duplicated()]
        ["nid"]).unique()
    old = old[~old["nid"].isin(duplicated_pickups)]

    old_maputo = old.query("maputo == 1").sort_values("pick_up")
    old_gaza = old.query("maputo == 0").sort_values("pick_up")

    panel_maputo_old = (old_maputo.set_index("nid")
        .groupby("nid")
        .apply(to_panel_maputo_old_cohort)
        .reset_index())

    panel_gaza_old = (old_gaza.set_index("nid")
        .groupby("nid")
        .apply(to_panel_gaza_old_cohort)
        .reset_index())

    panel_old = pd.concat([panel_maputo_old,panel_gaza_old])
    panel_old["mpr"] = (90 - panel_old["days_without_med"])/90
    panel_old.loc[:, "period"] = panel_old["period"] -4

    panel_old["treatment_status"] = "treatment"
    panel_old.loc[panel_old["treatment"] == 0, "treatment_status"] = "control"


    panel_old.drop("level_1",axis=1).to_stata(f"{path_cleaned_data}/panel_old.dta")

    print("panel for old patients generated")


def run_tests():
    # TEST CASE 1
    dates = ["05/06/2020"]

    df = new_df_test(dates, np.tile(90,len(dates)))
    start_dates_maputo_old, start_dates_gaza_old = get_days_maputo_gaza_old()

    start_dates = start_dates_maputo_old

    days = get_days_without_med_old_cohort(df,start_dates)
    expected_result = [np.nan, np.nan, 53., 90., 90., 90.]

    assert np.array_equal(days,expected_result,equal_nan=True)

    # TEST CASE 2
    dates = ["28/10/2020",
    "27/11/2020",
    "27/12/2020",
    "26/01/2021",
    "25/02/2021",
    "27/03/2021"]
    df_test = new_df_test(dates, np.tile(30,len(dates)))

    days = get_days_without_med_old_cohort(df_test,start_dates)
    expected_result = [np.nan, np.nan, np.nan, np.nan,  0., 88.]
    assert np.array_equal(days,expected_result,
                        equal_nan=True)

    # TEST CASE 3
    dates = ["15/12/2019",
    "15/03/2020",
    "15/06/2020",
    "15/09/2020"]
    df_test = new_df_test(dates, np.tile(90,len(dates)))

    days = get_days_without_med_old_cohort(df_test,start_dates)
    expected_result = [ 1.,  2.,  2., 41., 90., 90.]
    assert np.array_equal(days,expected_result,
                        equal_nan=True)
    print("Panel generation tests run with success!!")


def __init__():
    run_tests()
    create_panels()

__init__()