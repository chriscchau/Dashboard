<#
.SYNOPSIS
	Operation Dashboard
.DESCRIPTION
    The dashboard is intended to be used for performing health check tasks for IT systems.
.NOTES
	Version		: 1.0
	Date		: 18 June 2013
    Author		: Chris C CHAU
    Requires	: PowerShell V3 & .NET framework 4.0
.COMPONENT
	Main file	: Dashboard.ps1
	Includes	: Check-Status.ps1 (Routines for health checkings)
				  Dashboard.xaml (Defination file for the GUI)
				  Dashboard.xml (Configuration file for tasks to be checked)
				  plink.exe (Plink executable from PuTTY for remote running UNIX scripts, which needs to be downloaded separated.)
				  putty.exe (PuTTY executable from PuTTY for accessing UNIX Operator Menu, which needs to be downloaded separated.)
				  putty-registry.reg (Registry of PuTTY configurations. regedit /e putty-registry.reg HKEY_CURRENT_USER\Software\Simontatham)
				  prd_svc_caps.ppk (Private key to authenticate the Dashboard with remote UNIX hosts)
				  AIX.jpg (Icon for UNIX Operator Menu button)
				  Windows (Icon for Windows Operator Menu button)
.FUNCTIONALITY
	- To perform health check tasks for both Windows and UNIX servers
	- To launch Operator Menu for administrative tasks
#>
#Get and set path
Set-Location $(Split-Path $MyInvocation.MyCommand.Path)
$Global:Path = $(Split-Path $MyInvocation.MyCommand.Path)

#region Global Options
#Configuration File
$ConfigFile = $Global:Path + "\Dashboard.xml"
$Global:Config = [xml](Get-Content $ConfigFile)
#XAML Form
$Global:XAMLFile = $Global:Path + "\Dashboard.xaml"
#Check status functions
$Global:FunctionFile = $Global:Path + "\Check-Status.ps1"
#Path of Windows Operator's Memu
$Global:WindowsOperMenu = "D:\CAPS\App\OperConsole\OperConsolePRD.ps1"
#Facilities to write the Windows Event Logs
$Global:logSource = "Dashboard"
$Global:logUser = whoami
#Path of PuTTY tools
$Global:Plink = $Global:Path + "\plink.exe"
$Global:PuTTY = $Global:Path + "\putty.exe"
#Path of private key for connecting UNIX hosts
$Global:Key = $Global:Path + "\prd_svc_caps.ppk"
#IPs of UNIX hosts
$Global:UNIX = @(
	"192.168.192.168",
	"10.10.10.10",
	"10.10.10.20"
)
#Path of PuTTY config registry
$Global:PuTTYRegistry = $Global:Path + "\putty-registry.reg"
#Flag to indicate the script is under production or development ($True or $False)
$Global:Production = $True
#endregion

#region Synchronized Collections
$uiHash = [hashtable]::Synchronized(@{})
$runspaceHash = [hashtable]::Synchronized(@{})
$jobs = [system.collections.arraylist]::Synchronized((New-Object System.Collections.ArrayList))
$jobCleanup = [hashtable]::Synchronized(@{})
$Global:statusarray = New-Object System.Collections.ObjectModel.ObservableCollection[object]
#endregion

#region Load Required Assemblies and DLLs
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
#endregion

#region Load XAML into PowerShell
[XML]$xaml = Get-Content $XAMLFile
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$uiHash.Window = [Windows.Markup.XamlReader]::Load($reader)
#endregion

Function Cache-SSHKeys {
	Foreach ($Server in $Global:UNIX) {
		If ($Server -eq "192.168.21.11") {
			$User = "admin"
		} Else {
			$User = "root"
		}
		Invoke-Expression -Command "echo y | $Global:Plink -ssh -l $User -i $Global:Key $Server exit"
	}
}

Function Touch-File
{
    $file = $args[0]
    If ($file -eq $null) {
        throw "No filename supplied"
    }

    If (Test-Path $file) {
        (Get-ChildItem $file).LastWriteTime = Get-Date
    } Else {
        echo $null > $file
    }
}

