Param (
	[object[]]$Inputs,
	[string]$OutputFolder
)
$outPath = Resolve-Path $OutputFolder
$Inputs | % {
	$name = $_.target
	$file = Join-Path $outPath "$name.tar.gz"
	If (![System.IO.FileInfo]::new($file).Exists) {
		Write-Progress -Activity 'Downloading splicing quantifications' -Status $name
		$res = wget $_.file_url
		Set-Content $file $res.Content -Encoding byte
	}
}