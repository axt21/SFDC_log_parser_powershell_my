#book keeping stuff
#PowerShell.exe -ExecutionPolicy AllSigned
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. C:\Users\xi.tian\2016\Log\usingPowershell\Join-Object.ps1
#should be just . Join-Object.ps1 after this script is click boom-able
#path where logs and tables are saved
$logPath = "C:\Users\xi.tian\2016\Log\usingPowershell\CPRO\CPRO_log\"
#export user, profile, role, and report tables from SFDC using data loader, makesure the format is UTF8
$sfdctbPath = "C:\Users\xi.tian\2016\Log\usingPowershell\CPRO\CPRO_Info\"
#outPath
$outPath = "C:\Users\xi.tian\2016\Log\usingPowershell\CPRO\"


#Step 1
#go to the log directory
#parse out records that was report export (type "v")
#and save the results into .report file with max size of 50MB
#fils are generated 1.report, 2.report...etc
Get-ChildItem $logPath -Filter *.csv | 
Foreach-Object {
$reader = new-object System.IO.StreamReader($_.FullName)
$ext="report"
$count=1
$upperBound=50MB
#file name with full path
	$fileName="{0}{1}.{2}" -f ($logPath, $count, $ext)
	while(($line=$reader.ReadLine()) -ne $null)
	{
		if ($line.StartsWith("v"))
		{
			Add-Content -path $fileName -value $line -Encoding UTF8
			
			if((Get-ChildItem -path $fileName).Length -ge $upperBound)
			{
				++$count
				$fileName = "{0}{1}.{2}" -f ($logPath, $count, $ext)
			}
		}
	}
	$reader.Close()
}

#Step 2
#reimport the report(s) into powershell and add header
#there's a duplicate header in userId and UserID in the original file, powershell is case insensitive
#make my own header by modifying UserId to UserId2
$header = "logRecordType","timestamp","organizationId","userId","remoteAddr","logName","queryString","httpMethod","className","methodName","triggerId","triggerName","triggerType","entityName","apiType","apiVersion","clientName","dashid","jobId","batchId","entityType","verb","event","versionId","distributionType","docId","shareType","dmlType","dashboardId","documentId","fileName","contentType","masterReportId","reportId","reportDescription","method","requestMethod","ipAddress","ProxyingUserId","ProxyingUsername","UserId2","Username","httpReferer"

Get-ChildItem $logPath -Filter *.report | 
Foreach-Object {
    $log = Get-Content $_.FullName | ConvertFrom-Csv -Header $header | Select timestamp, userId, logName 
}
#trim the / in logName
foreach($logtmp in $log)
{
	if(($logtmp.logName.Length) -gt 15)
	{
		$logtmp.logName=($logtmp.logName.Substring(1,15))
	}
}
#get # of rows
$log | measure

#Step 3
#load SFDC data tables
#convert files to UTF8 if they are not already in UTF8 format###### IMPORTANT ######
$user = Import-Csv -Path $sfdctbPath"User_cpro_20160830.csv" -Encoding UTF8 | Select ID,USERNAME,NAME, PROFILEID, USERROLEID 
#change column names
$user = $user | Select-Object @{Expression = {$_.ID}; label='USERID_u'}, @{Expression = {$_.USERNAME}; label='USERNAME'}, @{Expression = {$_.NAME}; label='NAME'}, @{Expression = {$_.PROFILEID}; label='PROFILEID'}, @{Expression = {$_.USERROLEID}; label='USERROLEID'}
#profile
$profile = Import-Csv -Path $sfdctbPath"Profile_cpro_20160830.csv" -Encoding UTF8 | Select ID,NAME, PERMISSIONSRUNREPORTS, PERMISSIONSEXPORTREPORT, PERMISSIONSDATAEXPORT
$profile = $profile | Select-Object @{Expression = {$_.ID}; label='PROFILEID_p'}, @{Expression = {$_.NAME}; label='PROFILENAME'}, @{Expression = {$_.PERMISSIONSRUNREPORTS}; label='PermissionsRunReports'},@{Expression = {$_.PERMISSIONSEXPORTREPORT}; label='PermissionsExportReport'}, @{Expression = {$_.PERMISSIONSDATAEXPORT}; label='PermissionsDataExport'}
#role
$role = Import-Csv -Path $sfdctbPath"UserRole_cpro_20160830.csv" -Encoding UTF8 | Select ID,NAME
$role = $role | Select-Object @{Expression = {$_.ID}; label='ROLEID_r'}, @{Expression = {$_.NAME}; label='ROLENAME'}
#report
$report = Import-Csv -Path $sfdctbPath"Report_cpro_20160830.csv" -Encoding UTF8 | Select ID,NAME, DESCRIPTION
$report = $report | Select-Object @{Expression = {$_.ID}; label='REPORTID_r'}, @{Expression = {$_.NAME}; label='REPORTNAME'}, @{Expression = {$_.DESCRIPTION}; label='DESCRIPTION'}
#$trim user ID to 15 digit to match the log
foreach($usertmp in $user)
{
	$usertmp.USERID_u=($usertmp.USERID_u.Substring(0,15))
}
#$trim report ID to 15 digit to match the log
foreach($reporttmp in $report)
{
	$reporttmp.REPORTID_r=($reporttmp.REPORTID_r.Substring(0,15))
}


#Step4
#left join tables

$total1 = Join-Object -Left $log -Right $user -Where {$args[0].userId -ceq $args[1].USERID_u} -LeftProperties "*" -RightProperties "*" -Type AllInLeft
$total2 = Join-Object -Left $total1 -Right $profile -Where {$args[0].PROFILEID -ceq $args[1].PROFILEID_p} -LeftProperties "*" -RightProperties "*" -Type AllInLeft
$total3 = Join-Object -Left $total2 -Right $role -Where {$args[0].USERROLEID -ceq $args[1].ROLEID_r} -LeftProperties "*" -RightProperties "*" -Type AllInLeft
$total4 = Join-Object -Left $total3 -Right $report -Where {$args[0].logName -ceq $args[1].REPORTID_r} -LeftProperties "*" -RightProperties "*" -Type AllInLeft

#Step 5
#count the number of records
$final = $total4 | Select NAME, PROFILENAME, ROLENAME, REPORTNAME, DESCRIPTION, REPORTID_r, PermissionsRunReports, PermissionsExportReport, PermissionsDataExport, timestamp | Sort-Object timestamp
$final | Export-Csv $outPath"CPRO_report_export_list.csv" -Encoding UTF8

#Step 6 
#group by number of exports per user
$info = $total4 | Select userId, NAME, USERNAME, PROFILENAME, ROLENAME, PermissionsRunReports, PermissionsExportReport, PermissionsDataExport  
$final2 = $total4 | Select userId | Group-Object userId | Sort count -descending | Select-Object @{Expression = {$_.NAME}; label='NAME_userid'}, @{Expression = {$_.count}; label='Count'}
$total6 = Join-Object -Left $final2 -Right $info -Where {$args[0].NAME_userid -ceq $args[1].userId} -LeftProperties "*" -RightProperties "*" -Type OnlyIfInBoth
$total7 = $total6 | Get-Unique -AsString
$total8 = $total7 | Select NAME, USERNAME, PROFILENAME, ROLENAME, PermissionsRunReports, PermissionsExportReport, PermissionsDataExport, Count
$total8 | Export-Csv $outPath"CPRO_report_export_cnt_list.csv" -Encoding UTF8





