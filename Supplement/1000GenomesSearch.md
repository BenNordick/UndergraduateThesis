# 1000 Genomes Project Allele Search

The VCF lines for rsIDs of exonic SNPs present in the Phase 3 dataset were extracted from the chromosome 5 VCF and placed in `exonicsnps.vcf`.
The co-occurrence of the variant calls in that file was measured by `vcf_cooccur.ps1`.
Individual zygosity was determined from that file by `vcf_zygosity.ps1`.
That source VCF file was used by `vcf_findcooccurrers.ps1` to scan the region around the *LARS* gene (`larsregion_phase3.vcf`) for other co-occurring variants.

All VCF processing scripts depend on the `Get-VariantCalls` cmdlet from `vcf.ps1`.
