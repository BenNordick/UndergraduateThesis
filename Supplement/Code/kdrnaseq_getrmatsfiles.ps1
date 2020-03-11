Param (
	[string]$InputFolder
)
gci $InputFolder | ? { $_.Extension -eq '.json' } | % {
	$name = ($_.Name -split '\.')[0]
	$data = gc $_.FullName | ConvertFrom-Json
	$file = @($data.files | ? { $_.analysis_step_version.name -eq 'shrna-rna-seq-rmats-splicing-quantification-step-v-1-0' })
	If ($file.Count -eq 0) {
		Write-Host "${name}: No rMATS file"
	} ElseIf ($file.Count -gt 1) {
		Write-Host "${name}: Multiple rMATS files"
	} Else {
		New-Object psobject -Property @{'target' = $name; 'file_id' = $file[0].accession; 'file_url' = $file[0].cloud_metadata.url}
	}
}