#Window Load Events
$uiHash.Window.Add_SourceInitialized({

    Write-EventLog -logname CAPS -Source $Global:logSource -eventID 1000 -entrytype Information -Message "[$Global:logUser] Start Health Check Dashboard"

	$usagelog = $Global:Path + "\usage.log"
	
	Invoke-Command -ScriptBlock {
		param($registry)
		& 'C:\Windows\System32\Reg.exe' import $registry
	} -ArgumentList($Global:PuTTYRegistry)
	
	If (!(Test-Path -Path $usagelog)) {
		Write-Host "no usage log"
		Touch-File($usagelog)
		Cache-SSHKeys
		$Global:LogUser | Out-File $usagelog -Append
	} Else {
		Write-Host "has usage log"
		$usage = Select-String -SimpleMatch $Global:LogUser $usagelog
		$a = $usage | Measure-Object -Line
		If ($a.Lines -eq 0) {
			Write-Host "has name"
			Cache-SSHKeys
			$Global:LogUser | Out-File $usagelog -Append
		}
	}

	$ID = 0
	Foreach ($config in $Global:config.CAPS.Healthcheck) {
		[string[]]$ServerName = @()
		Foreach ($serverlist in $config.ServerList) {
			$ServerName += $serverlist.server
		}
		[string[]]$Keywords = @()
		[string]$keywordType = $config.Check.Keyword.Type
		Foreach ($keyword in $config.Check.Keyword.Item) {
			$Keywords += $keyword
		}
		$CMD = "&" + $config.Check.Command
		Foreach ($server in $ServerName) {
			If ($config.Check.Method -eq "ScheduledTask") {
				Foreach ($keyword in $config.Check.Keyword.Item) {
					$ID++
					$statusObject = Select-Object -InputObject "" ID, Platform, Server, Application, Component, Status, Remark, Notes, CheckMethod, Command, KeywordType, Keywords
					$statusObject.ID = $ID
					$statusObject.Platform = $config.Platform
					$statusObject.Server = $server
					$statusObject.Application = $config.Application
					$statusObject.Component = $config.Component
					$statusObject.Status = "Pending health check"
					$statusObject.Remark = "Task: "+$keyword
					$statusObject.Notes = ""
					$statusObject.CheckMethod = $config.Check.Method
					$statusObject.Command = $CMD
					$statusObject.KeywordType = $KeywordType
					$statusObject.Keywords = $keyword
					$Global:statusarray += $statusObject
				}
			} else {
				$ID++
				$statusObject = Select-Object -InputObject "" ID, Platform, Server, Application, Component, Status, Remark, Notes, CheckMethod, Command, KeywordType, Keywords
				$statusObject.ID = $ID
				$statusObject.Platform = $config.Platform
				$statusObject.Server = $server
				$statusObject.Application = $config.Application
				$statusObject.Component = $config.Component
				$statusObject.Status = "Pending health check"
				$statusObject.Remark = ""
				$statusObject.Notes = ""
				$statusObject.CheckMethod = $config.Check.Method
				$statusObject.Command = $CMD
				$statusObject.KeywordType = $KeywordType
				$statusObject.Keywords = $Keywords
				$Global:statusarray += $statusObject
			}
		}
	}
	
	$Global:TaskCount = $ID
	$uiHash.StatusDataGrid.ItemsSource = $Global:statusarray
})

$uiHash.Window.Add_Closed({
    Write-EventLog -logname CAPS -Source $logSource -eventID 1000 -entrytype Information -Message "[$logUser] Exit Health Check Dashboard"
})

#region Connect to all controls
$uiHash.BusyIndicator = $uiHash.Window.FindName('BusyIndicator')
$uiHash.ProgressBar = $uiHash.Window.FindName('ProgressBar')
$uiHash.RefreshButton = $uiHash.Window.FindName('RefreshButton')
$uiHash.WindowsOperMenuButton = $uiHash.Window.FindName('WindowsOperMenuButton')
$uiHash.UNIXOperMenuButton = $uiHash.Window.FindName('UNIXOperMenuButton')
$uiHash.ExitButton = $uiHash.Window.FindName('ExitButton')
$uiHash.StatusTextBox = $uiHash.Window.FindName("StatusTextBox")
$uiHash.StatusDataGrid = $uiHash.Window.FindName('StatusDataGrid')
$uiHash.DetailsButton = $uiHash.Window.FindName('DetailsButton')
#endregion

function Refresh-Status {
	Write-EventLog -logname CAPS -Source $Global:logSource -eventID 1000 -entrytype Information -Message "[$Global:logUser] Check overall system status"

	$uiHash.ProgressBar.Maximum = $Global:TaskCount
	$uiHash.StatusTextBox.Text = "Running health check tasks... Please Wait"
	Foreach ($object in $Global:statusarray) {
		$object.Status = "Pending health check"
	}
	$uiHash.StatusDataGrid.Items.Refresh()
	[Float]$uiHash.ProgressBar.Value = 0
	$uiHash.StartTime = (Get-Date)
	$ScriptBlock = {
		Param (
			$object,
			$Global:statusarray,
			$uiHash,
			$FunctionFile
		)
		$Global:statusarray[$object.ID-1].Status = "Performing health check"
		$uiHash.StatusDataGrid.Dispatcher.Invoke("Render",[action]{
            $uiHash.StatusDataGrid.Items.Refresh()
        })
		
		. $FunctionFile
		
		$Result = @(Check-Status -Task $object)
		$Global:statusarray[$object.ID-1].Status = $Result.Status
		$Global:statusarray[$object.ID-1].Notes = $Result.Notes

		$uiHash.StatusDataGrid.Dispatcher.Invoke("Render",[action]{
            $uiHash.StatusDataGrid.Items.Refresh()
        })
		$uiHash.ProgressBar.Dispatcher.Invoke("Normal",[action]{
            $uiHash.ProgressBar.value++  
        })
        $uiHash.Window.Dispatcher.Invoke("Normal",[action]{
            If ($uiHash.ProgressBar.value -eq $uiHash.ProgressBar.Maximum) {
				$End = New-Timespan $uihash.StartTime (Get-Date)
				$uiHash.StatusTextBox.Text = ("Completed in {0}" -f $End)
            }
        })
	}

    $sessionstate = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
    $runspaceHash.runspacepool = [runspacefactory]::CreateRunspacePool(1, 10, $sessionstate, $Host)
    $runspaceHash.runspacepool.Open()
		
	. $FunctionFile

	ForEach ($object in $Global:statusarray) {
		If ($object.Application -eq "Metro Mirror") {
			$Global:statusarray[$object.ID-1].Status = "Performing health check"
			$uiHash.StatusDataGrid.Dispatcher.Invoke("Render",[action]{
				$uiHash.StatusDataGrid.Items.Refresh()
			})
			$Result = Check-MetroMirror -ID $object.ID -Command $object.Command
			$Global:statusarray[$object.ID-1].Status = $Result[0]
			$Global:statusarray[$object.ID-1].Notes = $Result[1]
			$uiHash.ProgressBar.value++
			$uiHash.StatusDataGrid.Dispatcher.Invoke("Render",[action]{
				$uiHash.StatusDataGrid.Items.Refresh()
			})
		} Else {
			$powershell = [powershell]::Create().AddScript($ScriptBlock).AddArgument($object).AddArgument($Global:statusarray).AddArgument($uiHash).AddArgument($FunctionFile)
			$powershell.RunspacePool = $runspaceHash.runspacepool
            $temp = "" | Select-Object PowerShell,Runspace,Task
            $Temp.Task = $object.ID
            $temp.PowerShell = $powershell
            $temp.Runspace = $powershell.BeginInvoke()
            $jobs.Add($temp) | Out-Null 
		}
    }
	$uiHash.DetailsButton.IsEnabled = "True"
}

