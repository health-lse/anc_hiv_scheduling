import pandas as pd
import matplotlib.pyplot as plt 
import seaborn as sns
from graph_utils import *
import numpy as np

def size_1st(anc):
    len_c = len(anc.query("consultation_reason == 1 & treatment == 0"))
    len_t = len(anc.query("consultation_reason == 1 & treatment == 1"))
    return f"n = {len_c} (Control) {len_t} (Treated)"

def size_followup(anc):
    len_c = len(anc.query("consultation_reason == 2 & treatment == 0"))
    len_t = len(anc.query("consultation_reason == 2 & treatment == 1"))
    return f"n = {len_c} (Control) {len_t} (Treated)"

def size_anc(anc):
    len_c = len(anc.query("consultation_reason == 2 & treatment == 0"))
    len_t = len(anc.query("consultation_reason == 2 & treatment == 1"))
    return f"n = {len_c} (Control) {len_t} (Treated)"

def load_tc_df(treat_control_full_path):
    ## Loads treatment/control dataframe
    tc_df = pd.read_stata(treat_control_full_path)
    tc_df = tc_df[["facility_cod", "treatment"]]
    tc_df["treatment_status"] = "treated"
    tc_df.loc[tc_df["treatment"] == 0, "treatment_status"] = "control"
    return tc_df


def load_anc_df(anc_full_path):
    anc = pd.read_csv(anc_full_path)
    anc["treatment_status"] = "treated"
    anc.loc[anc["treatment"] == 0, "treatment_status"] = "control"

    anc["reason"] = np.nan
    anc.loc[anc["consultation_reason"] == 1, "reason"] = "1st visits"
    anc.loc[anc["consultation_reason"] == 2, "reason"] = "Follow-up"
    return anc


def load_registry_book(reg_book_full_path, tc_df):
    reg_book = pd.read_csv(reg_book_full_path)
    reg_book = reg_book[reg_book["facility_cod"].str.len()<=2]
    reg_book = reg_book[reg_book["anc_total"].str.len()<=2]
    reg_book["anc_total"] = reg_book["anc_total"].astype(int)
    reg_book = reg_book[reg_book["anc_total"] <= 40]

    reg_book = reg_book[reg_book["gestational_age_1st"].str.len()<=2]
    reg_book["gestational_age_1st"] = reg_book["gestational_age_1st"].astype(int)
    reg_book["facility_cod"] = reg_book["facility_cod"].astype(int)
    reg_book["gestational_age_1st"] = reg_book["gestational_age_1st"].astype(int)
    reg_book = reg_book[reg_book["gestational_age_1st"]<=40]

    reg_book.loc[reg_book["facility_name"] == "CS Urbano" ,"facility_cod"] = 50
    reg_book.loc[reg_book["facility_name"] == "CS Unidade 7" ,"facility_cod"] = 66
    reg_book.loc[reg_book["facility_name"] == "CS Porto" ,"facility_cod"] = 4

    reg_book = reg_book.merge(tc_df, left_on="facility_cod", right_on="facility_cod",
                          how="inner")
    return reg_book


def load_hiv_endline(path_hiv_endline):
    hiv = pd.read_csv(path_hiv_endline).query("flag == 0")
    hiv["treatment_status"] = "treated"
    hiv.loc[hiv["treatment"] == 0, "treatment_status"] = "control"

    hiv["pickup_time"] = hiv["consultation_time"]

    hiv["id"] = (hiv["facility"].astype("str") + "_" + hiv["day"].astype("str") + "_" + 
                hiv["page"].astype("str") + "_" +  hiv["line"].astype("str"))
    return hiv

# ANC: Type of Visits
# ANC: Procedures
# ANC: Procedures Detail
# ANC: waiting time coefplot
# ANC: waiting time - day of the week
# ANC: Opening Hours
# ANC: Arrival time coefplot
# ANC: Arrival time histogram
# ANC: Share of consultations before 10am - coefplot
# ANC: Share of consultations before 10am - coefplot
# ANC-het: number of consultations by age group
# ANC-het: number of consultations x ANC readiness
# ANC-het: waiting time x ANC readiness

