Param(
	[string]$InputTsv,
	[string]$OutputTsv,
	[double]$PCutoff
)
$first = $true
$pIndex = -1
gc $InputTsv | % {
	$parts = $_.Split("`t")
	If ($first) {
		$pIndex = $parts.IndexOf('PValue')
		$first = $false
		$_
	} ElseIf ([double]($parts[$pIndex]) -le $PCutoff) {
		$_
	}
} | Set-Content $OutputTsv -Encoding ascii