$uiHash.RefreshButton.add_Click({
    Refresh-Status
})

$uiHash.WindowsOperMenuButton.add_Click({
	Write-EventLog -logname CAPS -Source $Global:logSource -eventID 1000 -entrytype Information -Message "[$Global:logUser] Launch Windows Operator Menu"
    Start-Process powershell -WindowStyle Hidden -verb runas $Global:windowsopermenu
})

$uiHash.UNIXOperMenuButton.add_Click({
	Write-EventLog -logname CAPS -Source $Global:logSource -eventID 1000 -entrytype Information -Message "[$Global:logUser] Launch UNIX Operator Menu"

	$UserID = (($Global:logUser).split("\"))[-1].trim()
	
	Invoke-Command -ScriptBlock {
		param($putty,$user)
		& $putty -l $user -load CAPS
	} -ArgumentList $Global:PuTTY, $UserID
})

$uiHash.DetailsButton.add_Click({
	If ($uiHash.StatusDataGrid.RowDetailsVisibilityMode -eq "VisibleWhenSelected") {
		$uiHash.StatusDataGrid.RowDetailsVisibilityMode = "Collapsed"
		$uiHash.StatusDataGrid.Items.Refresh()
		$uiHash.DetailsButton.Content = "Show Details"
	} ElseIf ($uiHash.StatusDataGrid.RowDetailsVisibilityMode -eq "Collapsed") {
		$uiHash.StatusDataGrid.RowDetailsVisibilityMode="VisibleWhenSelected"
		$uiHash.StatusDataGrid.Items.Refresh()
		$uiHash.DetailsButton.Content = "Hide Details"
	}
})

$uiHash.ExitButton.add_Click({
	If ($Global:Production -eq $True) {
		Invoke-Command -ScriptBlock {
			Logoff;exit
		}
	}
})

$uiHash.Window.Add_Closing({
	If ($Global:Production -eq $True) {
		$_.Cancel = $true
	}
})

#region Background runspace to clean up jobs
$jobCleanup.Flag = $True
$newRunspace =[runspacefactory]::CreateRunspace()
$newRunspace.ApartmentState = "STA"
$newRunspace.ThreadOptions = "ReuseThread"          
$newRunspace.Open()
$newRunspace.SessionStateProxy.SetVariable("uiHash",$uiHash)          
$newRunspace.SessionStateProxy.SetVariable("jobCleanup",$jobCleanup)     
$newRunspace.SessionStateProxy.SetVariable("jobs",$jobs) 
$jobCleanup.PowerShell = [PowerShell]::Create().AddScript({
    Do {
        Foreach($runspace in $jobs) {
            If ($runspace.Runspace.isCompleted) {
                $runspace.powershell.EndInvoke($runspace.Runspace) | Out-Null
                $runspace.powershell.dispose()
                $runspace.Runspace = $null
                $runspace.powershell = $null               
            } 
        }
        $temphash = $jobs.clone()
        $temphash | Where {
            $_.runspace -eq $Null
        } | ForEach {
            Write-Host ("Removing {0}" -f $_.computer)
            $jobs.remove($_)
        }        
        Start-Sleep -Seconds 1     
    } while ($jobCleanup.Flag)
})
$jobCleanup.PowerShell.Runspace = $newRunspace
$jobCleanup.Thread = $jobCleanup.PowerShell.BeginInvoke()

$uiHash.Window.ShowDialog() | out-null