# ANC: Patient Volumes
def patient_volume():
    print("TODO patient volume")


def get_open_hours(df, arrival_time_col_name):
    open_h = (df.groupby(["facility", "day"])
    .agg({arrival_time_col_name:["first", "last"],
        "facility":"first",
        "day":"first",
        "treatment_status":"first"})
    .reset_index())

    open_h["open"] = open_h[arrival_time_col_name]["first"]
    open_h["close"] = open_h[arrival_time_col_name]["last"]
    open_h["facility"] = open_h["facility"]
    open_h["day"] = open_h["day"]

    open_h = open_h[["facility", "day", "open", "close", "treatment_status"]]
    open_h = open_h.droplevel(1, axis=1)

    open_h = open_h.loc[:,~open_h.columns.duplicated()].copy()

    list_open = open_h['open'].to_list()
    list_close = open_h['close'].to_list()
    list_wt = []

    for (open_, close) in  zip(list_open, list_close):
        list_wt.append(time_diff(close, open_))

    open_h["opening_time"] = list_wt
    return open_h


def anc_hiv_opening_hours(hiv_endline, anc):
    open_hiv = get_open_hours(hiv_endline, "arrival_time")
    plt.figure(figsize=(6, 3))
    plt.suptitle("Opening hours")
    plt.subplot(1,2,1)
    open_hiv["openting_time_hours"] = open_hiv["opening_time"]/60
    sns.barplot(open_hiv,
                x="treatment_status", y="openting_time_hours",
                palette=palette_anc, errwidth=0.5, capsize=0.1,
                order=order, errorbar=("se", 1.96))

    plt.title("HIV", fontsize=10)
    plt.xlabel(SOURCE_WT_FORMS  + "\n n=80 facilities, 12 days each", size=6)
    plt.ylabel("time in hours", fontsize=8)
    plt.ylim([0,4.3])
    plt.yticks(range(0,5), fontsize=8)
    plt.xticks(fontsize=8)

    plt.subplot(1,2,2)
    #open_h_anc = pd.read_stata(f"{lse}/anc_rct/data/opening_time.dta")
    open_h_anc = get_open_hours(anc, "time_arrived")

    title = "ANC: Average opening hours"

    open_h_anc["openting_time_hours"] = open_h_anc["opening_time"]/60
    sns.barplot(open_h_anc,
                x="treatment_status", y="openting_time_hours",
                palette=palette_anc, errwidth=0.5, capsize=0.1,
                order=order, errorbar=("se", 1.96))
    plt.title("ANC", fontsize=10)
    plt.xlabel(SOURCE_WT_FORMS + "\n n=77 facilities, 12 days each", size=6)
    plt.ylabel("")
    plt.ylim([0,4.3])
    plt.yticks(range(0,5), fontsize=8)
    plt.xticks(fontsize=8)

    plt.savefig(f"{img}/opening_hours.jpeg", bbox_inches='tight',dpi=300)


# ANC: Avg Consultations per Patient
def avg_consultations_per_patient(reg_book):

    title = "ANC: Average consultations per patient"
    sns.catplot(data=reg_book,
                x="treatment_status", y="anc_total", kind="bar",
                palette=palette_anc, errwidth=0.5, capsize=0.1,
                order=order, errorbar=("se", 1.96),
                aspect=1, height=3)
    plt.title(title, fontsize=10)

    xlabel = ("Increase of 14% in the average number \n of consultations per patient \n" +
                SOURCE_REG + "\n" +
            SIZE_REG_BOOK)
    plt.xlabel(xlabel, size=8)
    plt.ylabel("")
    format_graph()

    plt.savefig(f"{img}/consultations_per_patient.jpeg", bbox_inches='tight',dpi=300)


