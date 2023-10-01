"""
    HIV ENDLINE CLEANING SCRIPTS

    Textract returns json files with the content
    of the images. This script reads the json
    files and return the content.

    Important: the column with identification
    was blanked during the scaning process. As
    a result, textract identifies the images
    as containing 1 table, sometimes as 2 tables.
    The function

     Legend: 
     [QUESTION]     there is a about about that line of code
     [ISSUE]        issue to be solved
     [ADDED]        part added by Vincenzo, might need adjusting (?)
"""

from hiv_clean_utils import *
import pandas as pd
import numpy as np
import json

# package to read aws json files
from trp import Document
from os import listdir

#DATA_FOLDER = "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling/data"
DATA_FOLDER = "/Users/vincenzoalfano/LSE - Health/anc_hiv_scheduling/data"
AWS_RESPONSE_FOLDER=f"{DATA_FOLDER}/hiv/endline/aws_response"

def append_line_dict_response(dict_response, file, facility, day, page, line, 
                              row, two_tables):
    """
        function that adds one line to the dictionary
        that will be transformed into the dataframe
    """
    dict_response["file_name"].append(file)
    dict_response["facility"].append(facility)
    dict_response["day"].append(day)
    dict_response["page"].append(page)
    dict_response["line"].append(line)
    # two_tables = flag indicating if two tables
    # were dectected
    dict_response["two_tables"].append(two_tables)
    dict_response["col_0"].append(row.cells[0].text)
    dict_response["col_1"].append(row.cells[1].text)
    dict_response["col_2"].append(row.cells[2].text)
    dict_response["col_3"].append(row.cells[3].text)
    dict_response["col_4"].append(row.cells[4].text)

    if two_tables == 0 and len(row.cells) > 5:
        dict_response["col_5"].append(row.cells[5].text)
        dict_response["col_6"].append(row.cells[6].text)
        dict_response["col_7"].append(row.cells[7].text)
        dict_response["col_8"].append(row.cells[8].text)
        dict_response["col_9"].append(row.cells[9].text) # [ADDED]

    else:
 #       dict_response["col_5"].append("") 
        dict_response["col_5"].append(row.cells[5].text) # [ADDED] if col0 and 1 are empty, scheduled time will be in col5 so we need the data
        dict_response["col_6"].append("")
        dict_response["col_7"].append("")
        dict_response["col_8"].append("")
        dict_response["col_9"].append("") # [ADDED]


def process_tables():
    """
        read the aws json files and return a dataframe
        with column names like:
        column_1, column_2, column_3 ...
        because it is not possible to know
        to what these columns refer to without
        analysing their content
    """
    responses_sample = [f for f in listdir(AWS_RESPONSE_FOLDER) if "txt" in f]
    responses_sample.sort()
    dict_response = {"file_name":[],
                     "facility":[], "day": [], "page":[], "line":[],
                     "col_0":[], "col_1":[], "col_2":[],
                     "col_3":[], "col_4":[], "col_5":[],
                     "col_6":[], "col_7":[], "col_8":[],
                     "col_9":[], "two_tables":[]} # [ADDED] col9

    list_no_tables = []
    list_first_half = []
    list_2_tables = []
    dict_table_lengths = {"length":[], "file":[]}

    #empty files
    files_to_skip = ["endline_US31_day10_page8.txt",
                     "endline_US31_day10_page6.txt",
                     "endline_US31_day10_page7.txt"] 
    
    #files to skip for scheduled time (all the ones for control clinics) [ADDED]
    control_facilities = [1,3,5,7,9,13,15,17,19,21,23,25,29,31,33,35,37,39,43,45,47,49,51,53,55,57,59,61,63,65,67,69,71,73,75,77,79,80,81,83]
    for file in responses_sample:
        if int(file[10:(10+(file[10:].find("_")))]) in control_facilities:
            files_to_skip = files_to_skip + [file]

    for file in responses_sample:
        if file in files_to_skip:
            continue
        f = open(f"{AWS_RESPONSE_FOLDER}/{file}", "r")
        response_string = f.read()
        response_json = json.loads(response_string)
        doc = Document(response_json)
        doc_page = doc.pages[0]

        if len(doc_page.tables) == 0:
            continue
            list_no_tables.append(file)

        tables = doc_page.tables
        table = tables[0]
        two_tables = 0
        if len(tables) > 1:
            two_tables = 1
            tables = doc_page.tables
            size_table_0 = len(tables[0].rows[0].cells)
            size_table_1 = len(tables[1].rows[0].cells)
            # the table that contains time info is the table with more cells
            if size_table_1 > size_table_0:
                table = tables[1]

        if len(table.rows[0].cells) <= 4:
            print("only the first half: " + file)
            list_first_half.append(file)
            continue

        #append_coordinates(dict_lengths, file, facility, day, page, table.rows[0], i+1)
        facility, day, page = get_facility_day_page(file)

        for i, row in enumerate(table.rows):
            if page == 3 and i == 0:
                #skip first line of page 3 because it is the header
                continue
            append_line_dict_response(dict_response, file, facility, day, page, i+1, 
                                      row, two_tables)
    
    hiv_end_df = pd.DataFrame(dict_response)
    return hiv_end_df


