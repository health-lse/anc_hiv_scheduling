"""
    Functions used to generated the mozart panel
"""

import pandas as pd
import numpy as np
import datetime as dt


def get_start_dates_array(interv_date_maputo, interv_date_gaza):
    start_dates_maputo = np.array([])
    start_dates_gaza = np.array([])

    for i in range(0,7):
        date_maputo = (interv_date_maputo 
                            + dt.timedelta(days=30*i))
        start_dates_maputo = np.append(start_dates_maputo, date_maputo)

        date_gaza = (interv_date_gaza + dt.timedelta(days=30*i))
        start_dates_gaza = np.append(start_dates_gaza, date_gaza)
    return start_dates_maputo, start_dates_gaza

def clean_numeric_column(column_name, df):
    """
        convert column to numeric
    """
    df[column_name] = df[column_name].map(str)
    df = df[df[column_name] != ""]
    df[column_name] = pd.to_numeric(df[column_name], errors='coerce')
    return df

def diff_month(d1, d2):
    """
        returns difference in month between 2 dates
    """
    diff = (d1.year - d2.year) * 12 + d1.month - d2.month - 1
    months = (d1 - d2).days // 30
    #months = months if months < 0 else months + 1
    return months

def diff_maputo(df):
    return diff_month(df, intervention_maputo)

def diff_gaza_inhambane(df):
    return diff_month(df, intervention_ig)

def compute_days_without_med(pickup_days,quantities,period_start_days):
    """
        Based on a list of pickup dates and quantities,
        calculate the number of days without medication
        for each month. See test cases 
    """
    days_without_med = []

    filter_period = ((pickup_days >= 0) & (pickup_days < period_start_days[0]))
    # qtt in 1st period
    qtt_1st = quantities[filter_period]

    surplus = np.sum(qtt_1st) - period_start_days[0] + pickup_days[0]
    n_months = len(period_start_days)
    for i, period_start in enumerate(period_start_days[0:(n_months-1)]):
        # pickups in this period
        next_period_start = period_start_days[i+1]
        filter_period = ((pickup_days >= period_start) & (pickup_days < next_period_start))
        pickups = pickup_days[filter_period]

        total_days_in_period = next_period_start - period_start

        if len(pickups) == 0:
            balance_period = surplus - total_days_in_period
            if (balance_period < 0):
                days_without_med.append(balance_period)
                surplus = 0
            else:
                days_without_med.append(0)
                surplus = balance_period
            continue

        first_pickup_of_the_period = pickups[0]
        last_pickup = pickups[len(pickups) -1]

        #quantities taken in this period
        qtt_period = quantities[filter_period]

        # compute surplus till first pickup in period
        days_till_first_pickup = first_pickup_of_the_period - period_start

        # if there was not enough medication till pickup day
        # days_without_med[i] is negative
        # if there was more than the number of days,
        # the surplus is accumulated for next period
        balance_period = surplus - days_till_first_pickup
        extra_pills = 0
        if (balance_period < 0):
            days_without_med.append(balance_period)
        else:
            days_without_med.append(0)
            extra_pills = balance_period

        # update surplus for next period
        surplus = first_pickup_of_the_period + np.sum(qtt_period) - next_period_start + extra_pills

    return np.array(days_without_med)*(-1)

def get_start_days(start_dates, first_treated_month):
    ## return the days in terms of distance from the 
    ## first start days of the second treated period
    total_months = len(start_dates)
    #dates = start_dates[(first_treated_month+1):total_months]
    #days = [d.days for d in  (dates - start_dates[(first_treated_month+1)]) ] 
    dates = start_dates[(first_treated_month+1):(total_months+1)]

    days = [d.days for d in  (dates - start_dates[first_treated_month])] 
    return days

