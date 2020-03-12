# Pac-Bio SAM Investigation

`psdna.ps1` defines several cmdlets used for navigating the SAM file containing the aligned Pac-Bio reads.

- `Import-Sam` loads a SAM file as an array of PowerShell objects. These alignment objects are used by several other cmdlets.
- `Export-Sam` saves an array of alignment objects as a SAM file.
- `Get-AlignmentCounts` produces an array counting how many reads had a base aligned to each position.
  It can also tag each input alignment object with whether it had a base at each position. These tagged alignments are expected by some other cmdlets.
- `Get-AlignmentCigar` takes an aligned FASTA string and produces its CIGAR string relative to a consensus sequence.
- `Align-Sam` invokes Clustal Omega to forcibly align an alignment object lacking a CIGAR string. Uses `Get-AlignmentCigar`.
- `Get-AlignmentSequence` tags an alignment object with its aligned FASTA string based on its CIGAR string.
- `Test-StretchPresent` determines whether a FASTA-tagged alignment object contains at least the specified proportion of bases in the specified region.
- `Measure-AlignmentQuality` calculates the quality score for an alignment object.
- `Add-SnpFingerprint` tags each alignment with the fingerprint calculated by its base calls at the specified positions.

`exoncount.ps1` relies on `psdna.ps1` and defines a few cmdlets for testing exon presence.

- `Test-ExonPresent` determines whether an alignment contains the specified exon at the specified stringency.
- `Test-ExonAbsent` determines whether an alignment deletes the specified exon (but has surrounding areas) at the specified stringency.
- `Measure-ExonPresence` calculates an exon's inclusion status at many stringencies. Used for calibrating stringency against experiments.

`basemutrate.ps1` calculates the read error rate of a set of alignment objects relative to the consensus sequence.
It can be set to ignore specified positions (e.g. known SNPs).

`splicesearch.ps1` searches a SAM file for deletions that match the specified exon boundaries closely.
The mRNA boundaries string from NCBI is in `mrnabounds.txt`.