def flag_empty_lines(hiv_end_df):
    """
        the last lines of a day are empty, this
        function flags them
    """
    df_1_table = hiv_end_df.query("two_tables == 0")
    df_1_table["col_4"] = df_1_table["col_4"].str.replace(":", "").replace(" ", "")
    df_1_table["col_5"] = df_1_table["col_5"].str.replace(":", "").replace(" ", "")
    df_1_table["col_6"] = df_1_table["col_6"].str.replace(":", "").replace(" ", "")
    df_1_table["col_7"] = df_1_table["col_7"].str.replace(":", "").replace(" ", "")
    df_1_table["col_8"] = df_1_table["col_8"].str.replace(":", "").replace(" ", "") # [ADDED]
    df_1_table["col_9"] = df_1_table["col_9"].str.replace(":", "").replace(" ", "")
    index_empty_456 =  df_1_table.eval(" (col_4 == '' & col_5 == '' & col_6 == '') ")
    index_empty_567 =  df_1_table.eval(" (col_5 == '' & col_6 == '' & col_7 == '') ")
    index_empty_678 =  df_1_table.eval(" (col_6 == '' & col_7 == '' & col_8 == '') ")
    index_empty_9 =  df_1_table.eval(" (col_9 == '') ") # [ADDED]

    df_1_table.loc[:,"empty"] = 0
    df_1_table.loc[index_empty_456, "empty"] = 1
    df_1_table.loc[index_empty_567, "empty"] = 1
    df_1_table.loc[index_empty_678, "empty"] = 1
    df_1_table.loc[index_empty_9, "empty"] = 1 # [ADDED]

    # 2 TABLES
    df_2_tables = hiv_end_df.query("two_tables == 1")
    df_2_tables["col_0"] = df_2_tables["col_0"].str.replace(":", "").replace(" ", "")
    df_2_tables["col_1"] = df_2_tables["col_1"].str.replace(":", "").replace(" ", "")
    df_2_tables["col_2"] = df_2_tables["col_2"].str.replace(":", "").replace(" ", "")
    df_2_tables["col_3"] = df_2_tables["col_3"].str.replace(":", "").replace(" ", "")
    df_2_tables["col_4"] = df_2_tables["col_4"].str.replace(":", "").replace(" ", "") # [ADDED]
    df_2_tables["col_5"] = df_2_tables["col_5"].str.replace(":", "").replace(" ", "")

    index_empty_012 =  df_2_tables.eval(" (col_0 == '' & col_1 == '' & col_2 == '') ")
    index_empty_123 =  df_2_tables.eval(" (col_1 == '' & col_2 == '' & col_3 == '') ")
    index_empty_234 =  df_2_tables.eval(" (col_2 == '' & col_3 == '' & col_4 == '') ")
    index_empty_5 =  df_2_tables.eval(" (col_5 == '') ") # [ADDED]

    df_2_tables.loc[:,"empty"] = 0
    df_2_tables.loc[index_empty_012, "empty"] = 1
    df_2_tables.loc[index_empty_123, "empty"] = 1
    df_2_tables.loc[index_empty_234, "empty"] = 1
    df_2_tables.loc[index_empty_5, "empty"] = 1

    return df_1_table, df_2_tables


