#~~~~~~~~~~~~~~~~~
#Log File Analysis
#  Jacky Liang
#  Sep,2020
#~~~~~~~~~~~~~~~~~

#~~~~~~~~~~~~~~~~~~~
#Processing raw data
#~~~~~~~~~~~~~~~~~~~

 $color = "green"
 $colorRed = "red"


#Define the function to unzip GZip file
Function UnGZip-File{
    Param(
        $inFile,
        $outFile = ($inFile -replace '\.gz$','')
        )

    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)

    $buffer = New-Object byte[](1024)
    while($true){
        $read = $gzipStream.Read($buffer, 0, 1024)
        if ($read -le 0){break}
        $output.Write($buffer, 0, $read)
        }

    $gzipStream.Close()
    $output.Close()
    $input.Close()
}

#Unzip the file
$inFile='.\Helpdesk_interview_data_set.gz'
$outFile='.\Helpdesk_interview_data_set.txt'

Get-Date
Write-Host -ForegroundColor $color "Start to unzip RAW data..."
UnGZip-File $inFile $outFile

while((Test-Path $outFile) -eq $null) {
    sleep 1
}

Write-Host -ForegroundColor $color "RAW data unzipping completed"

#~~~~~~~~~~~~~~~~~~~~~~~~~~
#Data cleaning and analysis
#~~~~~~~~~~~~~~~~~~~~~~~~~~

#Data cleaning and extract useful information from the unzipped log and output to CSV
Write-Host -ForegroundColor $color "Start to clean and analyze the data, and then output to CSV..."
Get-Content .\Helpdesk_interview_data_set.txt | Where-Object { 
-not ([string]::IsNullOrEmpty($_) -or [string]::IsNullOrWhiteSpace($_) -or $_.contains("--- last message repeated * time ---") -or $_.contains("syslogd[113]") -or $_.startswith("	ASL Module") -or $_.startswith("	Those messages") -or $_.startswith("	Output parameters"))
} | ForEach-Object {
    [PSCustomObject]@{
        timeSlot = $_.split()[2].substring(0,2)
        deviceName = $_.split()[3]
        processName = $_.split()[4].split("[")[0]
        processId = $_.substring($_.indexof("[")+1,$_.indexof("]")-$_.indexof("["))
        description = $_.substring($_.indexof("]")+2,$_.length-$_.indexof("]")-2) -replace ",",";" 
    }
} | Group-Object timeSlot,deviceName,processName,processId,description  | ForEach-Object { $_.Name+","+$_.count} | ac .\temp.csv 

while((Test-Path .\temp.csv) -eq $null) {
    sleep 1
}

Write-Host -ForegroundColor $color "CSV file generated"

#Importing CSV and add headers
$csv = import-Csv -Path .\temp.csv -Header ("timeSlot","deviceName","processName","processId","desciption","count") 

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#Convert analysis result to Json and post to website
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#Ignore errors encountered when a website to be connected is using self signed SSL certificate
if (-not ([System.Management.Automation.PSTypeName]'ServerCertificateValidationCallback').Type)
{
$certCallback = @"
    using System;
    using System.Net;
    using System.Net.Security;
    using System.Security.Cryptography.X509Certificates;
    public class ServerCertificateValidationCallback
    {
        public static void Ignore()
        {
            if(ServicePointManager.ServerCertificateValidationCallback ==null)
            {
                ServicePointManager.ServerCertificateValidationCallback += 
                    delegate
                    (
                        Object obj, 
                        X509Certificate certificate, 
                        X509Chain chain, 
                        SslPolicyErrors errors
                    )
                    {
                        return true;
                    };
            }
        }
    }
"@
    Add-Type $certCallback
 }
[ServerCertificateValidationCallback]::Ignore()

Write-Host -ForegroundColor $color "Start to convert CSV to Json..."

#Covert CSV to Json format
$json = $csv | ConvertTo-Json

while($json.length -lt $csv.length) {
    sleep 1
}

Write-Host -ForegroundColor $color "Covert To Json completed"

$uri = 'https://foo.com/bar'

Write-Host -ForegroundColor $color "Start to post Json data to the website..."

#Post the Json format result to website
curl -uri $uri -Method POST -Body $json


#Cleaning up temp file and variable
del .\Helpdesk_interview_data_set.txt
del .\temp.csv
$csv = ""
$uri = ""
$json = ""
Get-Date