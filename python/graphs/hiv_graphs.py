
# GRAPHS
# MOZART:  days without medication
# MOZART:  delay next pickup
# MOZART:  delay > 7
# MOZART:  MPR
# MOZART:  LOSS TO FOLLOWUP

# The variable for the mozart raw data is called adm because
# Sandra usually refers to it as Admnistrative data

# IMPORTANT DATASET VARIABLES:
# month_order: months ordered with respect to treatment implementation
#               so, a patient who had a first pickup in the month before
#               intervention would have a month_order = -1 for that pickup
# pickup_oder: pickup number since first, not related to treatment implementation

import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np
# need to install scikit-learn
from sklearn.decomposition import PCA
import datetime as dt

def diff_month(d1, d2):
    diff = (d1.year - d2.year) * 12 + d1.month - d2.month - 1
    months = (d1 - d2).days // 30
    #months = months if months < 0 else months + 1
    return months

def diff_maputo(df):
    intervention_maputo = dt.datetime(2020, 10, 26)
    return diff_month(df, intervention_maputo)

def diff_gaza_inhambane(df):
    intervention_ig = dt.datetime(2020, 12, 7)
    return diff_month(df, intervention_ig)

# Tests
intervention_maputo = dt.datetime(2020, 10, 26)
intervention_ig = dt.datetime(2020, 12, 7)
assert diff_month(intervention_ig, intervention_maputo) == 1
assert diff_month(intervention_maputo, intervention_ig) == -2
assert diff_month(dt.datetime(2020, 10, 27), dt.datetime(2020, 10, 26)) == 0
assert diff_month(dt.datetime(2020, 10, 25), dt.datetime(2020, 10, 26)) == -1
assert diff_month(dt.datetime(2020, 10, 26), dt.datetime(2020, 10, 26)) == 0
assert diff_month(dt.datetime(2020, 11, 26), dt.datetime(2020, 10, 26)) == 1
assert diff_month(dt.datetime(2020, 11, 27), dt.datetime(2020, 10, 26)) == 1

def get_data_merge_pre_stata_filtered(mozart_path, path_treat):
    """
        cleans data_merge_pre_stata.csv,
        creates variables pickup_order and month_order that will be useful
        to establish new patients
    """
    adm = pd.read_csv(f"{mozart_path}/data_merge_pre_stata.csv", sep="\t")
    adm = adm.rename(columns={"hdd.x":"hdd",
                            "trv_date_pickup_drug":"pick_up"})
    adm["pick_up"] = pd.to_datetime(adm["pick_up"])
    adm = adm.query("pick_up > '2019-08-01'")

    new_label_maputo = {"province": {"MaputoCidade": "Maputo Cidade",
                                    "MaputoProvíncia": "Maputo Província"}}
    adm.replace(new_label_maputo , inplace = True)
    adm = adm[~adm.eval("trv_quantity_taken > 360")]
    adm = adm[adm.eval("trv_quantity_taken.notna()")]

    treat_df = pd.read_stata(f"{path_treat}/treatment_hdd.dta")
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

    return adm

def format_graph(g=None):
    plt.xticks(fontsize=8)
    plt.yticks(fontsize=8)
    if g:
        sns.move_legend(g, "lower center", ncol=2, title="", frameon=True)


def new_pat_days_without_med(panel_new, palette_anc, order,
                             source_new, img_path):
    plt.figure()
    g = sns.barplot(panel_new, x="period",
             y="days_without_med",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)
    #plt.title("Novos pacientes (30): média de dias sem medicação")
    plt.title("New patients: average days without medication")

    plt.ylabel("")
    #plt.xlabel("Mês após a intervenção \n" + source_new, fontsize=8)
    plt.xlabel("Month after treatment \n" + source_new, fontsize=8)

    format_graph(g)

    plt.savefig(f"{img_path}/adm_new_days_without.jpeg", bbox_inches='tight',dpi=300)

