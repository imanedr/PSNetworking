function Write-Log {
   <#
    .SYNOPSIS
    Standard event logging helper.

    .DESCRIPTION
    Writes structured log lines to a default log directory located in the parent folder's "logs" subfolder.
    If this script lives in ...\functions\, the logs default to ...\<parent-folder>\logs\.
    Creates the logs folder if missing. Supports levels, optional JSON output, console output, and pipeline input.

    .PARAMETER Message
    The text to log. Accepts pipeline input.

    .PARAMETER Level
    Log level (INFO, WARN, ERROR, DEBUG, TRACE). Default: INFO.

    .PARAMETER LogPath
    Override default file path. If not provided, default is: <parent-folder>\logs\<parentFolder>_yyyyMMdd.log

    .PARAMETER TimestampFormat
    Format string passed to Get-Date. Default: yyyy-MM-ddTHH:mm:ss.fffK.

    .PARAMETER Json
    Emit a JSON object per line instead of a plain text line.

    .PARAMETER WriteToHost
    Also write the formatted message to the host/console.

    .PARAMETER fileNamePrefix
    Optional prefix for the log file name. If provided, it will be used instead of the script name.

    .EXAMPLE
    "Something happened" | Write-Log -Level Info
    Write-Log -Message "Started process" -Level Debug -WriteToHost
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, Position = 0)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'WARNING', 'ERROR', 'DEBUG', 'TRACE')]
        [string]$Level = 'INFO',

        [string]$LogPath,

        [string]$TimestampFormat = 'yyyy-MM-ddTHH:mm:ss.fffK',

        [switch]$Json,

        [switch]$WriteToHost,
        [string]$fileNamePrefix
    )

    begin {
        # Determine script location and default log directory (parent\logs)
        $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) {
            Split-Path -Parent $MyInvocation.MyCommand.Path
        }
        else {
            # fallback to current directory
            (Get-Location).ProviderPath
        }

        $parentDir = Split-Path -Parent $scriptDir
        if (-not $parentDir) { $parentDir = $scriptDir }    # defensive


        # standard metadata
        $computer = $env:COMPUTERNAME
        $user = $env:USERNAME
        $processId = $PID
        # determine script name for log filename
        if ($fileNamePrefix) {
            $scriptName = $fileNamePrefix
        }
        else {
            if ($MyInvocation.MyCommand.Path) {
                $scriptName = Split-Path -Leaf $MyInvocation.MyCommand.Path
            }
            elseif ($PSCommandPath) {
                $scriptName = Split-Path -Leaf $PSCommandPath
            }
            else {
                # fallback to invocation/name when no script path is available (interactive session)
                $scriptName = if ($MyInvocation.InvocationName) { $MyInvocation.InvocationName } else { $MyInvocation.MyCommand.Name }
            }
        }
        if (-not $LogPath) {
            $logDir = Join-Path $parentDir 'logs'
            # ensure folder exists
            if (-not (Test-Path -LiteralPath $logDir)) {
                New-Item -Path $logDir -ItemType Directory -Force | Out-Null
            }
            $LogPath = Join-Path $logDir ("{0}_{1}_{2}.log" -f $scriptName, $processId, (Get-Date).ToString('yyyyMMdd'))
        }
        else {
            # If a folder was provided, ensure it exists and append default filename
            if ((Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).PSIsContainer) {
                $LogPath = Join-Path $logDir ("{0}_{1}_{2}.log" -f $scriptName, $processId, (Get-Date).ToString('yyyyMMdd'))
            }
            else {
                # ensure dir for provided file exists
                $ld = Split-Path -Parent $LogPath
                if ($ld -and -not (Test-Path -LiteralPath $ld)) { New-Item -Path $ld -ItemType Directory -Force | Out-Null }
            }
        }

       
    }

    process {
        if (-not $Message) { return }  # ignore empty pipeline items

        $ts = (Get-Date).ToString($TimestampFormat)
        $levelUp = $Level.ToUpper()

        if ($Json) {
            $obj = [PSCustomObject]@{
                Timestamp = $ts
                Level     = $levelUp
                Message   = $Message
                User      = $user
                Computer  = $computer
                PID       = $processId
            }
            $line = $obj | ConvertTo-Json -Depth 5 -Compress
        }
        else {
            # Plain text format: TIMESTAMP [LEVEL] [USER@COMPUTER] Message (Script: name PID: ####)
            $line = "{0} [{1}] [{2}@{3}] {4}" -f $ts, $levelUp, $user, $computer, $Message
        }

        # Write to log file (append). Use Out-File to ensure encoding and atomic append behavior.
        try {
            $line | Out-File -FilePath $LogPath -Append -Encoding UTF8 -Force
        }
        catch {
            # If writing fails, write to host error stream
            Write-Error "Write-Log: failed to write to $LogPath - $($_.Exception.Message)"
        }

        if ($WriteToHost) {
            if ($Json) {
                Write-Output $line
            }
            else {
                switch -Regex ($levelUp) {
                    'ERROR' { Write-Host $line -ForegroundColor Red }
                    'WARN|WARNING' { Write-Host $line -ForegroundColor Yellow }
                    'DEBUG' { Write-Host $line -ForegroundColor DarkGray }
                    default { Write-Host $line }
                }
            }
        }

        # also output the constructed object for downstream consumption
        if ($Json) {
            # return object for easier programmatic consumption
            $obj
        }
    }
}