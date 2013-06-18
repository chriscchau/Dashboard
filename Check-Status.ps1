function Create-Details {
	[CmdletBinding()]
	param(
		[string[]]$Message,
		[string[]]$Keywords
	)
	BEGIN {
		$detailsHeader = "<Section xmlns=""http://schemas.microsoft.com/winfx/2006/xaml/presentation"" xml:space=""preserve"" TextAlignment=""Left"" LineHeight=""Auto"" IsHyphenationEnabled=""False"" xml:lang=""en-us"" FlowDirection=""LeftToRight"" NumberSubstitution.CultureSource=""User"" NumberSubstitution.Substitution=""AsCulture"" FontFamily=""Lucida Console"" FontStyle=""Normal"" FontWeight=""Normal"" FontStretch=""Normal"" FontSize=""10"" Foreground=""#FF000000"" Typography.StandardLigatures=""True"" Typography.ContextualLigatures=""True"" Typography.DiscretionaryLigatures=""False"" Typography.HistoricalLigatures=""False"" Typography.AnnotationAlternates=""0"" Typography.ContextualAlternates=""True"" Typography.HistoricalForms=""False"" Typography.Kerning=""True"" Typography.CapitalSpacing=""False"" Typography.CaseSensitiveForms=""False"" Typography.StylisticSet1=""False"" Typography.StylisticSet2=""False"" Typography.StylisticSet3=""False"" Typography.StylisticSet4=""False"" Typography.StylisticSet5=""False"" Typography.StylisticSet6=""False"" Typography.StylisticSet7=""False"" Typography.StylisticSet8=""False"" Typography.StylisticSet9=""False"" Typography.StylisticSet10=""False"" Typography.StylisticSet11=""False"" Typography.StylisticSet12=""False"" Typography.StylisticSet13=""False"" Typography.StylisticSet14=""False"" Typography.StylisticSet15=""False"" Typography.StylisticSet16=""False"" Typography.StylisticSet17=""False"" Typography.StylisticSet18=""False"" Typography.StylisticSet19=""False"" Typography.StylisticSet20=""False"" Typography.Fraction=""Normal"" Typography.SlashedZero=""False"" Typography.MathematicalGreek=""False"" Typography.EastAsianExpertForms=""False"" Typography.Variants=""Normal"" Typography.Capitals=""Normal"" Typography.NumeralStyle=""Normal"" Typography.NumeralAlignment=""Normal"" Typography.EastAsianWidths=""Normal"" Typography.EastAsianLanguage=""Normal"" Typography.StandardSwashes=""0"" Typography.ContextualSwashes=""0"" Typography.StylisticAlternates=""0""><Paragraph>"
		$detailsFooter = "</Paragraph></Section>"
		$detailsStart = "<Run>"
		$detailsErrorStart = "<Run Foreground=""Red"">"
		$detailsNormalStart = "<Run Foreground=""Green"">"
		$detailsStop = "</Run>"
		$detailsNewline = "<LineBreak />"
	}
	PROCESS {
		$Format = "PlainText"
		If ($Format -eq "XAML") {
		$details = $detailsHeader
		Foreach ($line in $Message) {
			$hit = $False
            If ($Keywords.Count -ge "1") {
			    Foreach ($keyword in $Keywords) {
				    If ($line -cmatch $keyword) {
					    $hit = $True
				    }
			    }
            }
			If ($hit -eq $False) {
				$details = $details + $detailsStart + $line + $detailsStop + $detailsNewline
			} Else {
				$details = $details + $detailsErrorStart + $line + $detailsStop + $detailsNewline
			}
		}
		$details = $details + $detailsFooter
		} Elseif ($Format -eq "PlainText") {
			$details = ""
			Foreach ($line in $Message) {
				$details = $details+$line+[char]13+[char]10
			}
		}
	}
	END {
		Return $details
	}
}