def find_times_df_1_table(response_df):
    """
        AWS returns the time information in different columns,
        So the arrival time can be at columns 4, 5 or 6, this
        function tries to identify the right column
    """
    response_df["col_4_clean"] = remove_special_characters(response_df["col_4"])
    response_df["col_5_clean"] = remove_special_characters(response_df["col_5"])
    response_df["col_6_clean"] = remove_special_characters(response_df["col_6"])
    response_df["col_7_clean"] = remove_special_characters(response_df["col_7"])
    response_df["col_8_clean"] = remove_special_characters(response_df["col_8"]) # [ADDED]
    response_df["col_9_clean"] = remove_special_characters(response_df["col_9"]) # [ADDED]

    response_df.loc[(response_df["col_4"] != ""),
                    "arrival_time"] = response_df["col_4_clean"]
    response_df.loc[response_df["col_4"] != "",
                    "consultation_time"] = response_df["col_5_clean"]
    response_df.loc[response_df["col_4"] != "",
                    "scheduled_time"] = response_df["col_7_clean"] # [ADDED]

    response_df.loc[(response_df["col_4_clean"] == "") &
                    (response_df["col_5_clean"] != ""),
                        "arrival_time"] = response_df["col_5_clean"]
    response_df.loc[(response_df["col_4_clean"] == "") &
                    (response_df["col_5_clean"] != ""),
                        "consultation_time"] = response_df["col_6_clean"]
    response_df.loc[(response_df["col_4_clean"] == "") &
                    (response_df["col_5_clean"] != ""),
                        "scheduled_time"] = response_df["col_8_clean"] # [ADDED]

    # [QUESTION] the following code does not do much: if both col4 and col5 are empty then almost always there is no info on the time. For sure, scheduled_time would end up being column_9 which does not exist. Needs fixing? added col_9, still needs to be fixed in a better way
    response_df.loc[ (response_df["col_4_clean"] == "") & 
                     (response_df["col_5_clean"] == "") & \
                     (response_df["col_6_clean"] != ""), \
                             "arrival_time"] = response_df["col_6_clean"]
    response_df.loc[ (response_df["col_4_clean"] == "") & 
                     (response_df["col_5_clean"] == "") & \
                     (response_df["col_6_clean"] != ""), \
                             "consultation_time"] = response_df["col_7_clean"]
    response_df.loc[ (response_df["col_4_clean"] == "") & 
                     (response_df["col_5_clean"] == "") & \
                     (response_df["col_6_clean"] != ""), \
                             "scheduled_time"] = response_df["col_9_clean"] # [ADDED]
    
    response_df.loc[ (response_df["col_4_clean"].str.contains("SELECTED")) & 
                     (response_df["col_5_clean"] != ""),
                                            "arrival_time"] = response_df["col_5_clean"]
    response_df.loc[ (response_df["col_4_clean"].str.contains("SELECTED")) & 
                     (response_df["col_5_clean"] != ""),
                                        "consultation_time"] = response_df["col_6_clean"]
    response_df.loc[ (response_df["col_4_clean"].str.contains("SELECTED")) & 
                     (response_df["col_5_clean"] != ""),
                                        "scheduled_time"] = response_df["col_8_clean"] # [ADDED]
    
    response_df.loc[ (response_df["col_4_clean"].str.contains("SELECTED")) & 
                     (response_df["col_5_clean"] == ""),
                                            "arrival_time"] = response_df["col_6_clean"]

    response_df.loc[ (response_df["col_4_clean"].str.contains("SELECTED")) & 
                     (response_df["col_5_clean"] == ""),
                                        "consultation_time"] = response_df["col_7_clean"]
    response_df.loc[ (response_df["col_4_clean"].str.contains("SELECTED")) & 
                     (response_df["col_5_clean"] == ""),
                                        "scheduled_time"] = response_df["col_9_clean"] # [ADDED]
    
    return response_df

