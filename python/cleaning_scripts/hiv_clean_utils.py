"""
    This file contains functions used to 
    clean HIV aws json files.
"""

def remove_special_characters(column):
    """
        removes ":.,\ ", leading "0" to compare to annotated data
    """
    return (column
             .str.replace(":", "")
             .str.replace(".", "")
             .str.replace(" ", "")
             .str.replace("\'", "") # Attention: removing "'", not \
             .str.replace("\\", "")
             .str.replace("\/", "")
             .str.replace(",", "")
             .str.replace("i", "")
             .str.replace("-", "")
             .str.replace("M", "")
             .str.replace("r", "") # this line and those below where added to clean the scheduled_time column
             .str.replace("W", "") 
             .str.replace("w", "") 
             .str.replace("m", "") 
             .str.replace("n", "") 
             .str.replace("l", "") 
             .str.replace("u", "") 
             .str.replace("t", "") 
             .str.replace("s", "")             
             )


def remove_consultation_reason(column):
    """
        removes words related to the Column "reason of consultation"
        so that empty 
    """
    return (column
             .str.replace(":", "")
             .str.replace(".", "")
             .str.replace(" ", "")
             .str.replace("\'", "") # Attention: removing "'", not \
             .str.replace("\\", "")
             .str.replace("\/", "")
             .str.replace(",", "")
             .str.replace("i", "")
             .str.replace("-", "")
             .str.replace("M", ""))

def mask_time(text):
    """
        returns indications for each character if it is digit, 
        alphabetic or special. H is left as H
        For example: mask("1H20M") == "DHDDA"
    """
    mask = ""
    for char in text:
        if char == "H" or char == "h":
            mask = mask + "H"
        elif char.isalpha():
            mask = mask + "A"
        elif char.isnumeric():
            mask = mask + "D"
        else:
            mask = mask + "S"
    return mask

assert mask_time("1H-20M") == "DHSDDA"
assert mask_time("7H") == "DH"

import numpy as np
import pandas as pd
def clean_time_with_h(time):
    """ change 8h to 800 and 7h5 to 705"""

    if time == None or time == "" or pd.isna(time):
        return time

    cleaned = time
    size = len(cleaned)

    if cleaned.startswith("H"):
        cleaned = cleaned[1:size]

    size = len(cleaned)
    mask = mask_time(cleaned)

    if time.endswith("h") or time.endswith("H"):
        cleaned = cleaned.replace("h", "00")
        cleaned = cleaned.replace("H", "00")

    #cleans 7h5, 12h7
    if mask.endswith("HD"):
        cleaned = cleaned.replace("h", "0")
        cleaned = cleaned.replace("H", "0")

    #cleans 13h10, 7h10
    if mask.endswith("HDD"):
        cleaned = cleaned.replace("h", "")
        cleaned = cleaned.replace("H", "")
    return cleaned.replace("o", "0").replace("M", "11")

assert clean_time_with_h("705") == "705"
assert clean_time_with_h("7h5") == "705"
assert clean_time_with_h("7h") == "700"
assert clean_time_with_h("12H") == "1200"
assert clean_time_with_h("7H5") == "705"
assert clean_time_with_h("7H") == "700"
assert clean_time_with_h("12H") == "1200"
assert clean_time_with_h("12H05") == "1205"
assert clean_time_with_h("H12H05") == "1205"
assert clean_time_with_h("H705") == "705"



from datetime import datetime
def time_diff(final_time, initial_time):
    """
        computes the time diff between 2 integers.
        returns -1 if one of the times is invalid
        time_diff(920, 910) = 10
        time_diff(920, 910) = 10
    """
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

assert time_diff(990, 910) == -1
assert time_diff(920, 910) == 10   #10
assert time_diff(920, 850) == 30   #70
assert time_diff(940, 910) == 30   #30
assert time_diff(1320, 920) == 240 #400
assert time_diff(1030, 1000) == 30 #70
assert time_diff(1010, 950) == 20  #60
assert time_diff(1000, 900) == 60  #60
assert time_diff(1110, 950) == 80  #160


def get_facility_day_page(file_name):
    """
        extract facility, day and page from
        filename
    """
    facility = int(file_name.split("_")[1].replace("US", ""))
    day = int(file_name.split("_")[2].replace("day", ""))
    page = int(file_name.split("_")[3]
                        .replace("page", "")
                        .replace(".txt", ""))
    return facility, day, page
assert get_facility_day_page("endline_US10_day11_page3.txt") == (10, 11, 3)