def new_pat_delay(panel_new, palette_anc, order,
                             source_new, img_path):
    plt.figure()
    g = sns.barplot(panel_new, x="period",
             y="delay_7",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)

    plt.ylabel("")
    plt.xlabel("Mês após a intervenção \n" + source_new, fontsize=8)
    plt.xlabel("Month after treatment \n" + source_new, fontsize=8)
    format_graph(g)

    plt.title("Novos pacientes: Média de dias de atraso")
    plt.title("New patients: Delay")

    plt.savefig(f"{img_path}/adm_new_delay.jpeg", bbox_inches='tight',dpi=300)
    


def new_patients_mpr(panel_new, palette_anc, order,
                             source_new, img_path):
    plt.figure()
    g = sns.barplot(panel_new, x="period",
             y="mpr",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("Novos pacientes: MPR")
    plt.title("New patients: MPR")
    plt.ylim([0.8,0.96])
    format_graph(g)
    plt.ylabel("")
    plt.xlabel("Mês após a intervenção \n" + source_new, fontsize=8)
    plt.xlabel("Month after treatment \n" + source_new, fontsize=8)

    plt.savefig(f"{img_path}/adm_new_mpr.jpeg", bbox_inches='tight',dpi=300)
    


def new_delay_7(panel_new, palette_anc, order,
                             source_new, img_path):
    """
        delay greater than 7 days
    """
    plt.figure()
    g = sns.barplot(panel_new, x="period",
             y="delay_7",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("Novos pacientes: Atraso > 7")
    plt.title("New patients: delay > 7")
    format_graph(g)
    plt.ylabel("")
    plt.xlabel("Mês após a intervenção \n" + source_new, fontsize=8)
    plt.xlabel("Month after treatment \n" + source_new, fontsize=8)

    plt.savefig(f"{img_path}/adm_new_delay_7.jpeg", bbox_inches='tight',dpi=300)
    


def old_patients_days_without_med(panel_old, palette_anc, order,
                             source_old, img_path):
    plt.figure()
    g = sns.barplot(panel_old, x="period",
             y="days_without_med",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("Pacientes antigos: dias sem medicação")
    plt.title("Old patients: days without medication")

    plt.xlabel("Períodos de 3 meses agrupados \n" + source_old, fontsize=8)
    plt.xlabel("3 month period\n" + source_old, fontsize=8)
    plt.ylabel("")

    format_graph(g)

    plt.savefig(f"{img_path}/adm_old_days_without.jpeg", bbox_inches='tight',dpi=300)
    


def old_patients_delay(panel_old, palette_anc, order,
                             source_old, img_path):
    plt.figure()
    g = sns.barplot(panel_old.query("days_without_med < 30"), x="period",
             y="days_without_med",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("Old patients: delay")
    plt.title("Pacientes antigos: Média de dias de atraso na pickup seguinte")
    plt.xlabel("3 month period\n" + source_old, fontsize=8)
    plt.xlabel("Períodos de 3 meses agrupados \n" + source_old, fontsize=8)

    plt.ylabel("")

    format_graph(g)
    plt.ylim([1,3.5])

    plt.savefig(f"{img_path}/adm_old_delay.jpeg", bbox_inches='tight',dpi=300)


def old_patients_mpr(panel_old, palette_anc, order,
                             source_old, img_path):
    plt.figure()
    g = sns.barplot(panel_old.query("days_without_med < 30"), x="period",
             y="mpr",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc, 
             hue_order=order,errwidth=0.5, capsize=0.1)
    plt.xlabel("3 month period\n" + source_old, fontsize=8)
    plt.xlabel("Períodos de 3 meses agrupados \n" + source_old, fontsize=8)

    plt.ylabel("")

    format_graph(g)
    plt.title("Old patients: MPR (excluding dropouts)")
    plt.title("Pacientes antigos: MPR")

    plt.ylim([0.9,1])

    plt.savefig(f"{img_path}/adm_old_mpr.jpeg", bbox_inches='tight',dpi=300)
    


def old_pat_delay_7(panel_old, palette_anc, order,
                             source_old, img_path):
    plt.figure()
    panel_old.loc[panel_old["days_without_med"].notnull(),"delay_7"] = 0
    filter_7_29 = panel_old["days_without_med"].between(8,29,inclusive="both")
    panel_old.loc[filter_7_29, "delay_7"] = 1

    g = sns.barplot(panel_old, x="period",
             y="delay_7",
             hue="treatment_status", errorbar=("ci",95),
             palette=palette_anc,
             hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("Old patients: delay > 7 (excluding dropouts)")
    plt.title("Pacientes antigos: Atraso > 7")
    plt.xlabel("3 month period\n" + source_old, fontsize=8)
    plt.xlabel("Períodos de 3 meses agrupados \n" + source_old, fontsize=8)

    plt.ylabel("")
    format_graph(g)
    plt.ylabel("")

    plt.savefig(f"{img_path}/adm_old_days_7.jpeg", bbox_inches='tight',dpi=300)


def new_patients_by_month(adm, palette_anc, order,
                             source_old, img_path):
    plt.figure()
    new_by_month = adm.query("pickup_order_from_first == 1")
    count_new = (new_by_month.groupby(["treatment_status","month_order"])
        .size()
        .reset_index()
        .rename(columns={0:"n_pickups"})
        .query("month_order.between(-8,8)"))

    g = sns.lineplot(count_new,
                x="month_order",y="n_pickups",
                hue="treatment_status",
                palette=palette_anc,
                hue_order=order)

    plt.xlabel("Mês \n" + source_old, fontsize=8)
    plt.ylabel("")
    format_graph(g)
    plt.ylabel("")
    plt.title("Novos pacientes por mês")
    plt.title("New patients by month")
    plt.ylim([0, 3000])

    plt.savefig(f"{img_path}/adm_new_by_month.jpeg", bbox_inches='tight',dpi=300)


def new_pat_loss_to_followup(adm, palette_anc, order,
                             source_new, img_path):
    """
        Graph of patients who give up. We were not able 
        to have a consensus of who were the patients who give up.
        Here I plot for every month the number of patients who
        didn't show up again.
    """
    plt.figure()
    new_last = adm.query("new_patient == 1")

    new_last.loc[:, "remaining_pickups"] = (new_last.sort_values("pick_up")
        .groupby("nid")["pick_up"]
    .rank(ascending=False).add(-1))

    new_last["last_pickup"] = 0
    new_last.loc[new_last["remaining_pickups"] == 0, "last_pickup"] = 1

    g = sns.barplot(new_last.query("month_order.between(1,5)"),
                x="month_order", y="last_pickup",
                hue="treatment_status",
                palette=palette_anc,
                hue_order=order,errwidth=0.5, capsize=0.1)
    plt.title("Novos pacientes: perda de seguimento")
    plt.title("New patients: loss to follow up")
    plt.xlabel("Mês \n" + source_new, fontsize=8)
    plt.xlabel("Month \n" + source_new, fontsize=8)
    plt.ylabel("")
    format_graph(g)
    plt.ylabel("")

    plt.savefig(f"{img_path}/adm_new_loss.jpeg", bbox_inches='tight',dpi=300)


def old_patients_loss_to_followup(adm, palette_anc, order,
                             source_new, img_path):
    """
        Graph of patients who give up. We were not able 
        to have a consensus of who were the patients who give up.
        Here I plot for every month the number of patients who
        didn't show up again.
    """
    plt.figure()
    old_last = adm.query("new_patient == 0")

    old_last.loc[:, "remaining_pickups"] = (old_last.sort_values("pick_up")
        .groupby("nid")["pick_up"]
    .rank(ascending=False))

    old_last["last_pickup"] = 0
    old_last.loc[old_last["remaining_pickups"] == 1, "last_pickup"] = 1

    sns.barplot(old_last.query("(-10 <= month_order <= 10)"),
                x="month_order", y="last_pickup",
                hue="treatment")
    plt.title("Old patients: loss to follow up")
    plt.title("Pacientes antigos: loss to follow up")

    plt.savefig(f"{img_path}/adm_old_loss.jpeg", bbox_inches='tight',dpi=300)

def get_new_patients_last_pickup(adm):
    """
        Return a dataset with the last pickup of the new patients.
        Used to identify the loss-to-followup (those who give up)
    """
    new_last = adm.query("new_patient == 1")

    new_last.loc[:, "remaining_pickups"] = (new_last.sort_values("pick_up")
        .groupby("nid")["pick_up"]
    .rank(ascending=False).add(-1))

    new_last["last_pickup"] = 0
    new_last.loc[new_last["remaining_pickups"] == 0, "last_pickup"] = 1
    new_last = new_last.set_index("nid")
    new_last["loss"] = 0
    query_loss_tfu = "remaining_pickups == 0 & month_order <= 4"

    index_loss = new_last.query(query_loss_tfu).index
    new_last.loc[index_loss,"loss"] = 1
    new_last = new_last.reset_index()
    return new_last

def loss_to_followup_5_months(adm, palette_anc, order, img_path):
    """
        Patients who started after the intervention and had given up
        after 5 months.
    """
    plt.figure()
    new_last = get_new_patients_last_pickup(adm)
    new_patients_4months= new_last.query("month_order <= 4").groupby("nid").first()
    sns.barplot(new_patients_4months,
                x="treatment_status", y="loss",
                palette=palette_anc, order=order,errwidth=0.5, capsize=0.1)
    plt.title("Abandono de tratamento nos primeiros 5 meses após a intervenção")
    plt.title("Loss-to-followup (First 5 months)")
    xlabel = "Iniciaram o tratamento no período: 8109(Tratamento), 6680(Controlo) \n"+"Fonte:Mozart"
    xlabel = "Number of patients that started in the period: 8109(T), 6680(C) \n"+"Source:Mozart"

    plt.xlabel(xlabel,
            fontsize=8)
    plt.ylabel("Percentual de abondono de tratamento", fontsize=8)
    plt.ylabel("Percentage of loss-to-followup", fontsize=8)
    plt.yticks(fontsize=8)
    plt.savefig(f"{img_path}/adm_loss_5_months", bbox_inches='tight', dpi=300)
    


def column_by_quantile(df, col, n_quantiles,n_round=2,format_int=True):
    """
        Divide the column in quantiles and generate a label
    """
    plt.figure()
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


def print_mozart_graphs(adm, panel_new_all, panel_new_30, panel_old, 
                        img_path):
    """
        Generate graphs and save them to graphs folder
    """
    n_new=len(panel_new_all["nid"].unique())
    source_new = f"Fonte: Mozart, (n={n_new} pacientes)"
    source_new = f"Source: Mozart, (n={n_new} patients)"

    n_old=len(panel_old["nid"].unique())
    source_old = f"Fonte: Mozart, (n={n_old} pacientes)"
    source_old = f"Source: Mozart, (n={n_old} patients)"

    # color settings
    CONTROL = "#F95700FF"#"#ffc387"
    TREATED = "#00A4CCFF"#"#9ed9c3"
    palette_anc = [CONTROL, TREATED]
    order=["controlo","tratamento"]
    order=["control","treatment"]

    ## IMPORTANT: decide if you want to generate the graphs
    ## for all new patients or only those in a 30-day regimen.
    ## We had decided to focus only on 30 initially, but I thougt
    ## it would make sense to include them all because in the
    ## panel format they are comparable

    ## I included the code for delay 7 days, but it should be
    ## very close to delay.

    new_pat_days_without_med(panel_new_all, palette_anc, order,
                             source_new, img_path)
    new_pat_delay(panel_new_all, palette_anc, order,
                             source_new, img_path)
    new_patients_mpr(panel_new_all, palette_anc, order,
                             source_new, img_path)
    #new_delay_7(panel_new_30, palette_anc, order,
    #                         source_new, img_path)
    old_patients_days_without_med(panel_old, palette_anc, order,
                             source_old, img_path)
    old_patients_delay(panel_old, palette_anc, order,
                             source_old, img_path)
    old_patients_mpr(panel_old, palette_anc, order,
                             source_old, img_path)
    #old_pat_delay_7(panel_old, palette_anc, order,
    #                         source_old, img_path)
    new_pat_loss_to_followup(adm, palette_anc, order,
                             source_new, img_path)
    new_pat_loss_to_followup(adm, palette_anc, order,
                             source_new, img_path)
    old_patients_loss_to_followup(adm, palette_anc, order,
                             source_new, img_path)
    loss_to_followup_5_months(adm, palette_anc, order, img_path)


def plt_het_quality(panel_new, new_patients_het, 
                    labels_pca, SOURCE_NEW_5_MONTHS, img_path):
    plt.figure(figsize=(6, 3))
    plt.subplot(1, 2, 1)

    g = plot_het_graph(panel_new,x="pca_groups",
                y="delay_7",labels=labels_pca)
    plt.xlabel("Índice de preparo/infraestrutura da US \n" + SOURCE_NEW_5_MONTHS + " / SARA",
            fontsize=8)
    plt.xlabel("Facility readiness index \n" + SOURCE_NEW_5_MONTHS + " / SARA",
            fontsize=8)
    plt.ylabel("% de levantamentos", fontsize=8)
    plt.title("Atraso de 7 dias ou mais")
    plt.title("Delay (> 7)")
    plt.ylim([0,0.2])
    sns.move_legend(g,loc='lower center', ncol=2, title="", frameon=False,
                bbox_to_anchor=(1, -.4))

    plt.subplot(1, 2, 2)
    plot_het_graph(new_patients_het,x="pca_groups",
                y="loss",labels=labels_pca)
    plt.ylabel("% de pacientes", fontsize=8)
    plt.title("Abandono do tratamento \n nos 5 primeiros meses")
    plt.title("Loss to follow-up(5 months)")
    plt.legend([],[], frameon=False)
    plt.ylim([0,0.2])
    plt.xlabel("Índice de preparo/infraestrutura da US \n" + SOURCE_NEW_5_MONTHS + " / SARA",
            fontsize=8)
    plt.xlabel("Facility readiness index \n" + SOURCE_NEW_5_MONTHS + " / SARA",
            fontsize=8)

    plt.subplots_adjust(wspace=0.3)
    plt.savefig(f"{img_path}/het_hiv_infra", bbox_inches='tight',dpi=300)


def plt_het_age(panel_new, adm, new_patients_het, 
                SOURCE_NEW_5_MONTHS, img_path):
    outcome_cols=["delay_7","days_without_med","mpr"]

    means_new = (panel_new.dropna(subset=["days_without_med"])
        .groupby("nid")[outcome_cols].mean()
        .reset_index())

    new_het = (adm.query("new_patient == 1")
        [["nid","pac_sex","pac_age","treatment_status"]]
            .drop_duplicates())
    means_new = means_new.merge(new_het, left_on="nid", 
                                right_on="nid",how="left")

    age_group,label_age = column_by_quantile(means_new,"pac_age",4,1)
    means_new["age_group"] = age_group

    plt.figure(figsize=(6, 3))
    plt.subplot(1, 2, 1)

    g = plot_het_graph(means_new,x="age_group",
                y="delay_7",labels=label_age)
    plt.xlabel("Faixa etária \n" + SOURCE_NEW_5_MONTHS, fontsize=8)
    plt.ylabel("% de levantamentos", fontsize=8)
    plt.title("Atraso de 7 dias ou mais")
    plt.title("Delay (> 7)")
    sns.move_legend(g,loc='lower center', ncol=2, title="", frameon=False,
                bbox_to_anchor=(1, -.4))
    plt.ylim([0,0.22])

    plt.subplot(1, 2, 2)
    age_group,label_age = column_by_quantile(means_new,"pac_age",4,1)
    new_patients_het["age_group"] = age_group

    plot_het_graph(new_patients_het,x="age_group",
                y="loss",labels=label_age)
    plt.xlabel("Faixa etária \n" + SOURCE_NEW_5_MONTHS, fontsize=8)
    plt.ylabel("% de levantamentos", fontsize=8)
    plt.title("Abandono do tratamento \n nos 5 primeiros meses")
    plt.title("Loss to follow-up(5 months)")

    plt.legend([],[], frameon=False)
    plt.ylabel("% de pacientes",fontsize=8)
    plt.ylim([0,0.22])
    plt.subplots_adjust(wspace=0.3)
    plt.savefig(f"{img_path}/het_hiv_age", bbox_inches='tight',dpi=300)


def plt_het_volume(panel_new, new_patients_het, 
                SOURCE_NEW_5_MONTHS, labels_vol, 
                labels_vol_pat, img_path):
    plt.figure(figsize=(6, 3))
    plt.subplot(1, 2, 1)
    g = plot_het_graph(panel_new,x="vol_groups",
                y="delay_7",labels=labels_vol)

    plt.xlabel("Pacientes por dia - baseline \n" + SOURCE_NEW_5_MONTHS,
            fontsize=8)
    plt.xlabel("Patients by day - baseline \n" + SOURCE_NEW_5_MONTHS,
            fontsize=8)
    plt.ylabel("% of pickups", fontsize=8)
    plt.title("Atraso acima de 7 dias")
    plt.title("Delay (> 7)")
    sns.move_legend(g,loc='lower center', ncol=2, title="", frameon=False,
                bbox_to_anchor=(1, -.4))
    plt.ylim([0,0.25])

    plt.subplot(1, 2, 2)
    g = plot_het_graph(new_patients_het, x="vol_groups",
                y="loss",labels=labels_vol_pat)
    plt.legend([],[], frameon=False)
    plt.ylim([0,0.25])

    plt.xlabel("Pacientes por dia - baseline \n" + SOURCE_NEW_5_MONTHS,
            fontsize=8)
    plt.xlabel("Patients by day - baseline \n" + SOURCE_NEW_5_MONTHS,
            fontsize=8)
    plt.title("Abandono do tratamento \n nos 5 primeiros meses")
    plt.title("Loss to follow-up(5 months)")
    plt.ylabel("% of pickups", fontsize=8)
    plt.subplots_adjust(wspace=0.3)

    plt.savefig(f"{img_path}/het_hiv_vol", bbox_inches='tight',dpi=300)
    plt.show()


def heterogeneity_graphs(path_aux, adm, panel_new_all, img_path):
    """
        Separates the data in quantiles by var (quality, age and volume)
        and plot the graphs based on these quantiles
    """

    # new patients who started in the first 5 months
    SOURCE_NEW_5_MONTHS = "Fonte: Mozart (15855 pacientes)"

    facility_info = pd.read_stata(f"{path_aux}/facility_characteristics.dta")

    #### PCA Quality
    pca = PCA(n_components=1)
    cols_pca = ["score_basic_amenities",
                #"score_basic_equipment",
                "index_general_service",
                "index_hiv_care_readiness"]
    pca.fit(facility_info.query("facility_cod != 36")[cols_pca])
    not_36 = facility_info.eval("facility_cod != 36")
    facility_info.loc[not_36, "pca_quality"] = pca.transform(facility_info[not_36][cols_pca])

    #### VOLUME
    facility_info["pat_per_day"] = (adm
                                    .query("(-3 <= month_order <= 1)")
                                    .groupby("facility_cod")
                                    .size()
                                    .div(90)
                                    .round()
                                    .reset_index()[0])

    panel_new = panel_new_all.merge(facility_info, on="facility_cod",
                    suffixes=('', '_y'))
    panel_new["vol_groups"],labels_vol = column_by_quantile(panel_new,
                                                            "pat_per_day",
                                                            4,0)

    ### QUALITY/INFRA PCA
    not_36 = panel_new.eval("facility_cod != 36")
    pca_groups,labels_pca = column_by_quantile(panel_new[not_36],
                                                            "pca_quality",
                                                            3,2, format_int=False)
    panel_new.loc[not_36,"pca_groups"] = pca_groups
    new_label_quality = {"pca_groups": {labels_pca[0]: "Low",
                                labels_pca[1]: "Medium",
                                labels_pca[2]: "High"}}
    labels_pca = {"Low","Medium","High"}
    panel_new.replace(new_label_quality , inplace = True)

    ### DATA BY PATIENT
    new_last = get_new_patients_last_pickup(adm)
    new_patients = new_last.query("month_order <= 4").groupby("nid").first()
    new_patients = new_patients.drop("pat_per_day",axis=1,
                                    errors='ignore')

    new_patients_het = new_patients.merge(facility_info[["facility_cod",
                                                        "pat_per_day",
                                                        "pca_quality"]],
                                        on="facility_cod",how="left")
    new_patients_het["vol_groups"],labels_vol_pat = column_by_quantile(new_patients_het,
                                                            "pat_per_day",
                                                            4,0)

    not_36 = new_patients_het.eval("facility_cod != 36")
    pca_groups_het,labels_pca_pat = column_by_quantile(new_patients_het[not_36],
                                                            "pca_quality",
                                                            3,2,format_int=False)
    new_patients_het.loc[not_36,"pca_groups"]=pca_groups_het
    new_patients_het.replace(new_label_quality, inplace = True)

    plt_het_quality(panel_new, new_patients_het, 
                    labels_pca, SOURCE_NEW_5_MONTHS, img_path)
    plt_het_volume(panel_new, new_patients_het, 
                SOURCE_NEW_5_MONTHS, labels_vol, 
                labels_vol_pat, img_path)
    # has error to calculate the subgroups
    #plt_het_age(panel_new, adm, new_patients_het, 
    #            SOURCE_NEW_5_MONTHS, img_path)


def plot_het_graph(df,x,y,labels):
    """
        helper function to plot graphs with heterogeneity
    """
    CONTROL = "#F95700FF"#"#ffc387"
    TREATED = "#00A4CCFF"#"#9ed9c3"
    palette_anc = [CONTROL, TREATED]
    order=["controlo","tratamento"]
    order=["control","treatment"]

    g = sns.barplot(df, x=x,
            y=y, hue="treatment_status",
            order=labels,errorbar=("ci",95),
            palette=palette_anc,
            hue_order=order,errwidth=0.5, capsize=0.1)
    format_graph(g)
    return g

def __init__():
    data_path = "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling"
    mozart_path = f"{data_path}/data/cleaned_data/mozart"
    updated_data = f"{data_path}/data/cleaned_data"
    path_aux = f"{data_path}/data/aux"
    img_path = f"{data_path}/graphs/mozart"
    print("cleaning data_merge_pre_stata : mozart data")
    adm = get_data_merge_pre_stata_filtered(mozart_path, path_aux)
    
    #panel_old = pd.read_stata(f"{mozart_path}/panel_old.dta")
    #panel_new_all = pd.read_stata(f"{mozart_path}/panel_new_all.dta")
    #panel_new_30 = pd.read_stata(f"{mozart_path}/panel_new_30.dta")

    panel_old = pd.read_stata(f"{updated_data}/panel_old_updated.dta")
    panel_new_all = pd.read_stata(f"{updated_data}/panel_new_all_updated.dta")
    panel_new_30 = pd.read_stata(f"{updated_data}/panel_new_30_updated.dta")

    for df in [panel_new_30, panel_new_all, panel_old, adm]:# panel_old
        df["treatment_status"] = "treatment"
        df.loc[df["treatment"] == 0, "treatment_status"] = "control"

    print_mozart_graphs(adm, panel_new_all, panel_new_30, panel_old, 
                        img_path)
    heterogeneity_graphs(path_aux, adm, panel_new_all, img_path)

__init__()