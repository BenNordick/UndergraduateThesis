Param (
	[string]$SamFile,
	[int]$SequenceLength,
	[int]$SequenceCutoff = 0,
	[string]$MrnaBounds
)
If ($SequenceCutoff -eq 0) { $Cutoff = $SequenceLength }
. .\psdna.ps1
$task = 'Searching for common deletions'
Write-Progress $task -Status 'Loading SAM'
$sam = Import-Sam $SamFile
Write-Progress $task -Status 'Expanding alignments'
$sam | % { Get-AlignmentSequence -InputAlignment $_ -SequenceLength $SequenceLength -AddNote }
$seqs = $sam | % { $_.AlignedFasta.Substring(0, $SequenceCutoff) }
$delStarts = [array]::CreateInstance([int], $seqs.Count, $SequenceCutoff)
$delEnds = [array]::CreateInstance([int], $seqs.Count, $SequenceCutoff)
$dels = @()
$seqInfo = [array]::CreateInstance([psobject], $seqs.Count)
0..($seqs.Count - 1) | % {
	Write-Progress $task -Status 'Scanning per-sequence deletions' -PercentComplete ($_ * 100 / $seqs.Count)
	$seqInfo[$_] = New-Object psobject -Property @{'junctions' = [System.Collections.Generic.List[psobject]]::new()}
	$s = $_
	$anySeq = $false
	$deleteStart = 0
	0..($SequenceCutoff - 1) | % {
		If ($seqs[$s][$_] -eq '-') {
			If ($deleteStart -eq 0 -and $anySeq) {
				$deleteStart = $_
			}
		} Else {
			If (!$anySeq) {
				$anySeq = $true
				$seqInfo[$s] | Add-Member NoteProperty 'start_pos' $_
			}
			If ($deleteStart -gt 0) {
				$bp = $_
				$deleteStart..($bp - 1) | % {
					$delStarts[$s, $_] = $deleteStart
					$delEnds[$s, $_] = $bp - 1
				}
				$dels += [tuple[int, int, psobject]]::new($deleteStart, $bp - 1, $seqInfo[$s])
				$deleteStart = 0
			}
		}
	}
}
Write-Progress $task -Status 'Detecting splice junctions'
$exons = [regex]::Match($MrnaBounds.Replace("`r`n", '').Replace(' ', ''), 'join\((((\d*)\.\.(\d*)).)*')
$sBounds = [array]::CreateInstance([int], $exons.Groups[2].Captures.Count)
$eBounds = [array]::CreateInstance([int], $exons.Groups[2].Captures.Count)
$mrnaPos = 0
0..($exons.Groups[2].Captures.Count - 1) | % {
	$sBounds[$_] = $mrnaPos
	$exonLength = [int]($exons.Groups[4].Captures[$_].Value) - [int]($exons.Groups[3].Captures[$_].Value) + 1
	$eBounds[$_] = $mrnaPos + $exonLength - 1
	$mrnaPos += $exonLength
}
Function NearestBound($IsStart, $Position) {
	$offset = [int]($exons.Groups[3].Captures[0].Value) - 1
	$group = $eBounds
	If ($IsStart) { $group = $sBounds }
	$group | sort @{e = { [Math]::Abs($_ - $Position) }} | select -First 1
}
$skipScores = @{}
$dels | % {
	$sNearest = NearestBound $true ($_.Item1)
	$eNearest = NearestBound $false ($_.Item2)
	$score = 1 / [Math]::Sqrt([Math]::Abs($_.Item1 - $sNearest) + [Math]::Abs($_.Item2 - $eNearest) + 1)
	If ($eNearest -ne ($sNearest - 1)) { 
		$key = "$sNearest/$eNearest"
		$skipScores[$key] += $score 
		$_.Item3.junctions.Add((New-Object psobject -Property @{'score' = $score; 'splice' = $key}))
	}
}
New-Object psobject -Property @{'common' = ($skipScores.Keys | % {
	$s, $e = $_ -split '/'
	$sExon = (0..($sBounds.Length - 1) | ? { $sBounds[$_] -eq $s }) + 1
	$eExon = (0..($eBounds.Length - 1) | ? { $eBounds[$_] -eq $e }) + 1
	$isShift = (([int]$e - [int]$s + 1) % 3 -ne 0)
	$svInfo = New-Object psobject
	$svInfo | Add-Member NoteProperty 'junction' $_
	$svInfo | Add-Member NoteProperty 'score' ($skipScores[$_])
	$svInfo | Add-Member NoteProperty 'exon_start' $sExon
	$svInfo | Add-Member NoteProperty 'exon_end' $eExon
	$svInfo | Add-Member NoteProperty 'frameshift' $isShift
	$svInfo
} | sort score -Desc); 'transcripts' = $seqInfo}