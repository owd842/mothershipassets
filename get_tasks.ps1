Get-ScheduledTask | ForEach-Object {
    $taskInfo = $_ | Get-ScheduledTaskInfo
    [PSCustomObject]@{
        TaskName     = $_.TaskName
        TaskPath     = $_.TaskPath
        State        = $_.State
        LastRunTime  = $taskInfo.LastRunTime
        NextRunTime  = $taskInfo.NextRunTime
        LastResult   = $taskInfo.LastTaskResult
        # Joins multiple actions (if any) into a single string
        CommandLine  = ($_.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join " ; "
    }
} | Format-List | Out-File -FilePath $args[0] -Encoding utf8