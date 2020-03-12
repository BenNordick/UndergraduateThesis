Param (
	[string]$SamFile,
	[string]$Consensus,
	[int[]]$IgnorePos
)
. .\psdna.ps1
Write-Progress 'Calculating read error rate' -Status 'Loading SAM'
$sams = Import-Sam -SamFile $SamFile
Write-Progress 'Calculating read error rate' -Status 'Expanding alignments'
$sams | % { Get-AlignmentSequence -InputAlignment $_ -SequenceLength ($Consensus.Length) -AddNote }
$allBases = [long]0
$wrongBases = [long]0
0..($Consensus.Length - 1) | ? { -not (($_ + 1) -in $IgnorePos) } | % {
	Write-Progress 'Calculating read error rate' -Status 'Comparing reads' -PercentComplete ($_ / $Consensus.Length * 100)
	$pos = $_
	$sams | % {
		If ($_.AlignedFasta[$pos] -ne '-') {
			$allBases++
			If ($_.AlignedFasta[$pos] -ne $Consensus[$pos]) { $wrongBases++ }
		}
	}
}
Write-Progress 'Calculating read error rate' -Completed
$wrongBases / $allBases