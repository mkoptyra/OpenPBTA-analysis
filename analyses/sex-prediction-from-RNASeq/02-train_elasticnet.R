#--------Library calls

library(glmnet)
library(glmnetUtils)
library(readr)

#--------

# This script is the second of a three-script workflow to predict sex from gene expression.
# We build an elastic net logistic regression model from a training set and known target values set
# that was cleaned and saved in script 01-clean_split_data.R.

# Command-line arguments for this script identify the input directory where the training and target sets are located,
# the output directory where the model files will be saved, the file name components necessary to create
# the required file paths for input and output, along with the threshold percentile for filtering transcripts by median 
# absolute deviation.

#________ Declare command line arguments

option_list <- list(
  optparse::make_option(
    c("-i", "--input_directory"),
    type = "character",
    default = NULL,
    help = "input directory"
  ),
  optparse::make_option(
    c("-o", "--output_directory"),
    type = "character",
    default = NULL,
    help = "output directory"
  ),
  optparse::make_option(
    c("-f", "--filename_lead"),
    type = "character",
    default = NULL,
    help = "A character vector that will be used to name output files"
  ),
  optparse::make_option(
    c("-s", "--seed"),
    type = "integer",
    default = 36354,
    help = "seed integer",
    metavar = "integer"
  ),  
  optparse::make_option(
    c("-p", "--transcript_tail_percent"),
    type = "double",
    default = 0.25,
    help = "Filter out the bottom (1 - transcript_tail_percent) of transcripts from the training set",
    metavar = "double"
  )
  
)


# Read the arguments passed
opt_parser <- optparse::OptionParser(option_list = option_list)
opt <- optparse::parse_args(opt_parser)

#--------

#--------test for the existence of the expected training and target value sets. 

train_set_file_name <- file.path(opt$input_directory, paste(opt$filename_lead, opt$seed, "train_expression.RDS", sep = "_"))
targets_set_file_name <- file.path(opt$input_directory, paste(opt$filename_lead, opt$seed, "train_targets.tsv", sep = "_"))

# print error and quit if not found.
if (!file.exists(train_set_file_name)) {
  stop(paste("training set", train_set_file_name, "does not exist. Check all arguments."))
}

print("training set found!")

if (!file.exists(targets_set_file_name)) {
  stop(paste("targets set", targets_set_file_name, "does not exist. Check all arguments.", sep=" "))
}

print("targets set found!")

# safe to read if we get here

train_set <- readRDS(train_set_file_name)
targets_set <- read.delim(targets_set_file_name, header=TRUE, sep="\t", stringsAsFactors = FALSE)

#--------

#--------test sample ID sequence of train_set matches sample ID sequence of targets set

if (!(sum(rownames(train_set) == targets_set[ , "Kids_First_Biospecimen_ID"]) == nrow(train_set))) {
  stop("train set sample IDs are out of sequence with targets set sample IDs.  Aborting run.")
}

print("train set sample ID sequence matches targets set sample ID sequence.  Proceeding to filtering training set columns.")

#--------

#--------Filter transcript columns by median absolute deviation according to MAD_threshold argument

tx_mads <- apply(train_set, 2, function(x) mad(x, high = TRUE))
filtered_txs <- which(tx_mads >= quantile(tx_mads, 1 - opt$transcript_tail_percent))
train_set <- train_set[, filtered_txs]

print(paste("MAD filtering is complete.  train_set dimension = ", nrow(train_set), "X", ncol(train_set), ". Proceeding to model build.", sep=" "))
print(paste("Model build begun at", Sys.time(), sep=" "))

#--------


#--------Build elastic net logistic regression model

sex.cva <- cva.glmnet(train_set, targets_set[, "reported_gender"], standardize=TRUE, 
                      alpha = seq(0, 1, len = 11)^3, family="binomial")

print(paste("Model build complete at", Sys.time(), sep=" "))

#--------

#--------Retrieve optimal values of lambda and alpha

#Although Hastie recommends against looking into the cva object, I could not retrieve optimal
#values of lambda and alpha through code without doing so.

#the cva object contains a list, called modlist, of 11 objects, one for each of the alpha values tested.
#The alpha corresponding to the minimum of these minimum cvm values is optimal.

best_cvm_values <- sapply(sex.cva$modlist, function(x) min(x$cvm))
best_alpha_index <- which(best_cvm_values == min(best_cvm_values))

# note: look at sex.cva$alpha[best_alpha_index] to find the tuned value of alpha
# best fitting model is at best_alpha_index in sex.cva$modlist

best_fit <- sex.cva$modlist[[best_alpha_index]]

#--------Save best_fit model object and filtered transcript indexes

best_fit_file <- file.path(opt$output_directory, paste(opt$filename_lead, opt$seed, opt$transcript_tail_percent, 
                                                       "model_object.RDS", sep = "_"))
saveRDS(best_fit, best_fit_file)

model_transcripts_file <- file.path(opt$output_directory, paste(opt$filename_lead, opt$seed, opt$transcript_tail_percent, 
                                                       "model_transcripts.RDS", sep = "_"))
saveRDS(filtered_txs, model_transcripts_file)

#--------

#--------Capture and save best fit model's non-zero transcripts and coefficients

#The cva.modlist object corresponds to a given alpha value, and contains results for all the lambda values 
#tested for the corresponding alpha value.

#The minimum CVloss lambda value is stored within the modlist object as lambda.min.

#However, in an effort to minimize # of non-zero coefficients, 
#follow common rule-of-thumb and use best_fit$lambda.1se for prediction

non_zero_features <- which(coef(best_fit, s = best_fit$lambda.1se) != 0)

non_zero_coef <- coef(best_fit, s=best_fit$lambda.1se)[non_zero_features]

non_zero_transcripts <- colnames(train_set)[non_zero_features]


model_coefs_file <- file.path(opt$output_directory, paste(opt$filename_lead, opt$seed, opt$transcript_tail_percent, 
                                                       "model_coefs.tsv", sep = "_"))

model_coefs <- data.frame(non_zero_transcripts, non_zero_coef)

write_tsv(model_coefs, model_coefs_file,
          na = "NA", append = FALSE, col_names = TRUE, quote_escape = "double")


#--------