function Check-MetroMirror {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$Command
	)
	BEGIN {
		$ScriptBlock = $executioncontext.InvokeCommand.NewScriptBlock($Command)
	}
	PROCESS {
		$Return = Invoke-Command -ScriptBlock $ScriptBlock

		$SynStatus = (($Return | Where-Object {$_ -match "state"}).split(":"))[-1].trim()
		
		If ($SynStatus -eq "consistent_synchronized") {
			$Status = "Normal"
		} Else {
			$Status = "Error"
		}
		
		If ($KeywordType -eq "Error") {
			$Notes = Create-Details -Message $Return -Keywords $Keywords
		} Else {
			$Notes = Create-Details -Message $Return
		}
	}
	END {
		Return $Status, $Notes
	}
}

function Run-Command {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$Platform,
		[string]$ServerName,
		[string]$Command,
		[string]$KeywordType,
		[string[]]$Keywords
	)
	BEGIN {
		$ScriptBlock = $executioncontext.InvokeCommand.NewScriptBlock($Command)
		
        $normal = @{}
		Foreach ($e in $Keywords) {
			$normal.Add($e,"")
		}
	}
	PROCESS {
		If ($Platform -eq "UNIX" -OR $ServerName -eq "") {
			$Return = Invoke-Command -ScriptBlock $ScriptBlock
		} Else {
			$Return = Invoke-Command -ComputerName $ServerName -ScriptBlock $ScriptBlock
		}
		
		Switch ($KeywordType) {
			"Error" {
                Foreach ($e in $Keywords) {
		            $normal.Set_Item($e,$True)
		        }
				Foreach ($line in $Return) {
					Foreach ($e in $Keywords) {
						If ($line -cmatch $e) {
							$normal.Set_Item($e,$False)
						}
					}
				}
			}
			"Normal" {
                Foreach ($e in $Keywords) {
		            $normal.Set_Item($e,$False)
		        }
				Foreach ($line in $Return) {
					Foreach ($e in $Keywords) {
						If ($line -cmatch $e) {
							$normal.Set_Item($e,$True)
						}
					}
				}
			}
		}
			
		If ($normal.ContainsValue($False)) {
			$Status = "Error"
		} Else {
			$Status = "Normal"
		}
		
		$Message = $Return | Out-String
		If ($Message -eq "") {
			$Status = "Error"
		}
#		If ($KeywordType -eq "Error") {
#			$Notes = Create-Details -Message $Return -Keywords $Keywords
#			Write-Host $Notes
#		} Else {
			$Notes = Create-Details -Message $Return
#			Write-Host $Notes
#		}
	}
	END {
		Return $Status, $Notes
	}
}

function Check-Website {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$ServerName,
		[string]$WebsiteName
	)
	BEGIN {
		$WebsitePattern = "*"+$WebsiteName+"*"
	}
	PROCESS {
		$Return = invoke-command -ComputerName $ServerName -ScriptBlock {
			param($website)
			Import-Module -Name webadministration
			Get-Website -Name $website
		} -ArgumentList $WebsitePattern
		
		$Status = $Return.State
		$Message = $Return | Out-String
		If ($Message -eq "") {
			$Status = "Error"
		}

		If ($Status -ne "Started") {
			$Notes = Create-Details -Message $Message -Keywords $WebsiteName
		} Else {
			$Notes = Create-Details -Message $Message
		}
	}
	END {
		Return $Status, $Notes
	}
}

function Check-Service {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$ServerName,
		[string]$ServiceName
	)
	BEGIN {
	}
	PROCESS {
		$Return = Invoke-Command -ComputerName $ServerName -ScriptBlock {
			param($service)
			Get-Service -DisplayName $service
		} -ArgumentList $ServiceName
		
		$Status = $Return.Status
		$Message = $Return | Out-String
		If ($Message -eq "") {
			$Status = "Error"
		}
		
		If ($Status -ne "Running") {
			$Notes = Create-Details -Message $Message -Keywords $ServiceName
		} Else {
			$Notes = Create-Details -Message $Message
		}
	}
	END {
		Return $Status, $Notes
	}
}

