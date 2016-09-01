# SFDC_log_parser_powershell
SFDC_log_parser_powershell

Join-Object.ps1 is taken from a ms website, written by one of the ms scripting guys. 

The path is hardcoded inside the powershell scripts. Make sure to go inside and specify the path. 
All input files should have the UTF8 encoding. 

Step 1
go to the log directory
parse out records that was report export (type "v")
and save the results into 1 or more .report file swith max size of 50MB (keeping the file size small) 1.report, 2.report...etc

Step 2
reimport the report(s) into powershell and add header
there's a duplicate header in userId and UserID in the original file, powershell is case insensitive
make my own header by modifying UserId to UserId2
trim the / in logName

Step 3
load SFDC data tables

Step 4
join tables based on keys

Step 5 and 6 
export two types of report. one has all the info, another one has counts.
