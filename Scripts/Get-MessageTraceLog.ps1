# This contains a function to collect the Message Trace logging.
Function StartDateMTL {
	param([switch]$Quiet)

	if (($startDate -eq "") -Or ($null -eq $startDate))
	{
		$script:StartDate = [datetime]::Now.ToUniversalTime().AddDays(-90)
		if (-not $Quiet) {
			write-LogFile -Message "[INFO] No start date provided by user setting the start date to: $($script:StartDate.ToString("yyyy-MM-ddTHH:mm:ssK"))" -Color "Yellow"
		}
	}
	else {
		$script:StartDate = $startDate -as [datetime]
		if (!$startDate -and -not $Quiet) {
			write-LogFile -Message "[WARNING] Not A valid start date and time, make sure to use YYYY-MM-DD" -Color "Red"
		} 
	}
}

function EndDateMTL {
	param([switch]$Quiet)

	if (($endDate -eq "") -Or ($null -eq $endDate))
	{
		$script:EndDate = [datetime]::Now.ToUniversalTime()
		if (-not $Quiet) {
			write-LogFile -Message "[INFO] No end date provided by user setting the end date to: $($script:EndDate.ToString("yyyy-MM-ddTHH:mm:ssK"))" -Color "Yellow"
		}
	}
	else {
		$script:EndDate = $endDate -as [datetime]
		if (!$endDate -and -not $Quiet) {
			write-LogFile -Message "[WARNING] Not A valid end date and time, make sure to use YYYY-MM-DD" -Color "Red"} 
	}
}