function Check-Cluster {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$ClusterName
	)
	BEGIN {
		Import-Module FailoverClusters
	}
	PROCESS {
		$Return = Get-ClusterResource -Cluster $ClusterName
		
		$Status = "Normal"
		foreach ($item in $Return)
		{
			If ($item.State -eq "Offline") {
				$Status = "Error"
			}
		}
		
		$Message = $Return | Out-String
		If ($Status -eq "Error") {
				$Notes = Create-Details -Message $Message -Keywords ["Offline"]
			} Else {
				$Notes = Create-Details -Message $Message
		}
	}
	END {
		Return $Status, $Notes
	}
}

function Check-Process {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$ServerName,
		[string]$ProcessName
	)
	BEGIN {
	}
	PROCESS {
		$Return = Invoke-Command -ComputerName $ServerName -ScriptBlock {
			param($process)
			Get-Process | Where-Object -filter { $_.ProcessName -eq $process }
		} -ArgumentList $ProcessName
		
		$Message = $Return | Out-String
		If ($Message -eq "") {
			$Status = "Not exist"
			$Notes = Create-Details -Message $Message -Keywords $ProcessName
		} Else {
			$Status = "Exists"
			$Notes = Create-Details -Message $Message
		}
	}
	END {
		Return $Status, $Notes
	}
}

function Check-ScheduledTask {
	[CmdletBinding()]
	param(
		[Int]$ID,
		[string]$ServerName,
		[string]$TaskName
	)
	BEGIN {
	}
	PROCESS {
		$Return = Invoke-Command -ComputerName $ServerName -ScriptBlock {
			param($t)
			schtasks /query /FO LIST /V /TN $t
		} -ArgumentList $TaskName

		$TaskStatus = (($Return | Where-Object {$_ -match "Status"}).split(":"))[-1].trim()
		$LastResult = (($Return | Where-Object {$_ -match "Last Result"}).split(":"))[-1].trim()
		
		If ($TaskStatus -eq "Ready" -OR $TaskStatus -eq "Running") {
			$TS = $True
		} Else {
			$TS = $False
		}
		
		If ($TS -eq $True -AND $LastResult -eq "0") {
			$Status = "Normal"
		} Else {
			$Status = "Error"
		}

		$Message = $Return | Out-String
		If ($Status -eq "Error") {
			$Notes = Create-Details -Message $Message -Keywords $TaskName
		} Else {
			$Notes = Create-Details -Message $Message
		}
	}
	END {
		Return $Status, $Notes
	}
}

function Check-Status {
	Param (
		$Task
	)

	If ($Task.CheckMethod -eq "Process") {
		$Result = Check-Process -ID $Task.ID -ServerName $Task.Server -ProcessName $Task.Keywords[0]
	}
	If ($Task.CheckMethod -eq "CLI" -AND $Task.Application -ne "Metro Mirror") {
		$Result = Run-Command -ID $Task.ID -Platform $Task.Platform -ServerName $Task.Server -Command $Task.Command -KeywordType $Task.KeywordType -Keywords $Task.Keywords
	}
	If ($Task.CheckMethod -eq "Website") {
		$Result = Check-Website -ID $Task.ID -ServerName $Task.Server -WebsiteName $Task.Keywords[0]
	}
	If ($Task.CheckMethod -eq "Service") {
		$Result = Check-Service -ID $Task.ID -ServerName $Task.Server -ServiceName $Task.Keywords[0]
	}
	If ($Task.CheckMethod -eq "Cluster") {
		$Result = Check-Cluster -ID $Task.ID -ClusterName $Task.Keywords[0]
	}
	If ($Task.CheckMethod -eq "ScheduledTask") {
		$Result = Check-ScheduledTask -ID $Task.ID -ServerName $Task.Server -TaskName $Task.Keywords
	}
	
	$State = "" | Select Status,Notes
	$State.Status = $Result[0]
	$State.Notes = $Result[1]
	Write-Output $State
}