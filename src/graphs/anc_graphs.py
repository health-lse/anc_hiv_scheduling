import pandas as pd
import matplotlib.pyplot as plt 
import seaborn as sns
from graph_utils import plot_cathegorical, time_diff, format_graph
import numpy as np


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
    anc_full_path = f"{cleaned_path}/anc_cpn_endline_v20230413.csv"
    anc = load_anc_df(anc_full_path)

    path_reg_book = f"{root}/anc_rct/surveys/data_csv/Endline"
    reg_book_full_path = f"{path_reg_book}/anc_registry_book.csv"
    reg_book = load_registry_book(reg_book_full_path, tc_df)

    path_hiv = "/Users/rafaelfrade/arquivos/desenv/lse/ocr_hiv"
    hiv_endline = load_hiv_endline(f"{path_hiv}/hiv_endline_cleaned.csv")

    patient_volume()
    avg_consultations_per_patient(reg_book)
    anc_hiv_opening_hours(hiv_endline, anc)


def __init__():
    gen_anc_graphs()

__init__()