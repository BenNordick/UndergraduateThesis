Function Import-Sam {
    Param (
	    [string]$SamFile,
		[switch]$IncludeSamLine
    )
    gc $SamFile | % {
	    $alignment = New-Object psobject
	    $fields = $_ -split "`t"
    	$alignment | Add-Member NoteProperty 'Name' $fields[0]
    	$alignment | Add-Member NoteProperty 'Flags' ([int]$fields[1])
    	$alignment | Add-Member NoteProperty 'MasterName' $fields[2]
    	$alignment | Add-Member NoteProperty 'StartPos' -Value ([int]$fields[3])
    	$alignment | Add-Member NoteProperty 'MapQuality' -Value ([int]$fields[4])
    	$alignment | Add-Member NoteProperty 'Cigar' $fields[5]
    	$alignment | Add-Member NoteProperty 'MateName' $fields[6]
    	$alignment | Add-Member NoteProperty 'MatePos' -Value ([int]$fields[7])
    	$alignment | Add-Member NoteProperty 'PairedRunLength' -Value ([int]$fields[8])
    	$alignment | Add-Member NoteProperty 'Sequence' $fields[9]
    	$alignment | Add-Member NoteProperty 'ReadQuality' $fields[10]
    	$alignment | Add-Member NoteProperty 'Tags' (($fields | select -Skip 11) -join ' ')
		If ($IncludeSamLine) { $alignment | Add-Member NoteProperty 'SamLine' $_ }
    	$alignment
    }
}
Function Export-Sam {
	Param (
		[psobject[]]$InputAlignments,
		[string]$SamFile
	)
	If ($InputAlignments[0].SamLine) {
		$InputAlignments | select -ExpandProperty SamLine | Out-File $SamFile -Encoding ASCII
	} Else {
		$InputAlignments | % {
			($_.Name, $_.Flags, $_.MasterName, $_.StartPos, $_.MapQuality, $_.Cigar, $_.MateName, $_.MatePos, $_.PairedRunLength, $_.Sequence, $_.ReadQuality, $_.Tags) -join "`t"
		} | Out-File $SamFile -Encoding ASCII
	}
}
Function Get-AlignmentCounts {
	[CmdletBinding()] Param (
		[psobject[]]$InputAlignments,
		[int]$SequenceLength,
		[switch]$Individual
	)
	$counts = [array]::CreateInstance([int], $SequenceLength + 1)
	$InputAlignments | % {
		$masterpos = $_.StartPos
		$cigar = $_.Cigar
		$individualcount = $null
		If ($Individual) { $individualcount = [array]::CreateInstance([byte], $SequenceLength + 1) }
		[regex]::Matches($cigar, '(\d+[MIDNSHP=X])*')[0].Groups[1].Captures | % {
			$code = $cigar.Substring($_.Index + $_.Length - 1, 1)
			$runlen = [int]($cigar.Substring($_.Index, $_.Length - 1))
			If ('M=X'.Contains($code)) {
				$masterpos..($masterpos + $runlen - 1) | % { $counts[$_]++ }
				If ($Individual) { $masterpos..($masterpos + $runlen - 1) | % { $individualcount[$_] = 1 } }
			}
			If ('MDN=X'.Contains($code)) { $masterpos += $runlen }
		}
		If ($Individual) { $_ | Add-Member NoteProperty 'BasePresence' $individualcount -Force }
	}
	$counts
}
Function Get-AlignmentCigar {
	Param (
		[string]$MasterSequence,
		[string]$Sequence
	)
	Set-Variable -Name cigar, delMaster, delSequence -Option AllScope
	$cigar = ''
	$delMaster = $false
	$delSequence = $false
	$runLength = 0
	$startPos = -1
	Function AddCurrentRun ($AtEnd) {
		If (!$delSequence -or !$AtEnd) { $cigar += [string]$runLength }
		If ($delMaster -and $AtEnd) {
			$cigar += 'S'
		} ElseIf ($delMaster) {
			$cigar += 'I'
		} ElseIf ($delSequence) {
			If (!$AtEnd) { $cigar += 'D' }
		} Else {
			$cigar += 'M'
		}
	}
	For ($i = 0; $i -lt $MasterSequence.Length; $i++) {
		$masterGone = ($MasterSequence[$i] -eq [char]'-')
		$sequenceGone = ($Sequence[$i] -eq [char]'-')
		If (!$sequenceGone -and $startPos -lt 0) { $startPos = $i }
		If (($runLength -gt 0) -and ($delMaster -ne $masterGone -or $delSequence -ne $sequenceGone)) {
			AddCurrentRun ($cigar.Length -eq 0)
			$runLength = 1
		} Else {
			$runLength++;
		}
		$delMaster = $masterGone
		$delSequence = $sequenceGone
	}
	AddCurrentRun $true
	$result = New-Object psobject
	$result | Add-Member NoteProperty 'Cigar' $cigar
	$result | Add-Member NoteProperty 'StartPos' ($startPos + 1)
	$result
}
Function Align-Sam {
	Param (
		[psobject[]]$UnalignedSams,
		[string]$MasterFastaPath,
		[string]$MasterName,
		[string]$ClustalPath
	)
	$fasta = (gc $MasterFastaPath | select -Skip 1) -join ''
	$recordsProcessed = 0
	$UnalignedSams | % {
		Write-Progress 'Aligning sequences' -Status "Aligning #$($recordsProcessed + 1) of $($UnalignedSams.Count)" -PercentComplete (($recordsProcessed / $UnalignedSams.Count) * 100)
		">$MasterName`r`n$fasta`r`n>$($_.Name)`r`n$($_.Sequence)" | Out-File ".\tmp$recordsProcessed.fasta" -Encoding ASCII
		Start-Process $ClustalPath -Argument ("-i tmp$recordsProcessed.fasta -o tmp.fasta$recordsProcessed.out --force") -WorkingDirectory (pwd).Path -Wait -NoNewWindow
		del ".\tmp$recordsProcessed.fasta"
		$gettingMaster = $false
		$alignedMaster = ''
		$alignedSequence = ''
		gc ".\tmp.fasta$recordsProcessed.out" | % {
			If ($_.StartsWith('>')) {
				$gettingMaster = !$gettingMaster
			} Else {
				If ($gettingMaster) {
					$alignedMaster += $_
				} Else {
					$alignedSequence += $_
				}
			}
		}
		del ".\tmp.fasta$recordsProcessed.out"
		$alignment = Get-AlignmentCigar -MasterSequence $alignedMaster -Sequence $alignedSequence
		$record = New-Object psobject
		$record | Add-Member NoteProperty 'StartPos' $alignment.StartPos
		$record | Add-Member NoteProperty 'SamLine' "$($_.Name)`t0`t$MasterName`t$($alignment.StartPos)`t255`t$($alignment.Cigar)`t*`t0`t0`t$($_.Sequence)`t*`t$($_.Tags)"
		$record
		$recordsProcessed++
	}
	Write-Progress 'Aligning sequences' -Completed
}
Function Get-AlignmentSequence {
	Param (
		[psobject]$InputAlignment,
		[int]$SequenceLength,
		[switch]$AddNote
	)
	$chars = [array]::CreateInstance([char], $SequenceLength)
	$cigar = $InputAlignment.Cigar
	$masterpos = $InputAlignment.StartPos - 1
	$seqpos = 0
	$seq = $InputAlignment.Sequence
	0..$masterpos | % { $chars[$_] = '-' }
	[regex]::Matches($cigar, '(\d+[MIDNSHP=X])*')[0].Groups[1].Captures | % {
		$code = $cigar.Substring($_.Index + $_.Length - 1, 1)
		$runlen = [int]($cigar.Substring($_.Index, $_.Length - 1))
		If ('M=X'.Contains($code)) {
			1..$runlen | % { $chars[$masterpos + $_ - 1] = $seq[$seqpos + $_ - 1] }
			$seqpos += $runlen
			$masterpos += $runlen
		} ElseIf ('SI'.Contains($code)) {
			$seqpos += $runlen
		} ElseIf ('DN'.Contains($code)) {
			1..$runlen | % { $chars[$masterpos + $_ - 1] = '-' }
			$masterpos += $runlen
		}
	}
	$masterpos..($SequenceLength - 1) | % { $chars[$_] = '-' }
	$alignedFasta = [string]::new($chars)
	If ($AddNote) {
		$InputAlignment | Add-Member NoteProperty 'AlignedFasta' $alignedFasta -Force
	} Else {
		$alignedFasta
	}
}
Function Test-StretchPresent {
	[CmdletBinding()] Param (
		[Parameter(ValueFromPipelineByPropertyName='BasePresence')][byte[]]$BasePresence,
		[int]$StartPos,
		[int]$EndPos,
		[int]$PercentRequired = 80
	)
	$present = 0
	$StartPos..$EndPos | % { If ($BasePresence[$_]) { $present++ } }
	($present / ($EndPos - $StartPos + 1)) -ge ($PercentRequired / 100)
}
Function Measure-AlignmentQuality {
	[CmdletBinding()] Param (
		[Parameter(ValueFromPipeline)][psobject]$Alignment,
		[int]$SequenceLength,
		[switch]$AddNote
	)
	$instructions = [regex]::Matches($Alignment.Cigar, '(\d+[MIDNSHP=X])*')[0].Groups[1].Captures.Count
	If (!$Alignment.BasePresence) { Get-AlignmentCounts -InputAlignments $Alignment -SequenceLength $SequenceLength -Individual | Out-Null }
	$bases = $Alignment.BasePresence | measure -Sum | select -ExpandProperty Sum
	$quality = [Math]::Log($bases / $instructions)
	If ($AddNote) { $Alignment | Add-Member NoteProperty 'LnQQ' $quality -Force }
	$quality
}
Function Add-SnpFingerprint {
	[CmdletBinding()] Param (
		[Parameter(ValueFromPipeline)][psobject]$Alignment,
		[int[]]$SnpPositions,
		[string]$PropertyName = 'SnpFingerprint'
	)
	$fingerprint = ($SnpPositions | % { $Alignment.AlignedFasta[$_ - 1] }) -join ''
	$Alignment | Add-Member NoteProperty $PropertyName $fingerprint -Force
}