def waiting_time_by_consultation_reason(anc):
    plt.figure(figsize=(6, 3))
    plt.subplot(1, 2, 1)
    sns.barplot(anc.query("consultation_reason == 1"), 
                x="treatment_status", y="waiting_time",
                palette=palette_anc, errwidth=0.5, capsize=0.1,
                hue_order=order, errorbar=("se", 1.96))
    plt.title("ANC: 1st visits")
    plt.xlabel(SOURCE_WT_FORMS + "\n"+ size_1st(anc) , fontsize=6)
    plt.xticks(fontsize=8)
    plt.yticks(fontsize=8)
    plt.ylabel("time in minutes", fontsize=8)
    plt.ylim([40,140])

    plt.subplot(1, 2, 2)

    sns.barplot(anc.query("consultation_reason == 2"), 
                x="treatment_status", y="waiting_time",
                palette=palette_anc, errwidth=0.5, capsize=0.1,
                hue_order=order, errorbar=("se", 1.96))
    plt.title("ANC: Followup")

    SIZE_HIV = "n = 10708 (Control) 12091 (Treated)"
    plt.xlabel(SOURCE_WT_FORMS + "\n"+ size_followup(anc) , fontsize=6)

    plt.xticks(fontsize=8)
    plt.yticks(fontsize=8)
    plt.ylabel("", fontsize=8)
    plt.ylim([40,140])

    plt.savefig(f"{img}/anc_wt_by_consultation_reason.jpeg", bbox_inches='tight',dpi=300)


def anc_het_wt_province(anc):
    anc["province_label"] = anc["province"]
    anc["province_label"] = anc["province_label"].replace({"Maputo Cidade":"Maputo \n Cidade",
                                                        "Maputo Província":"Maputo \n Província",
                                                        "Inhambane":"Inhamb."})

    plt.figure(figsize=(10, 3))
    plt.subplot(1, 2, 1)

    province_order = ["Maputo \n Cidade", "Maputo \n Província",
                    "Inhamb.", "Gaza"]

    g = sns.barplot(anc.query("consultation_reason == 2"),
                    x="waiting_time", y="province_label",
                    order=province_order,
                    hue="treatment_status",palette=palette_anc,
                    hue_order=order,errwidth=0.5, capsize=0.1,
                    errorbar=("ci",95))
    plt.xlabel("Time in minutes" + "\n" + SOURCE_WT_FORMS + "/SARA \n" + size_followup(anc),
            size=8)

    plt.ylabel("")
    format_graph()
    plt.title("ANC: Waiting time by province - follow-ups" ,fontsize=10)
    plt.xlim([30,160])

    #sns.move_legend(g, "lower right", ncol=2, title="", frameon=True)
    sns.move_legend(g,loc='lower center', ncol=2, title="", frameon=False,
                bbox_to_anchor=(1, -.4))

    plt.subplot(1, 2, 2)
    sns.barplot(anc.query("consultation_reason == 2 & treatment == 1"),
                    x="complier", y="province_label",
                    order=province_order,errwidth=0.5, capsize=0.1,
                    errorbar=("ci",95), color=TREATED)
    plt.title("Percent of patients in complier clinics",size=10)

    plt.ylabel("")
    format_graph()

    plt.savefig(f"{img}/anc_wt_province.jpeg", bbox_inches='tight',dpi=300)



def anc_het_wt_vol(anc):
    followup = anc.query("consultation_reason == 2")
    plt.figure(figsize=(8, 3))
    plt.subplot(1, 2, 1)

    base_vol,labels_base_vol = column_by_quantile(followup, "volume_base_total", 3,
                                            n_round=0,format_int=False)
    followup["base_vol"] = base_vol
    followup["base_vol"] = followup["base_vol"].str.replace(".0","")

    order_base_bol=["82-314", "314-689", "689-1603"]
    g = sns.barplot(followup, x="base_vol",
                y="waiting_time",
                hue="treatment_status",
                order=order_base_bol,
                palette=palette_anc,
                hue_order=order,errwidth=0.5, capsize=0.1)
    plt.xlabel("Baseline patients per month - SISMA / Forms \n"  + size_followup(anc), size=8)
    plt.ylabel("Waiting time in minutes", fontsize=8)
    plt.title("ANC: Waiting time x Baseline volume" ,fontsize=10)
    format_graph()
    sns.move_legend(g, "lower center", ncol=2, title="", frameon=True)

    plt.subplot(1, 2, 2)
    g = sns.barplot(followup.query("treatment == 1"), x="base_vol",
                y="complier", color=TREATED,
                order=order_base_bol,
                errwidth=0.5, capsize=0.1)
    plt.title("ANC: Percentage of patientes in complier facilities" ,fontsize=10)

    plt.xlabel("Baseline patients per month - SISMA \n" + SOURCE_WT_FORMS + size_followup(anc), size=8)

    #sns.move_legend(g, "lower center", ncol=2, title="", frameon=True)
    plt.ylabel("Percentage of patientes", fontsize=8)
    format_graph()
    plt.savefig(f"{img}/anc_het_wt_vol.jpeg", bbox_inches='tight',dpi=300)


