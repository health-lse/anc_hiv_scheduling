"""
    Cleans aws textract files regarding HIV baseline
"""

from hiv_clean_utils import *
import pandas as pd
import numpy as np
import json
# package to read aws json files
from trp import Document
from os import listdir

ROOT = "/Users/rafaelfrade/arquivos/desenv/lse/anc_hiv_scheduling/data/"
baseline_path=f"{ROOT}/hiv/baseline/aws_files"
cleaned_data=f"{ROOT}/cleaned_data"

def get_facility_page(file_name):
    """
        extract facility and day  from
        filename
    """
    file_name = file_name.replace(".txt", "")
    facility = int(file_name.split("_")[1].replace("US", ""))
    page = int(file_name.split("_")[2]
                    .replace("page", ""))
    
    return facility, page

assert get_facility_page("baseline_US1_page1.txt") == (1,1)

def remove_special_characters(string):
    """
        removes ":.,\ ", leading "0" to compare to annotated data
    """
    return (string
             .replace(":", "")
             .replace(".", "")
             .replace(" ", "")
             .replace("\'", "") # Attention: removing "'", not \
             .replace("\\", "")
             .replace("\/", "")
             .replace(",", "")
             .replace("i", "")
             .replace("-", ""))

replace_dic_1st = {
    "mim":"min",
    "mm":"min",
    "NOT_SELECTED":"",
    "Bom":"30m",
    "Bm":"3m",
    "mi-":"mi",
    "+/-":"",
}
 
case_sensitive_replace = {
    "amin":"9min",
    "Amin":"1min",
    "ZMIN":"1min"
}

replace_dic_sec = {
    "sm":"5m",
    "smin":"5min",
    "jomin":"20min",
    "zomin":"20min",
    "domin":"20min",
    "lomin":"10min",
    "romin":"10min",
    "tomin":"10min",
    "tom":"10m",
    "th":"1h",
    "ih":"1h",
    "zh":"2h",
    "lom":"10m",
    "uh":"4h",
    "2n":"2h",
    "lh":"1h",
    "Amin":"1min",
    "us":"45",
    "gmin":"9min",
    "jh":"2h",
    "bm":"6m",
    "hon":"hor",
    "selected":"",
    ":h":"h",
    "1e":"1h",
    "2e":"2h",
    "3e":"3h"
}

final = {
    "omin":"0min",
    "z":"2"
}

exact_replace = {
    "the":"1h",
    "14":"1h",
    "gh":"9h",
    "hora":"1h",
    "sh":"5h"
}

contains_replace_all = {
    "1n":"1h",
    "lh":"1h",
    "seg":"0"
}

starts_with = {
    "is":"15",
    "as":"15",
    "sh":"5h",
}

def replace_with_dic(time, dictionary):
    for from_,to_ in dictionary.items():
        time = time.replace(from_, to_)
    return time

assert replace_with_dic("amin", case_sensitive_replace) == "9min"

def replace_patterns(wt):
    wt = replace_with_dic(wt, replace_dic_1st)
    wt = replace_with_dic(wt, case_sensitive_replace)
    
    wt = wt.lower()
    wt = wt.replace(" ", "")
    wt = replace_with_dic(wt, replace_dic_sec)
    
    for from_, to_ in contains_replace_all.items():
        if from_ in wt:
            return to_
    
    wt = remove_special_characters(wt)
    
    for from_, to_ in exact_replace.items():
        if from_ == wt:
            return to_

    for from_, to_ in starts_with.items():
        if wt.startswith(from_):
            wt = wt.replace(from_, to_)
    
    return wt

def extract_minute(time):
    if "m" in time:
        before_min = time.split("m")[0]
        if before_min.isnumeric():
            return float(before_min)
    
    return None

assert extract_minute("30min") == 30

def extract_time(time):
    """
        extract hour and minute separated
    """
    hour = np.nan
    minute = np.nan
    if "h" in time:
        before_h = time.split("h")[0]
        if before_h.isnumeric():
            hour = float(before_h)
            before_min = extract_minute(time.split("h")[1])
            if before_min:
                minute = float(before_min)
            else:
                minute = 0
    else:
        before_min = extract_minute(time)
        if before_min:
            hour = 0
            minute = float(before_min)
    return hour, minute

