Function Get-VariantCalls {
	Param (
		[string]$VcfFile,
		[int]$Ploidy = 2,
		[switch]$SkipFirstLine,
		[switch]$AddVcfLine
	)
	$skippedLines = 0
	If ($SkipFirstLine) { $skippedLines++ }
	$vcfLines = gc $VcfFile
	$indivs = ($vcfLines[0].Split([char]"`t")).Count - 9
	$snps = $vcfLines.Count - $skippedLines
	$chromosomes = $indivs * $Ploidy
	$result = [psobject]::new()
	$presence = [array]::CreateInstance([byte], $chromosomes, $snps)
	$infos = [array]::CreateInstance([psobject], $snps)
	$curSnp = 0
	$vcfLines | select -Skip $skippedLines | % {
		$parts = $_.Split("`t", 10)
		$info = [psobject]::new()
		$info | Add-Member NoteProperty 'Position' ($parts[1])
		$info | Add-Member NoteProperty 'RsID' ($parts[2])
		If ($AddVcfLine) { $info | Add-Member NoteProperty 'VcfLine' $_ }
		$infos[$curSnp] = $info
		$alleleLine = $parts[9]
		$alleles = $alleleLine.Split([char[]]@("`t", '|'))
		0..($chromosomes - 1) | % { $presence[$_, $curSnp] = [byte]($alleles[$_].Substring(0, 1) -eq '1') }
		$curSnp++
	}
	$result | Add-Member NoteProperty -Name 'Alleles' -Value $presence
	$result | Add-Member NoteProperty -Name 'SnpInfo' -Value $infos
	$result | Add-Member NoteProperty -Name 'Snps' -Value $curSnp
	$result | Add-Member NoteProperty -Name 'Individuals' -Value $indivs
	$result | Add-Member NoteProperty -Name 'Chromosomes' -Value $chromosomes
	$result
}