def anc_het_arrival_province(anc):
    anc["province_label"] = anc["province"]
    anc["province_label"] = anc["province_label"].replace({"Maputo Cidade":"Maputo \n Cidade",
                                                        "Maputo Província":"Maputo \n Província",
                                                        "Inhambane":"Inhamb."})

    plt.figure(figsize=(10, 3))
    plt.subplot(1, 2, 1)

    province_order = ["Maputo \n Cidade", "Maputo \n Província",
                    "Inhamb.", "Gaza"]

    g = sns.barplot(anc.query("consultation_reason == 2"),
                    x="time_arrived_float", y="province_label",
                    order=province_order,
                    hue="treatment_status",palette=palette_anc,
                    hue_order=order,errwidth=0.5, capsize=0.1,
                    errorbar=("ci",95))
    plt.xlabel("Time in hours" + "\n" + SOURCE_WT_FORMS + " \n" + size_followup(anc),
            size=8)

    plt.ylabel("")
    format_graph()
    plt.title("ANC: Arrival time by province - follow-ups" ,fontsize=10)
    sns.move_legend(g,loc='lower right', ncol=1, title="", frameon=True)
    plt.xlim([5,12])
    plt.savefig(f"{img}/anc_het_arrival_time_province.jpeg", bbox_inches='tight',dpi=300)



