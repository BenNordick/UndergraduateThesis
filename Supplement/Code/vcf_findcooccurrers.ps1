Param (
	[string]$ScanVcfFile,
	[string]$SourceVcfFile,
	[int]$MinCooccurRate = 95,
	[switch]$SkipFirstLine
)
$known = Get-VariantCalls -VcfFile $SourceVcfFile
$possible = Get-VariantCalls -VcfFile $ScanVcfFile -AddVcfLine
0..($possible.Snps - 1) | % {
	$s = $_
	$cooccurrences = 0
	0..($possible.Chromosomes - 1) | % {
		If ($possible.Alleles[$_, $s] -eq $known.Alleles[$_, 0]) { $cooccurrences++ }
	}
	$cooccurPct = ($cooccurrences / $possible.Chromosomes) * 100
	If ($cooccurPct -ge $MinCooccurRate) { 
		$info = $possible.SnpInfo[$_]
		$info | Add-Member NoteProperty 'CooccurrenceRate' $cooccurPct
		$info
	}
}