# 2 TABLES
def find_times_df_2_tables(response_df):
    """
        AWS returns the time information in different columns,
        So the arrival time can be at columns 0, 1 or 2, this
        function tries to identify the right column
    """
    response_df["col_0_clean"] = remove_special_characters(response_df["col_0"])
    response_df["col_1_clean"] = remove_special_characters(response_df["col_1"])
    response_df["col_2_clean"] = remove_special_characters(response_df["col_2"])
    response_df["col_3_clean"] = remove_special_characters(response_df["col_3"])
    response_df["col_4_clean"] = remove_special_characters(response_df["col_4"]) # [ADDED] 
    response_df["col_5_clean"] = remove_special_characters(response_df["col_5"])

    response_df.loc[response_df["col_0_clean"] != "", "arrival_time"] = response_df["col_0_clean"]
    response_df.loc[response_df["col_0_clean"] != "","consultation_time"] = response_df["col_1_clean"] # modified, it was col_1 instead of col_1_clean
    response_df.loc[response_df["col_0_clean"] != "","scheduled_time"] = response_df["col_3_clean"] # [ADDED]

    response_df.loc[(response_df["col_0_clean"] == "") &
                    (response_df["col_1_clean"] != ""), "arrival_time"] = response_df["col_1_clean"]
    response_df.loc[(response_df["col_0_clean"] == "") &
                    (response_df["col_1_clean"] != ""),"consultation_time"] = response_df["col_2_clean"]
    response_df.loc[(response_df["col_0_clean"] == "") &
                    (response_df["col_1_clean"] != ""),"scheduled_time"] = response_df["col_4_clean"] # [ADDED]

    response_df.loc[(response_df["col_0_clean"] == "") & 
                    (response_df["col_1_clean"] == "") & \
                    (response_df["col_2_clean"] != ""), \
                             "arrival_time"] = response_df["col_2_clean"]
    response_df.loc[ (response_df["col_0_clean"] == "") & 
                     (response_df["col_1_clean"] == "") & \
                     (response_df["col_2_clean"] != ""), \
                             "consultation_time"] = response_df["col_3_clean"]
    response_df.loc[ (response_df["col_0_clean"] == "") & 
                     (response_df["col_1_clean"] == "") & \
                     (response_df["col_2_clean"] != ""), \
                             "scheduled_time"] = response_df["col_5_clean"]
    return response_df