def get_days_maputo_gaza_old():
    ## Prepares the panel for OLD patients
    interv_date_maputo = dt.datetime(2020, 10, 26)
    interv_date_gaza = dt.datetime(2020, 12, 7)

    start_dates_maputo_after = np.array([])
    start_dates_gaza_after = np.array([])

    period_length = 90
    for i in range(0,4):
        date_maputo = (interv_date_maputo 
                            + dt.timedelta(days=period_length*i))
        start_dates_maputo_after = np.append(start_dates_maputo_after, date_maputo)

        date_gaza = (interv_date_gaza 
                            + dt.timedelta(days=period_length*i))
        start_dates_gaza_after = np.append(start_dates_gaza_after, date_gaza)
    
    
    start_dates_maputo_before = np.array([])    
    start_dates_gaza_before = np.array([])

    for i in range(1,5):
        date_maputo = (interv_date_maputo 
                            - dt.timedelta(days=period_length*i))
        start_dates_maputo_before = np.append(start_dates_maputo_before,
                                            date_maputo)

        date_gaza = (interv_date_gaza 
                            - dt.timedelta(days=period_length*i))
        start_dates_gaza_before = np.append(start_dates_gaza_before,
                                            date_gaza)    
        
    start_dates_maputo_before.sort()
    start_dates_gaza_before.sort()

    start_dates_maputo_old = np.concatenate([start_dates_maputo_before,
                                        start_dates_maputo_after])
    start_dates_gaza_old = np.concatenate([start_dates_gaza_before,
                                        start_dates_gaza_after])
    return start_dates_maputo_old, start_dates_gaza_old

def get_days_without_med_by_month(df,start_dates):
    """
        Normalize panel for all patients. Given the start
        of the treatment, fills with zeros in the months before
        the first pickup for patients who started in later months
    """
    first_treated_month = df["month_order"].iloc[0]
    first_period_1st_day = start_dates[first_treated_month]

    df["pickup_day"] = (df["pick_up"] - first_period_1st_day).dt.days

    # fill the months before treatment with nan's
    nans = np.tile(np.nan, first_treated_month)

    pickup_days = df["pickup_day"].values
    quantities = df["qtt"].values
    total_months = len(start_dates)
    #period_start_days = start_dates[(first_treated_month+1):total_months]

    period_start_days_numeric = get_start_days(start_dates,
                                               first_treated_month)

    array_days_without_med = compute_days_without_med(pickup_days,
                                                      quantities,
                                                      period_start_days_numeric)
    # fill the months before treatment started with nan
    filled_array = np.concatenate( (nans, array_days_without_med) )
    return filled_array

def diff_month(d1, d2):
    diff = (d1.year - d2.year) * 12 + d1.month - d2.month - 1
    months = (d1 - d2).days // 30
    #months = months if months < 0 else months + 1
    return months

def diff_maputo(df):
    return diff_month(df, intervention_maputo)

def new_df_test(dates, qtt):
    """ used just to test panel with test cases
    """
    ids = np.tile(1,len(dates))
    df_test = pd.DataFrame({"nid":ids,"pick_up":dates,"qtt":qtt})
    df_test["pick_up"] = pd.to_datetime(df_test["pick_up"],
                                        format="%d/%m/%Y")

    df_test['pickup_order'] = (df_test.groupby("nid")["pick_up"]
                        .rank(method="first", ascending=True))

    df_test["month_order"] = df_test["pick_up"].apply(diff_maputo)
    df_test = df_test.sort_values(["nid","pick_up"])
    return df_test

def get_start_date_old_cohort(first_treated_month,
                              dict_start_dates,
                              start_dates):
    
    first_treated_period = dict_start_dates[first_treated_month]
    return start_dates[first_treated_period]


def get_first_treated_period(first_treated_month,
                              dict_start_dates,
                              start_dates):
    
    first_treated_period = dict_start_dates[first_treated_month]
    return start_dates[first_treated_period]


##### TESTS #####

# When intervention started in maputo
global intervention_maputo
intervention_maputo = dt.datetime(2020, 10, 26)

# When intervention started in gaza/inhambane
global intervention_ig
intervention_ig = dt.datetime(2020, 12, 7)

# needed here for tests
interv_date_maputo = dt.datetime(2020, 10, 26)
interv_date_gaza = dt.datetime(2020, 12, 7)

global start_dates_maputo
global start_dates_gaza
start_dates_maputo, start_dates_gaza = get_start_dates_array(interv_date_maputo,
                                                             interv_date_gaza)

