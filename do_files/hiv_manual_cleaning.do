
*** this dofile manually cleans observations. At the moment the cleaning is not systematic:
*       when I spot errors in the values for some variables, if I realize they cannot be fixed in a 
*       automated way I manually clean them here.


* manual cleaning

** arrival_time
replace arrival_time = 1032 if file_name=="endline_US10_day5_page5.txt" & line==3
replace arrival_time = 848 if file_name=="endline_US10_day7_page7.txt" & line==3
replace arrival_time = 849 if file_name=="endline_US10_day7_page7.txt" & line==4
replace arrival_time = 1040 if file_name=="endline_US13_day2_page6.txt" & line==8
replace arrival_time = 800 if file_name=="endline_US13_day8_page6.txt" & line==4

** consultation_time
replace consultation_time = 1142 if file_name=="endline_US43_day12_page4.txt" & line==1 
replace consultation_time = 1100 if file_name=="endline_US13_day2_page6.txt" & line==8
replace consultation_time = 830 if file_name=="endline_US13_day8_page6.txt" & line==4


** scheduled_time
replace scheduled_time = 1030 if file_name=="endline_US30_day10_page5.txt" & line==5
replace scheduled_time = 830 if file_name=="endline_US30_day10_page5.txt" & line==6
replace scheduled_time = 830 if file_name=="endline_US30_day4_page5.txt" & line==2
replace scheduled_time = 1030 if file_name=="endline_US30_day4_page8.txt" & line==5
replace scheduled_time = 830 if file_name=="endline_US30_day6_page6.txt" & line==6
replace scheduled_time = 1030 if file_name=="endline_US30_day7_page8.txt" & line==7 // it is equal ot 1041111, should be 10H11H
replace scheduled_time = 0 if file_name=="endline_US61_day5_page3.txt"  // the whole page
replace scheduled_time = 0 if file_name=="endline_US13_day2_page6.txt" & line==8
replace arrival_time = 0 if file_name=="endline_US13_day8_page6.txt" & line==4

** next_scheduled_time
replace next_scheduled_time = "8h" if file_name=="endline_US14_day7_page5.txt" & line==6
replace next_scheduled_time = "8h" if file_name=="endline_US14_day9_page7.txt" & line==6


/*
facility-day-page with no consultation time in the split image:
--- endline_US25_day1_page5.png

--- endline_US43_day12_page4.txt

*/