def anc_het_wt_urban(anc):
    followup = anc.query("consultation_reason == 2")
    plt.figure(figsize=(8, 3))
    plt.subplot(1, 2, 1)
    g = sns.barplot(followup, x="urban",
                y="waiting_time",
                hue="treatment_status",
                palette=palette_anc,
                hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("ANC: Waiting time in urban facilities \n (Followu-ps)" ,fontsize=10)

    plt.xlabel("Urban (SARA) \n" + SOURCE_WT_FORMS + "\n" + size_followup(anc), size=8)
    sns.move_legend(g, "lower center", ncol=2, title="", frameon=True)
    plt.ylabel("Waiting time in minutes", fontsize=8)
    plt.ylim([15,140])
    format_graph()

    plt.subplot(1, 2, 2)
    g = sns.barplot(followup.query("treatment == 1"), x="complier",
                y="urban", color=TREATED,
                errwidth=0.5, capsize=0.1)
    plt.title("ANC: Percentage of patientes in complier facilities" ,fontsize=10)

    plt.xlabel("Urban (SARA) \n" + SOURCE_WT_FORMS , size=8)

    #sns.move_legend(g, "lower center", ncol=2, title="", frameon=True)
    plt.ylabel("Percentage of patientes", fontsize=8)
    format_graph()

    plt.savefig(f"{img}/anc_het_wt_urban.jpeg", bbox_inches='tight',dpi=300)

import forestplot as fp
import scipy.stats as st

def get_ci(n, mean, sem):
    return st.t.interval(alpha=0.95, df=n, loc=mean, scale=sem)#[1] - mean

def coef_plot(values, sem, n, title, xlabel, xticks=[0]):
    coef_wt = {}
    coef_wt["label"] = ["ITT-No Controls, No FE", "ITT-Only FE",
                        "ITT-Only Controls",
                        "ITT-Controls and FE",
                        "TOT-Controls and FE"]

    coef_wt["value"] = values

    coef_wt["lb"] = [get_ci(n, values[i], sem[i])[0] for i in range(5)]
    coef_wt["ub"] = [get_ci(n, values[i], sem[i])[1] for i in range(5)]

    coef_df = pd.DataFrame(coef_wt)


    ax = fp.forestplot(coef_df,  # the dataframe with results data
                  estimate="value",  # col containing estimated effect size 
                  ll="lb", hl="ub",  # lower & higher limits of conf. int.
                  varlabel="label",  # column containing the varlabels to be printed on far left
                  capitalize=None,  # Capitalize labels
                  ci_report=False,  # Turn off conf. int. reporting
                  flush=False,
                  #pval="pval",# Turn off left-flush of text
                  figsize=(3,2),
                  table=True,
                  xticks=xticks
                )
    plt.grid(False)
    plt.yticks(fontsize=8)
    plt.title(title,
              fontsize=10)
    plt.xlabel(xlabel,fontsize=8)
    return ax



def anc_share_consultations_10(anc):
    values = [.12, .13, .12, .13, .20]
    sem = [0.04, 0.04, 0.04, 0.04, 0.05]
    n=800
    title="Share of patients with consultations after 10am - followup"
    xlabel=SOURCE_WT_FORMS + "\n" + size_followup(anc)
    ax = coef_plot(values, sem, n, title, xlabel, xticks=[-0.1,0,0.1])
    plt.savefig(f"{img}/anc_consultation_after_10.jpeg", bbox_inches='tight',dpi=300)



def anc_share_arrival_10(anc):
    values = [.13, .14, .13, .13, .21]
    sem = [0.03, 0.04, 0.03, 0.03, 0.05]
    n=800
    title="Share of patients that arrived after 10am - followup"
    xlabel=SOURCE_WT_FORMS + "\n" + size_followup(anc)
    ax = coef_plot(values, sem, n, title, xlabel, xticks=[-0.1,0,0.1])
    plt.savefig(f"{img}/anc_after_10.jpeg", bbox_inches='tight',dpi=300)

def gen_complier_graphs():
    raise NotImplemented

# Configs
CONTROL = "#F95700FF"#"#ffc387"
TREATED = "#00A4CCFF"#"#9ed9c3"
palette_anc = [CONTROL, TREATED]
order=["control","treated"]

SOURCE_WT_FORMS = "Source: intervention forms"
SOURCE_REG = "Source: Facilities' registry book (Gov. of Mozambique)"

SIZE_REG_BOOK = "n = 3389(Control) 3109 (Treated)"

img = "graphs"

def gen_anc_graphs():
    root = "/Users/rafaelfrade/arquivos/desenv/lse"
    treat_control_full_path = f"{root}/adm_data/art_intervention/test/bases_auxiliares/treatment_hdd.dta"
    tc_df = load_tc_df(treat_control_full_path)

    cleaned_path = f"{root}/ocr/cleaned_data"
    anc_full_path = f"{cleaned_path}/anc_cpn_endline_v20230611.csv"
    #anc = load_anc_df(anc_full_path)
    anc = pd.read_csv(anc_full_path)

    path_reg_book = f"{root}/anc_rct/surveys/data_csv/Endline"
    reg_book_full_path = f"{path_reg_book}/anc_registry_book.csv"
    reg_book = load_registry_book(reg_book_full_path, tc_df)

    path_hiv = "/Users/rafaelfrade/arquivos/desenv/lse/ocr_hiv"
    hiv_endline = load_hiv_endline(f"{path_hiv}/hiv_endline_cleaned.csv")

    followup = anc.query("consultation_reason == 2")

    patient_volume()
    avg_consultations_per_patient(reg_book)
    anc_hiv_opening_hours(hiv_endline, anc)
    waiting_time_by_consultation_reason(anc)
    anc_het_wt_province(anc)
    anc_het_wt_vol(anc)
    anc_het_wt_urban(anc)
    #anc_share_consultations_10(anc)
    #anc_share_arrival_10(anc)
    anc_het_arrival_province(anc)

    gen_complier_graphs()
    print("Finished generating graphs!")



def __init__():
    gen_anc_graphs()

__init__()