def flag_incorrect_obs(response_df):
    """
        Flag itens with errors to be reviewed later
    """
    response_df.loc[pd.isnull(response_df["consultation_time"]), "flag"] = 1
    response_df.loc[pd.isnull(response_df["arrival_time"]), "flag"] = 1
    response_df.loc[pd.isnull(response_df["scheduled_time"]), "flag"] = 1

    response_df["arrival_time_cleaned"] = remove_special_characters(
                                            response_df["arrival_time"])

    response_df["consultation_time_cleaned"] = remove_special_characters(
                                            response_df["consultation_time"])
    
    response_df["scheduled_time_cleaned"] = remove_special_characters(
                                            response_df["scheduled_time"])

    response_df.loc[response_df["arrival_time_cleaned"]=="", "flag"] = 1
    response_df.loc[response_df["consultation_time_cleaned"]=="", "flag"] = 1
    response_df.loc[response_df["scheduled_time_cleaned"]=="", "flag"] = 1

    response_df["arrival_time_cleaned"] = response_df["arrival_time_cleaned"].apply(clean_time_with_h)
    response_df["consultation_time_cleaned"] = response_df["consultation_time_cleaned"].apply(clean_time_with_h)
    response_df["scheduled_time_cleaned"] = response_df["scheduled_time_cleaned"].apply(clean_time_with_h)

    response_df['arrival_time_numeric'] = pd.to_numeric(
                                            response_df['arrival_time_cleaned'],
                                            errors='coerce')

    response_df.loc[~response_df['arrival_time_numeric'].notnull(), "flag"] = 1

    response_df['consultation_time_numeric'] = pd.to_numeric(
                                            response_df['consultation_time_cleaned'],
                                            errors='coerce')
    response_df.loc[~response_df['consultation_time_numeric'].notnull(), "flag"] = 1

    response_df['scheduled_time_numeric'] = pd.to_numeric(
                                            response_df['scheduled_time_cleaned'],
                                            errors='coerce')
    response_df.loc[~response_df['scheduled_time_numeric'].notnull(), "flag"] = 1

    filter_arrival_time = ((response_df["arrival_time_numeric"] < 500) | 
                           (response_df["arrival_time_numeric"] >= 1530))
    response_df.loc[filter_arrival_time, "flag"] = 1

    filter_consultation_time = ((response_df["consultation_time_numeric"] <= 700) | 
                           (response_df["consultation_time_numeric"] >= 1530))
    response_df.loc[filter_consultation_time, "flag"] = 1

    filter_scheduled_time = ((response_df["scheduled_time_numeric"] <= 700) | 
                           (response_df["scheduled_time_numeric"] >= 1530))
    response_df.loc[filter_scheduled_time, "flag"] = 1

    #response_df = response_df.query("""arrival_time_cleaned >= 530 & arrival_time_cleaned <= 1530""")
    #response_df = response_df.query("""consultation_time_cleaned >= 700 & consultation_time_cleaned < 1530""")

    response_df["waiting_time_filter"] = response_df["consultation_time_numeric"] - response_df["arrival_time_numeric"]
    #response_df = response_df.query("waiting_time_filter >= 0")
    response_df.loc[response_df["waiting_time_filter"] < 0, "flag"] = 1
    response_df = response_df.drop("waiting_time_filter", axis=1)
    return response_df


def compute_waiting_time(hiv_cleaned_numeric):
    """
        convert time info to int and compute waiting_time
    """


    #hiv_cleaned_numeric['arrival_time_numeric'] = (hiv_cleaned_numeric['arrival_time_numeric']
    #                                                .astype(int))
    #hiv_cleaned_numeric['consultation_time_numeric'] = (hiv_cleaned_numeric['consultation_time_numeric']
    #                                                    .astype(int))

    # [ADDED] modified the lines above because it gave an error due to there being NaN 
    hiv_cleaned_numeric['arrival_time_numeric'] = (hiv_cleaned_numeric['arrival_time_numeric']
                                                    .fillna(0).astype(int))

    hiv_cleaned_numeric['consultation_time_numeric'] = (hiv_cleaned_numeric['consultation_time_numeric']
                                                        .fillna(0).astype(int))

    list_arrived = hiv_cleaned_numeric['arrival_time_numeric'].to_list()
    list_entered = hiv_cleaned_numeric['consultation_time_numeric'].to_list()
    list_wt = []

    i = 0
    for (arrived, entered) in  zip(list_arrived, list_entered):
        list_wt.append(time_diff(entered, arrived))
        #print(i)
        i = i + 1
    hiv_cleaned_numeric.loc[:,"waiting_time"] = list_wt
    return hiv_cleaned_numeric

def merge_treat_control_df(hiv_cleaned_numeric):
    treat_control = f"{DATA_FOLDER}/aux/treatment_hdd.dta"
    tc_df = pd.read_stata(treat_control)
    tc_df = tc_df[["facility_cod", "treatment"]]
    hiv_cleaned_numeric = hiv_cleaned_numeric.merge(tc_df, left_on="facility", right_on="facility_cod", 
                     how = "left")
    return hiv_cleaned_numeric


