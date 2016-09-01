>stdout.log 2>&1 (
echo processing DMCC logs
Powershell.exe -executionpolicy Unrestricted -File code_dmcc.ps1
echo processing CPRO logs
Powershell.exe -executionpolicy Unrestricted -File code_cpro.ps1
)