function Get-MessageTraceLog
{
<#
    .SYNOPSIS
	Collects the trace messages as they pass through the cloud-based organization.

    .DESCRIPTION
    Collects the trace messages as they pass through the cloud-based organization.
	Only 10 days of history is available. Output is saved in: Output\MessageTrace\
	
	.PARAMETER UserIds
    UserIds is the UserIds parameter filtering the log entries by the account of the user who performed the actions.

	.PARAMETER StartDate
    startDate is the parameter specifying the start date of the date range.
	Default: Today 10 days

	.PARAMETER EndDate
    endDate is the parameter specifying the end date of the date range.
	Default: Now

	.PARAMETER OutputDir
    outputDir is the parameter specifying the output directory.
	Default: Output\MessageTrace

	.PARAMETER Encoding
    Encoding is the parameter specifying the encoding of the CSV output file.
	Default: UTF8

	.PARAMETER LogLevel
    Specifies the level of logging:
    None: No logging
    Minimal: Critical errors only
    Standard: Normal operational logging
    Default: Standard

	.EXAMPLE
    Get-MessageTraceLog
	Collects the trace messages for all users.
    
    .EXAMPLE
    Get-MessageTraceLog -UserIds HR@invictus-ir.com
	Collects the trace messages for the user HR@invictus-ir.com.

	.EXAMPLE
    Get-MessageTraceLog -UserIds "Test@invictus-ir.com,HR@invictus-ir.com"
	Collects the trace messages for the users Test@invictus-ir.com and HR@invictus-ir.com.

	.EXAMPLE
	Get-MessageTraceLog -UserIds "*@invictus-ir.com"
	Collects the trace messages for the full @invictus-ir.com domain.

	.EXAMPLE
	Get-MessageTraceLog -UserIds Test@invictus-ir.com -StartDate 1/4/2023 -EndDate 5/4/2023
	Gets the trace messages for the user Test@invictus-ir.com between 1/4/2023 and 5/4/2023.
#>
	[CmdletBinding()]
	param(
		[string]$UserIds,
		[string]$StartDate,
		[string]$EndDate,
		[string]$OutputDir = "Output\MessageTrace",
		[string]$Encoding = "UTF8",
        [ValidateSet('None', 'Minimal', 'Standard')]
        [string]$LogLevel = 'Standard'
	)

	try {
		$areYouConnected = Get-MessageTrace -ErrorAction stop
	}
	catch {
		write-logFile -Message "[INFO] Ensure you are connected to M365 by running the Connect-M365 command before executing this script" -Color "Yellow" -Level Minimal
		Write-logFile -Message "[ERROR] An error occurred: $($_.Exception.Message)" -Color "Red" -Level Minimal
		break
	}
		
	Write-LogFile -Message "=== Starting Message Trace Log Collection ===" -Color "Cyan" -Level Minimal

	StartDateMTL -Quiet
	EndDateMTL -Quiet
	
	Set-LogLevel -Level ([LogLevel]::$LogLevel)
    $date = Get-Date -Format "yyyyMMddHHmm"
    $summary = @{
        StartTime = Get-Date
        ProcessingTime = $null
    }

	if (!(test-path $OutputDir)) {
		New-Item -ItemType Directory -Force -Path $outputDir > $null
	} else {
        if (!(Test-Path -Path $OutputDir)) {
            Write-Error "[Error] Custom directory invalid: $OutputDir exiting script" -ErrorAction Stop
            Write-LogFile -Message "[Error] Custom directory invalid: $OutputDir" -Level Minimal
        }
    }

	if (($null -eq $UserIds) -Or ($UserIds -eq "")) {
        Write-LogFile -Message "[INFO] No users provided. Getting the Message Trace Log for all users between $($script:StartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")) and $($script:EndDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK"))" -Color "Yellow" -Level Standard
        Retrieve-MessageTrace -StartDate $script:StartDate -endDate $script:EndDate -OutputFile "$OutputDir\$($date)-AllUsers-MTL.csv"
    } else {
        if($UserIds -match "\*"){
            Write-LogFile -Message "[INFO] An entire domain has been provided, retrieving all messages between $($script:StartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")) and $($script:EndDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK"))" -Color "Yellow" -Level Standard
        }
        $users = $UserIds.Split(",")

        $users | foreach {
            $user = $_

            write-logFile -Message "[INFO] Collecting the Message Trace Log for $user between $($script:StartDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")) and $($script:EndDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK"))" -Level Standard
            $outputFile = "$OutputDir\$($user.Replace('*@',''))-MTL.csv"
            Remove-Item $outputFile -ErrorAction SilentlyContinue

            Retrieve-MessageTrace -StartDate $script:StartDate -endDate $script:EndDate -OutputFile $outputFile -searchParams @{"RecipientAddress" = $user}
            Retrieve-MessageTrace -StartDate $script:StartDate -endDate $script:EndDate -OutputFile $outputFile -searchParams @{"SenderAddress" = $user}

            if (test-path $outputFile) {
                Write-LogFile -Message "[INFO] Output is written to: $outputFile" -Color "Green" -Level Standard
            } else {
                Write-LogFile -Message "[INFO] No message Trace logging found for $($user)" -Color "Yellow" -Level Standard
            }
        }
    }

	$summary.ProcessingTime = (Get-Date) - $summary.StartTime
	Write-LogFile -Message "`n=== Message Trace Analysis Summary ===" -Color "Cyan" -Level Standard
    Write-LogFile -Message "Analysis Period: $($script:StartDate) to $($script:EndDate)" -Level Standard
    Write-LogFile -Message "Output Statistics:" -Level Standard
	Write-LogFile -Message "  Output Directory: $OutputDir" -Level Standard
    Write-LogFile -Message "  Processing Time: $($summary.ProcessingTime.ToString('mm\:ss'))" -Color "Green" -Level Standard
    Write-LogFile -Message "===================================" -Color "Cyan" -Level Standard
}

function Retrieve-MessageTrace {
# Handle the pagination of the MessageTraceV2 API
    param(
		[DateTime]$startDate,
		[DateTime]$endDate,
		$searchParams = @{},
		[string]$OutputFile
	)

	$localSummary = @{
        MessageCount = 0
        SentCount = 0
        ReceivedCount = 0
        StatusCounts = @{}
    }

	$currentEnd = $endDate
    while($currentEnd -gt $startDate){
        $currentStart = $currentEnd.addDays(-10)
        if($currentStart -lt $StartDate) {
            $currentStart = $StartDate
        }

        $searchParams.ResultSize = 5000
        $searchParams.StartDate = $currentStart
        $searchParams.EndDate = $currentEnd
        $resultCount = 5000
		
        while($resultCount -ge 5000) {
            $results = Get-MessageTraceV2 @searchParams
            $resultCount = $results.Count

            if($results){
                $results | Export-Csv $outputFile -ErrorAction SilentlyContinue -NoTypeInformation -Encoding $Encoding -Append
                Write-LogFile -Message "[INFO] Found $resultCount records between $($results[-1].Received) and $($results[0].Received)"  -Level Standard

                $searchParams.EndDate = $results[-1].Received.ToString("O")
                $searchParams.StartingRecipientAddress = $results[-1].RecipientAddress
            }
        }

        $currentEnd=$currentStart
    }
}