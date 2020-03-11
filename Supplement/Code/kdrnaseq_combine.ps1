Param(
	[string]$InputFolder,
	[string]$OutputFolder,
	[string]$Gene
)
$outPath = Resolve-Path $OutputFolder
$tempPath = Join-Path $outPath '_temp'
gci $InputFolder -File | ? { $_.Name.EndsWith('.tar.gz') } | % {
	$target = $_.Name.Split('.')[0]
	Write-Progress -Activity 'Compiling differential splicing reports' -Status $target
	mkdir $tempPath | Out-Null
	tar xzf $_.FullName -C $tempPath
	gci $tempPath -Recurse -File | % {
		$combined = Join-Path $outPath $_.Name
		gc $_.FullName | ? {
			$parts = $_.Split("`t", 4)
			$parts[2] -eq ('"' + $Gene + '"')
		} | % { "$target`t$_" } | Out-File $combined -Append -Encoding ASCII
	}
	Remove-Item $tempPath -Recurse
}