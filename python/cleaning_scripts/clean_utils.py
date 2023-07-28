import pandas as pd
import numpy as np

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

def clean_time_with_h(time):
    """ change 8h to 800 and 7h5 to 705"""

    cleaned = time
    size = len(cleaned)
    mask = mask_time(time)

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
    
    return cleaned

assert clean_time_with_h("705") == "705"
assert clean_time_with_h("7h5") == "705"
assert clean_time_with_h("7h") == "700"
assert clean_time_with_h("12H") == "1200"
assert clean_time_with_h("7H5") == "705"
assert clean_time_with_h("7H") == "700"
assert clean_time_with_h("12H") == "1200"
assert clean_time_with_h("12H05") == "1205"
assert clean_time_with_h("9-10") == "9-10"
assert clean_time_with_h("9_10") == "9_10"
assert clean_time_with_h("9") == "9"

from datetime import datetime
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

assert time_diff(990, 910) == -1   
assert time_diff(920, 910) == 10   #10
assert time_diff(920, 850) == 30   #70 
assert time_diff(940, 910) == 30   #30 
assert time_diff(1320, 920) == 240 #400
assert time_diff(1030, 1000) == 30 #70
assert time_diff(1010, 950) == 20  #60
assert time_diff(1000, 900) == 60  #60
assert time_diff(1110, 950) == 80  #160

scheduled_repl = {
    "0708":"0730",
    "89":"830",
    "8_9":"830",
    "8 a 9":"830",
    "1011":"1030",
    "1112":"1130",
    "1213":"1230",
    "1":"1000",
    "78":"730",
    "91":"930",
    "50":"800",
    "2911":"1000",#9 to 11
    "30":"800",
    "7440":"740",
    "07:08":"730",
    "910":"930",
    "811":"930",
    "10_11":"1030",
    "08":"800",
    "0809":"830",
    "11_12":"1130",
    "101":"1030",
    "102":"1020",
    "1013":"1130",
    "130":"1300",
    "230":"730"
}

def clean_time_scheduled(time):
    if time == "":
        return time
    
    cleaned = time.replace(".0","")
    size = len(cleaned)
    if size > 5:
        cleaned = cleaned.replace(":00", "")
    
    cleaned = cleaned.replace(":", "")
    for key,value in scheduled_repl.items():
        if cleaned == key:
            cleaned = value
    
    if size in [1,2]:
        if int(cleaned) in range(7,17):
            cleaned = cleaned + "00"
            
    return cleaned.lstrip("0")

assert clean_time_scheduled("930") == "930"
assert clean_time_scheduled("0930") == "930"
assert clean_time_scheduled("9") == "900"
assert clean_time_scheduled("900.0") == "900"
assert clean_time_scheduled("10") == "1000"
assert clean_time_scheduled("8_9") == "830"
assert clean_time_scheduled("1") == "1000"
assert clean_time_scheduled("8:29") == "829"
assert clean_time_scheduled("1011") == "1030"
assert clean_time_scheduled("1011.0") == "1030"
assert clean_time_scheduled("1011:00") == "1030"
assert clean_time_scheduled("10:11:00") == "1030"
assert clean_time_scheduled("10:00") == "1000"
assert clean_time_scheduled("10.0") == "1000"
assert clean_time_scheduled("10") == "1000"
assert clean_time_scheduled("") == ""

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

assert time_to_time_float(730) == 7.5
assert time_to_time_float(1000) == 10
assert time_to_time_float(1020) == 10.33