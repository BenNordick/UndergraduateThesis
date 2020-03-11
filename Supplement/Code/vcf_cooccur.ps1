Param (
	[string]$VcfFile,
	[int]$Ploidy = 2,
	[switch]$SkipFirstLine
)
$skippedLines = 0
If ($SkipFirstLine) { $skippedLines++ }
$vcfLines = gc $VcfFile
$indivs = ($vcfLines[0].Split([char]"`t")).Count - 9
$snps = $vcfLines.Count - $skippedLines
$chromosomes = $indivs * $Ploidy
$presence = [array]::CreateInstance([byte], $chromosomes, $snps)
$curSnp = 0
$vcfLines | select -Skip $skippedLines | % {
	$alleleLine = $_.Split("`t", 10)[9]
	$alleles = $alleleLine.Split([char[]]@("`t", '|'))
	0..($chromosomes - 1) | % { $presence[$_, $curSnp] = [byte]($alleles[$_].Substring(0, 1) -eq '1') }
	$curSnp++
}
$transChromosomes = 0
0..($chromosomes - 1) | % {
	$c = $_
	$firstAllele = $presence[$c, 0]
	$hasDiff = $false
	1..($snps - 1) | % { If ($presence[$c, $_] -ne $firstAllele) { $hasDiff = $true } }
	If ($hasDiff) { $transChromosomes++ }
}
@{'Trans' = $transChromosomes; 'Total' = $chromosomes}