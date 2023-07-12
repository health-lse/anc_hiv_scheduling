import pandas as pd
import matplotlib.pyplot as plt 
import seaborn as sns
import numpy as np
import scipy.stats as st
from datetime import datetime

def get_confidence_interval(n, mean, sem):
    return st.t.interval(alpha=0.95, df=n, loc=mean, scale=sem)

def add_error_bar(means, se):
    for i, mean in enumerate(means):
        plt.errorbar(str(i), 
             mean,
             yerr=se[i], 
             color='black',
             ecolor='black', elinewidth=.5, 
             capsize=2, markeredgewidth=.5)

def get_value_counts(df, var, normalize=True):
    countplot_df = (df.groupby("treatment_status")[var]
                         .value_counts(normalize=normalize)
                         .rename('percent')
                         .reset_index()
                     .rename(columns={"index":"reason"})
                   .sort_values([var,"treatment_status"]
                                ,ascending=True))
    countplot_df = countplot_df.query("percent >= 0.01")
    return countplot_df

n = 0
def plot_cathegorical(df, var, title, y_size=5, order_=None,
                      normalize=True, x_size=5, figure=True,
                      error=False):
    """
        plots a normalized count plot of the variable selected
    """
    global n
    if figure:
        plt.figure(figsize=(x_size, y_size), dpi=80)

    countplot_df = get_value_counts(df, var, normalize=normalize)
    copy = countplot_df.copy()
    countplot_df = pd.concat([countplot_df,copy], axis=0)
    
    if error:
        value_counts_df = get_value_counts(df, var, normalize=False)

        #sem = (df.groupby("treatment_status")[var]
        #             .value_counts(normalize=normalize).sem())
        
        i = 0
        n = len(df)/2
        def get_errors(df):
            global n
            mean = df.mean()
            #n = value_counts_df.iloc[i]["percent"]
            ##ci = get_confidence_interval(n, mean, sem)
            p = mean
            se_95 = 1.96*np.sqrt(p*(1-p)/n)
            return (mean - se_95, mean + se_95)

        countplot_df["test"] = 1
        g = sns.barplot(x=var, y="percent",  hue="treatment_status", 
                     data=countplot_df, palette=palette_anc,
                     hue_order=order, errorbar=get_errors,
                     errwidth=0.5, capsize=0.2)
    else:
        g = sns.barplot(x=var, y="percent",  hue="treatment_status", 
             data=countplot_df, palette=palette_anc,
             hue_order=order)

    plt.xticks(fontsize=8)
    plt.yticks(fontsize=8)
    plt.xlabel("")
    plt.ylabel("")
    plt.title(title ,fontsize=10)
    sns.move_legend(g, "lower center", ncol=2, title="", frameon=True)
    #plt.show()
    return g

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
    

def format_graph():
    plt.xticks(fontsize=8)
    plt.yticks(fontsize=8)


def column_by_quantile(df, col, n_quantiles,n_round=2,format_int=True):
    """
        Divide the column in quantiles and generate a label
    """
    quantiles = np.linspace(0,1,n_quantiles+1)

    conditions = []
    labels = []
    for i,q in enumerate(quantiles[0:(n_quantiles)]):
        v = np.quantile(df[col], q)
        v_next = np.quantile(df[col], quantiles[i+1])

        # if last, changes comparison to lower or equal
        if i == n_quantiles-1:
            conditions.append( (df[col] >= v) & (df[col] <= v_next) )
        else:
            conditions.append( (df[col] >= v) & (df[col] < v_next) )

        if format_int:
            lower_bound = int(round(v,n_round))
            upper_bound = int(round(v_next,n_round))
        else:
            lower_bound = round(v,n_round)
            upper_bound = round(v_next,n_round)

        label = f"{lower_bound}-{upper_bound}"
        labels.append(label)
        
    return np.select(conditions, labels),labels

"""
ROOT = "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling/data"
ROOT = "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling/data"

cleaned_files_path = f"{ROOT}/anc/csv_cleaned"
CLEANED_DATA_PATH = f"{ROOT}/cleaned_data"
AUX = f"{ROOT}/aux"
complier_df = pd.read_stata(f"{CLEANED_DATA_PATH}/complier.dta")
facility_characteristics = pd.read_stata(f"{AUX}/facility_characteristics.dta")

volume_baseline = pd.read_stata(f"{AUX}/facility_volume_baseline.dta")

complier_df = complier_df.merge(facility_characteristics, on=["facility_cod", "treatment"])
complier_df = complier_df.merge(volume_baseline, on=["facility_cod"])

column_by_quantile(complier_df.query("index_ANC_readiness.notna()"),
                   "index_ANC_readiness", 3, n_round=0,format_int=False)
"""