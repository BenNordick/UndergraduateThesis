Param (
	[string]$VcfFile,
	[switch]$SkipFirstLine
)
$presence = Get-VariantCalls -VcfFile $VcfFile -SkipFirstLine:$SkipFirstLine -Ploidy 2
$summary = [array]::CreateInstance([byte], $presence.Chromosomes)
0..($presence.Chromosomes - 1) | % {
	$c = $_
	$mutantSnps = 0
	0..($presence.Snps - 1) | % {
		If ($presence.Alleles[$c, $_] -gt 0) { $mutantSnps++ }
	}
	If ($mutantSnps -gt [Math]::Floor($presence.Snps / 2)) { $summary[$c] = 1 }
}
$wildtype, $heterozygous, $mutant = 0, 0, 0
0..($presence.Individuals - 1) | % {
	$mut1 = $summary[$_ * 2] -gt 0
	$mut2 = $summary[$_ * 2 + 1] -gt 0
	If ($mut1 -and $mut2) {
		$mutant++
	} ElseIf ($mut1 -or $mut2) {
		$heterozygous++
	} Else {
		$wildtype++
	}
}
@{ "HomozygousWildtype" = $wildtype; "Heterozygous" = $heterozygous; "HomozygousMutant" = $mutant }