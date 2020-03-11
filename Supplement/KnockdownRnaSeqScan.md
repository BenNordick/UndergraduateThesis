# ENCODE Knockdown/RNA-Seq Experiment Search

The ENCODE Project's web interface was used to search for "shRNA RNA-seq" experiments in HepG2 and K562 biosamples separately.
The JSON search results were downloaded and saved (`kdrnaseq_experiments_*.json`).
The experiment metadata JSON was downloaded for each experiment with `kdrnaseq_downloadexperiments.ps1`.
From those experiments, rMATS results files were selected with `kdrnaseq_getrmatsfiles.ps1`.
The output of that script was used by `kdrnaseq_downloadtars.ps1` to download the rMATS result archive for each experiment.
The archives were extracted and the *LARS*-specific results combined with `kdrnaseq_combine.ps1`.
The resulting TSV was filtered for significant events with `kdrnaseq_pfilter.ps1`.
The two cell-line-specific TSVs were manually combined in Excel.