def insert_day_of_the_week(hiv_cleaned_numeric):
    # day 1 maputo (facilities 1 to 41): 1/11/2021
    # day 1 gaza (facilities 42 to 83): 29/11/2021
    hiv_cleaned_numeric.loc[hiv_cleaned_numeric["day"].isin([1, 6, 11]), "day_of_week"] = 1
    hiv_cleaned_numeric.loc[hiv_cleaned_numeric["day"].isin([2, 7, 12]), "day_of_week"] = 2
    hiv_cleaned_numeric.loc[hiv_cleaned_numeric["day"].isin([3, 8]), "day_of_week"] = 3
    hiv_cleaned_numeric.loc[hiv_cleaned_numeric["day"].isin([4, 9]), "day_of_week"] = 4
    hiv_cleaned_numeric.loc[hiv_cleaned_numeric["day"].isin([5, 10]), "day_of_week"] = 5
    return hiv_cleaned_numeric


def load_hiv_endline(hiv_end_df):
    # dictionary to compute sample sizes

    hiv_end_df["empty"] = 0
    #df_1_table, df_2_tables = flag_empty_lines(hiv_end_df)
    #hiv_end_df["arrival_time"] = None
    #hiv_end_df["consultation_time"] = None

    df_1_table_not_empty = find_times_df_1_table(hiv_end_df.query("two_tables == 0"))
    df_2_tables_not_empty = find_times_df_2_tables(hiv_end_df.query("two_tables == 1"))
    #hiv_end_df.loc[df_1_table_not_empty.index, :] = df_1_table_not_empty
    #hiv_end_df.loc[df_2_tables_not_empty.index, :] = df_2_tables_not_empty
    hiv_end_df = pd.concat([df_1_table_not_empty, df_2_tables_not_empty])

    #flagged_df = flag_incorrect_obs(hiv_end_df.query("empty == 0"))
    #hiv_end_df.loc[flagged_df.index, :] = flagged_df
    hiv_cleaned_numeric = flag_incorrect_obs(hiv_end_df)

    #hiv_cleaned_numeric = hiv_end_df
    hiv_cleaned_numeric["waiting_time"] = None

    hiv_cleaned_numeric['flag'].fillna(0, inplace=True) # [ADDED]
    non_flagged_itens = compute_waiting_time(hiv_cleaned_numeric.query("flag == 0"))
    hiv_cleaned_numeric.loc[hiv_cleaned_numeric["flag"] == 0, :] = non_flagged_itens

    hiv_cleaned_numeric = merge_treat_control_df(hiv_cleaned_numeric)
    hiv_cleaned_numeric = insert_day_of_the_week(hiv_cleaned_numeric)

    hiv_cleaned_numeric["arrival_time"] = (hiv_cleaned_numeric["arrival_time_numeric"]
                                            .fillna(0).astype(int))
    hiv_cleaned_numeric["consultation_time"] = (hiv_cleaned_numeric["consultation_time_numeric"]
                                            .fillna(0).astype(int))
    hiv_cleaned_numeric["scheduled_time"] = (hiv_cleaned_numeric["scheduled_time_numeric"]
                                            .fillna(0).astype(int))
    
    hiv_cleaned_numeric["day"] = (hiv_cleaned_numeric["day"].astype(int))
    hiv_cleaned_numeric["page"] = (hiv_cleaned_numeric["page"].astype(int))
    hiv_cleaned_numeric["facility"] = (hiv_cleaned_numeric["facility"].astype(int))
    hiv_cleaned_numeric["line"] = (hiv_cleaned_numeric["line"].astype(int))

    hiv_cleaned_numeric = hiv_cleaned_numeric[["file_name", "facility", 
                                               "day", "page", "line", 
                                               "arrival_time","consultation_time", 
                                               "scheduled_time", "treatment", 
                                               "waiting_time", "flag", "empty"]]

    hiv_cleaned_numeric = hiv_cleaned_numeric.sort_values(["facility","day", 
                                                           "page", "line"])
    return hiv_cleaned_numeric


def clean_hiv():
    tables_df = process_tables() 
    #tables_df = pd.read_csv(f"{DATA_FOLDER}/temp/hiv_endline_temp.csv")
    hiv_endline = load_hiv_endline(tables_df)
    hiv_endline.to_csv(f"{DATA_FOLDER}/hiv/endline/extracted_data/hiv_endline.csv",
                    index=False, mode="w")

def __init__():
    clean_hiv()

__init__()