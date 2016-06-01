library(TopmedPipeline)
library(SeqArray)
sessionInfo()

args <- commandArgs(trailingOnly=TRUE)
config <- readConfig(args[1])

required <- c("in_gds_file", "out_gds_file")
optional <- c("chromosomes"="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 X")
config <- setConfigDefaults(config, required, optional)
print(config)


## gds file has two parts split by chromosome identifier
gdsfile <- unname(config["in_gds_file"])
chr <- strsplit(config["chromosomes"], " ", fixed=TRUE)[[1]]
gds.files <- sapply(chr, function(c) insertChromString(gdsfile, c, "in_gds_file"))
gds.list <- lapply(gds.files, seqOpen, readonly=FALSE)

read.var <- function(gds) {
    data.frame(variant.id=seqGetData(gds, "variant.id"),
               chromosome=seqGetData(gds, "chromosome"),
               position=seqGetData(gds, "position"),
               stringsAsFactors=FALSE)
}

var <- do.call(rbind, lapply(gds.list, function(x) read.var(x)))

gds.comb.file <- config["out_gds_file"]
gds.comb <- seqOpen(gds.comb.file)
comb.var <- read.var(gds.comb)
seqClose(gds.comb)

stopifnot(all.equal(var$chromosome, comb.var$chromosome))
stopifnot(all.equal(var$position, comb.var$position))

var$variant.id.new <- comb.var$variant.id

for (c in chr) {
    id.old <- var$variant.id[var$chromosome == c]
    id.new <- var$variant.id.new[var$chromosome == c]
    if (identical(id.old, id.new)) next
    
    node <- index.gdsn(gds.list[[c]], "variant.id")
    compress <- objdesp.gdsn(node)$compress
    compression.gdsn(node, "")
    write.gdsn(node, id.new)
    compression.gdsn(node, compress)
    seqClose(gds.list[[c]])
}
