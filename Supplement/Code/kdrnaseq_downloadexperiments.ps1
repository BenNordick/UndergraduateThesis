Param(
	[string]$InputFile,
	[string]$OutputFolder
)
$data = gc $InputFile | ConvertFrom-Json
$outPath = Resolve-Path $OutputFolder
$data.'@graph' | ? { $_.target -ne $null } | % {
	$name = $_.target.label
	$expOutPath = Join-Path $outPath "$name.json"
	If (![System.IO.FileInfo]::new($expOutPath).Exists) {
		Write-Progress -Activity 'Downloading experiment metadata' -Status $name
		$id = $_.'@id'
		(iwr "https://www.encodeproject.org/${id}?format=json").Content | Out-File $expOutPath -Encoding ASCII
	}
}