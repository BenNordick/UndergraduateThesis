Function Test-ExonPresent {
	Param (
		[psobject]$InputAlignment,
		[int]$StartPos,
		[int]$EndPos,
		[int]$Purity
	)
	$_ | Test-StretchPresent -StartPos $StartPos -EndPos $EndPos -PercentRequired $Purity
}
Function Test-ExonAbsent {
	Param (
		[psobject]$InputAlignment,
		[int]$StartPos,
		[int]$EndPos,
		[int]$Purity
	)
	$margin = ($EndPos - $StartPos + 1) * 0.2
	$runGone = -not ($_ | Test-StretchPresent -StartPos $StartPos -EndPos $EndPos -PercentRequired (100 - $Purity + 1))
	$leftPresent = ($_ | Test-StretchPresent -StartPos ($StartPos - $margin) -EndPos $StartPos -PercentRequired 50)
	$rightPresent = ($_ | Test-StretchPresent -StartPos $EndPos -EndPos ($EndPos + $margin) -PercentRequired 50)
	$runGone -and $leftPresent -and $rightPresent
}
Function Measure-ExonPresence {
	Param (
		[string]$SourceSam,
		[int]$StartPos,
		[int]$EndPos,
		[string]$OutFile,
		[int]$MinPurity = 50,
		[int]$MaxPurity = 100
	)
	Write-Progress 'Testing exon presence' -Status 'Loading SAM'
	$sams = Import-Sam -SamFile $SourceSam | ? { $_.StartPos -le $StartPos }
	Write-Progress 'Testing exon presence' -Status 'Counting base presence'
	$counts = Get-AlignmentCounts $sams -SequenceLength 5000 -Individual
	'Purity%,Present,Absent,AllQualifying,%Absent' | Out-File $OutFile -Force
	$MinPurity..$MaxPurity | % {
		Write-Progress 'Testing exon presence' -Status "Checking at $_% purity" -PercentComplete (100 * ($_ - $MinPurity) / ($MaxPurity - $MinPurity))
		$purity = $_
		$testArgs = @{'StartPos' = $StartPos; 'EndPos' = $EndPos; 'Purity' = $purity}
		$present = ($sams | ? { $_ | Test-ExonPresent -InputAlignment $_ @testArgs }).Count
		$absent = ($sams | ? { Test-ExonAbsent -InputAlignment $_ @testArgs }).Count
		$allpure = $present + $absent
		$pctAbsent = $absent / $allpure * 100
		"$_,$present,$absent,$allpure,$pctAbsent"
	} | Out-File $OutFile -Append
}