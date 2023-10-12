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
             .str.replace("r", "") 
             .str.replace("W", "") 
             .str.replace("w", "") 
             .str.replace("m", "") 
             .str.replace("n", "") 
             .str.replace("l", "") 
             .str.replace("u", "") 
             .str.replace("t", "") 
             .str.replace("s", "")    
             .str.replace("h", "H")     
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


# checks for observations where the character "h" (within the first three characters of a string) is misread as a 4 
def misread_h(text):
    if len(str(text)) > 3 and str(text)[0:2] in ["64", "74", "84", "94"]:
        return str(text)[0:1] + "H" + str(text)[2:]
    if len(str(text)) == 4 and str(text)[0:2] in ["44"]: # there are few observations where the hour 11 is misread as 44
        return "11" + str(text)[2:]
    if len(str(text)) > 4 and str(text)[0:3] in ["104", "124", "114"]:
        return str(text)[0:2] + "H" + str(text)[3:]
    if len(str(text)) > 4 and str(text)[0:3] in ["811", "711", "911"]:
        return str(text)[0:1] + "H" + str(text)[3:]
    else: 
        return text

# given that sometimes the scheduled appointment is a range of one hour, we also have to clean "h" at the end of the string
def misread_h_scheduled(text):
    if len(str(text)) > 3 and str(text)[0:2] in ["64", "74", "84", "94"]:
        return str(text)[0:1] + "H" + str(text)[2:]
    if len(str(text)) == 4 and str(text)[0:2] in ["44"]: # there are few observations where the hour 11 is misread as 44
        return 11 + str(text)[2:]
    if len(str(text)) > 4 and str(text)[0:3] in ["104", "124", "114"]:
        return str(text)[0:2] + "H" + str(text)[3:]
    if len(str(text)) > 4 and str(text)[0:3] in ["811", "711", "911"]:
        return str(text)[0:1] + "H" + str(text)[3:]
    if len(str(text)) > 3 and str(text)[-2:] in ["94", "84", "74"]:
        return str(text)[:-1] +  "H"
    if len(str(text)) > 4 and str(text)[-3:] in ["104", "114", "124", "134"]:
        return str(text)[:-1] +  "H"
    else:
        return text
    
# hour range cleans observations where scheduled time takes the form of an hour range (e.g. 8H9H), returning the midpoint
def hour_range(text):
    formats = ("DHDH", "DDHDDH", "DHDDH","DDHDH")
    if isinstance(text, float):
        return text
    if mask_time(text) in formats:
        return ((int(text.split("H")[0]) + int(text.split("H")[1]))/2) # [QUESTION] is it okay to return the midpoint? or should we report the minimum
    else: 
        return text
    
import numpy as np
import pandas as pd
def clean_time_with_h(time):
    """ change 8h to 800 and 7h5 to 705"""

    if time == None or time == "" or pd.isna(time):
        return time

    if isinstance(time, bool):
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

import numpy as np
def time_to_time_float(time):
    """ transforms 730 into 7.5 """
    if not time:
        return np.nan
    if np.isnan(time):
        return time
    if time == "":
        return np.nan
    if len(str(time)) < 3:
        return np.nan

    time = str(time)
    size = len(time)
    hour = float(time[0:(size-2)])
    minute = float(time[(size-2):size])
    return hour + round(minute/60, 2)