assert extract_time("1h30min") == (1.0, 30.0)
assert extract_time("30min") == (0, 30.0)


import re
def find_regex(time):
    """
        finds patterns D:D and DhD
        return hour and minutes
    """
    
    regex_2dots = re.compile(r'\d\:\d', re.I)
    regex_h = re.compile(r'\dh\d', re.I)
    #regex_dot = re.compile(r'\d\.\d', re.I)

    hour = np.nan
    minute = np.nan

    m = regex_2dots.search(time)
    if m:
        pattern = m.group()
        hour = pattern.split(":")[0]
        minute = pattern.split(":")[1]

    m = regex_h.search(time)
    if m:
        pattern = m.group()
        hour = pattern.split("h")[0]
        minute = pattern.split("h")[1]
    return float(hour), float(minute)*10


def get_dictionary_response():
    """
        puts textract content into a dictionary
    """
    total = 0

    dict_response = {"file_name":[], "facility":[],
                     "page": [], "line":[],
                     "waiting_time":[]}
    responses_sample = [f for f in listdir(baseline_path) if "txt" in f]
    for file in responses_sample:
        total += 1
        if total % 100 == 0:
            print(total)

        f = open(f"{baseline_path}/{file}", "r")
        response_string = f.read()
        response_json = json.loads(response_string)
        doc = Document(response_json)
        doc_page = doc.pages[0]

        if len(doc_page.tables) == 0:
            continue
        table = doc_page.tables[0]

        first_line_cells = table.rows[0].cells
        index_waiting_time = 0 # 
        for cell in first_line_cells:
            c = cell.text
            if "Tempo" in c or "fila" in c or "aguardou" in c:
                break
            index_waiting_time += 1

        line_number = 1
        # skip first because it's the header
        for row in table.rows[1:len(table.rows)]:

            facility, page = get_facility_page(file)
            waiting_time = row.cells[index_waiting_time].text

            dict_response["file_name"].append(file)
            dict_response["facility"].append(facility)
            dict_response["page"].append(page)
            dict_response["line"].append(line_number)
            dict_response["waiting_time"].append(waiting_time)

            line_number += 1
    return dict_response


def generate_hiv_baseline():
    # extracts aws data
    hiv = pd.DataFrame(get_dictionary_response())
    hiv["hour"] = np.nan
    hiv["minute"] = np.nan

    hiv = hiv.query("~ waiting_time.str.contains('aguardou')")
    hiv = hiv.query("~ waiting_time.str.contains('control')")
    hiv["wt_replaced"] = hiv["waiting_time"].apply(replace_patterns)

    # 1st attempt to find final data: regex
    hiv["hour"] = hiv["wt_replaced"].apply(find_regex).apply(lambda x: x[0])
    hiv["minute"] = hiv["wt_replaced"].apply(find_regex).apply(lambda x: x[1])

    # 2nd attempt to find final data: find hour
    hiv.loc[hiv["hour"].isna(), "hour"] = hiv.loc[hiv["hour"].isna(), "wt_replaced"].apply(extract_time).apply(lambda x: x[0])
    hiv.loc[hiv["minute"].isna(), "minute"] = hiv.loc[hiv["minute"].isna(), "wt_replaced"].apply(extract_time).apply(lambda x: x[1])

    hiv.loc[hiv.eval("hour > 9"), "hour"] = np.nan
    hiv.loc[hiv.eval("minute > 100"), "minute"] = np.nan

    hiv["waiting_time_minutes"] = hiv["hour"]*60 + hiv["minute"]

    # remove empty lines
    hiv = hiv.query("waiting_time != '' ")
    hiv.to_csv(f"{cleaned_data}/hiv_baseline.csv", index=False, mode="w")
    print("HIV baseline generated")

def __init__():
    generate_hiv_baseline()

__init__()