assert diff_month(intervention_ig, intervention_maputo) == 1
assert diff_month(intervention_maputo, intervention_ig) == -2
assert diff_month(dt.datetime(2020, 10, 27), dt.datetime(2020, 10, 26)) == 0
assert diff_month(dt.datetime(2020, 10, 25), dt.datetime(2020, 10, 26)) == -1
assert diff_month(dt.datetime(2020, 10, 26), dt.datetime(2020, 10, 26)) == 0
assert diff_month(dt.datetime(2020, 11, 26), dt.datetime(2020, 10, 26)) == 1
assert diff_month(dt.datetime(2020, 11, 27), dt.datetime(2020, 10, 26)) == 1



# Test case 1:
pickup_days = np.array([8,40,71,108])
quantities = np.array([30,30,30,30])
period_start_days = np.array([30,60,90,120])
days_without_med = compute_days_without_med(pickup_days,
                                            quantities,
                                            period_start_days)

assert np.array_equal(days_without_med,np.array([2, 1, 7]),
                      equal_nan=True)

# Test case 2:
pickup_days = np.array([8,71,108])
quantities = np.array([30,30,30])
period_start_days = np.array([30,60,90,120])
days_without_med = compute_days_without_med(pickup_days,
                                            quantities,
                                            period_start_days)

assert np.array_equal(days_without_med,np.array([22, 11, 7]),
                      equal_nan=True)

# Test case 3:
pickup_days = np.array([1,31,62,95])
quantities = np.array([30,30,30,30])
period_start_days = np.array([30,60,90,120])
days_without_med = compute_days_without_med(pickup_days,
                                            quantities,
                                            period_start_days)

assert np.array_equal(days_without_med,np.array([0, 1, 3]),
                      equal_nan=True)

# Test case 4:
pickup_days = np.array([1,33,58,95])
quantities = np.array([30,30,30,30])
period_start_days = np.array([30,60,90,120])
days_without_med = compute_days_without_med(pickup_days,
                                            quantities,
                                            period_start_days)

assert np.array_equal(days_without_med,np.array([2, 0, 2]),
                      equal_nan=True)

# Test case 5:
pickup_days = np.array([1,31,95,192])
quantities = np.array([30,90,90,90])
period_start_days = np.array([90,180,270,360])
days_without_med = compute_days_without_med(pickup_days,
                                            quantities,
                                            period_start_days)

assert np.array_equal(days_without_med,np.array([0, 0, 59]),
                      equal_nan=True)


### TEST CASE 1
dates = [
"08/01/2021",
"08/02/2021",
"07/03/2021",
"02/04/2021"]
df_test = new_df_test(dates, np.tile(30,4))

days_without_med = get_days_without_med_by_month(df_test,
                                                 start_dates_maputo)
expected_result = [np.nan, np.nan, 1.,  0.,  0.]
assert np.array_equal(days_without_med,expected_result,
                      equal_nan=True)

### TEST CASE 2
dates = ["28/11/2020"]
df_test = new_df_test(dates, np.tile(30,len(dates)))

days_without_med = get_days_without_med_by_month(df_test,
                                                 start_dates_maputo)
expected_result = [np.nan, 27., 30., 30., 30]
assert np.array_equal(days_without_med,expected_result,
                      equal_nan=True)

### TEST CASE 3
dates = ["28/10/2020",
"27/11/2020",
"27/12/2020",
"26/01/2021",
"25/02/2021",
"27/03/2021"]
df_test = new_df_test(dates, np.tile(30,len(dates)))

days_without_med = get_days_without_med_by_month(df_test,
                                                 start_dates_maputo)
expected_result = np.tile(0,5)
assert np.array_equal(days_without_med,expected_result,
                      equal_nan=True)

### TEST CASE 4
dates = ["28/12/2020",
"26/02/2021"]
df_test = new_df_test(dates, np.tile(30,len(dates)))

days_without_med = get_days_without_med_by_month(df_test,
                                                 start_dates_maputo)
expected_result = [np.nan, np.nan,27.,3.,27.]
assert np.array_equal(days_without_med,
                      expected_result,
                      equal_nan=True)

print("Tests hiv_panel_utils run with success!")