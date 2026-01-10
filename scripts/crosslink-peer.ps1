# Crosslink CLI - Agent-to-Agent Communication (Windows)
# Usage:
#   .\crosslink-cli.ps1 send <to_machine> "prompt"
#   .\crosslink-cli.ps1 check
#   .\crosslink-cli.ps1 respond <task_id> "result"
#   .\crosslink-cli.ps1 status <task_id>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1)]
    [string]$Arg1,

    [Parameter(Position=2)]
    [string]$Arg2
)

$Server = "http://192.168.50.2:8888"
$MyMachine = "windows"

switch ($Command) {
    "send" {
        $ToMachine = $Arg1
        $Prompt = $Arg2

        if (-not $ToMachine -or -not $Prompt) {
            Write-Host "Usage: crosslink-cli.ps1 send <linux|windows> 'your prompt'"
            exit 1
        }

        $Body = @{
            prompt = $Prompt
            from_machine = $MyMachine
            to_machine = $ToMachine
        } | ConvertTo-Json

        $Response = Invoke-RestMethod -Uri "$Server/tasks" -Method Post -Body $Body -ContentType "application/json"
        Write-Host "Task sent: $($Response.task_id)"
        $Response | ConvertTo-Json
    }

    "check" {
        $Response = Invoke-RestMethod -Uri "$Server/tasks/pending/$MyMachine"

        if ($Response.pending_count -eq 0) {
            Write-Host "No pending tasks"
        } else {
            Write-Host "Found $($Response.pending_count) pending task(s):"
            $Response.tasks | ForEach-Object {
                Write-Host ""
                Write-Host "  Task ID: $($_.id)"
                Write-Host "  From: $($_.from_machine)"
                Write-Host "  Prompt: $($_.prompt)"
                Write-Host "  Created: $($_.created_at)"
            }
        }
    }

    "respond" {
        $TaskId = $Arg1
        $Result = $Arg2

        if (-not $TaskId -or -not $Result) {
            Write-Host "Usage: crosslink-cli.ps1 respond <task_id> 'result'"
            exit 1
        }

        $Body = @{
            task_id = $TaskId
            result = $Result
        } | ConvertTo-Json

        $Response = Invoke-RestMethod -Uri "$Server/tasks/$TaskId/complete" -Method Post -Body $Body -ContentType "application/json"
        Write-Host "Response sent:"
        $Response | ConvertTo-Json
    }

    "status" {
        $TaskId = $Arg1

        if (-not $TaskId) {
            Write-Host "Usage: crosslink-cli.ps1 status <task_id>"
            exit 1
        }

        $Response = Invoke-RestMethod -Uri "$Server/tasks/$TaskId"
        $Response | ConvertTo-Json -Depth 5
    }

    "list" {
        $Response = Invoke-RestMethod -Uri "$Server/tasks"
        Write-Host "Total: $($Response.total) | Pending: $($Response.pending) | Completed: $($Response.completed)"
        $Response.tasks | ConvertTo-Json -Depth 5
    }

    default {
        Write-Host "Crosslink CLI - Agent Communication"
        Write-Host ""
        Write-Host "Commands:"
        Write-Host "  send <machine> 'prompt'   Send task to linux or windows"
        Write-Host "  check                     Check for tasks assigned to me"
        Write-Host "  respond <id> 'result'     Complete a task with result"
        Write-Host "  status <id>               Check status of a task"
        Write-Host "  list                      List all tasks"
    }
}
