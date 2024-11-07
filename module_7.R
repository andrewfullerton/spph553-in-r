#######################
###### 1) SETUP #######
#######################

# if not installed, run: install.packages('sqldf')

library(sqldf)

# Import mortality data
mortality <- readRDS("data/m3_mortality.rds")

# Import m4dat data
m4dat <- readRDS("data/m4dat.rds")

##################################
##### 2) EXAMINING THE PCCF ######
##################################

# Read in pccf data
pccf <- read.csv("data/postal_code_conversion_file.csv")
pccf$start_date <- as.Date(pccf$start_date) # Format start date
pccf$end_date <- as.Date(pccf$end_date) # Format end date

str(pccf) # See what the data looks like

# Order by postal code (ascending) and by end_date (descending)
pccf <- pccf[order(pccf$postal_code, rev(as.numeric(pccf$end_date))), ]

# View first 10 rows, only these three variables
head(pccf[, c("postal_code", "start_date", "end_date")], n = 10)

# Reduce the dataset to the essential variables
pccf_short <- sqldf(
  "SELECT postal_code, 
          start_date, 
          end_date,
          longitude,
          latitude
   FROM pccf"
)

str(pccf_short) # View changes

# Explore how many distinct postal code entries are in the pccf
sqldf(
  "SELECT count(postal_code) AS tot_postal_code,
          count(distinct(postal_code)) AS unique_postal_code
   FROM pccf_short"
)

# Explore the number of times a given postal code appears
sqldf(
  "SELECT postal_code,
          count(postal_code) AS pc_count
   FROM pccf_short
   GROUP BY postal_code
   LIMIT 10"
)

# Get the average, min, and max number of times each postal code appears
sqldf(
  "SELECT AVG(pc_count) AS mean_pc_count,
          MIN(pc_count) AS min_pc_count,
          MAX(pc_count) AS max_pc_count
   FROM (SELECT COUNT(postal_code) AS pc_count
         FROM pccf_short
         GROUP BY postal_code)"
)

####################################################
######## 3) GEOCODING THE MORTALITY DATASET ########
####################################################

str(mortality) # Remind ourselves what this dataset looks like

# Count null postal codes (attempt 1)
sqldf(
  "SELECT COUNT(uid)
   FROM mortality
   WHERE postcode IS NULL"
)

# Hmm ... this is exactly how we did it in SAS. Why the difference in output?

sum(is.na(mortality$postcode)) # Count number of null values using base R
nrow(mortality[mortality$postcode == '.', ]) # Count number of cells with '.'
nrow(mortality[mortality$postcode == '', ]) # Count number of empty cells

# Count null postal codes (attempt 2)
sqldf(
  "SELECT COUNT(uid)
   FROM mortality
   WHERE postcode = ''"
)

# That looks better! Different software packages handle missing values 
# differently. Since postcode is stored as a character variable in R, it will 
# not convert missing cells to NAs by default. 

# Create a version of the mortality data with no missing values
m7_mortality <- sqldf(
  "SELECT *
   FROM mortality
   WHERE postcode != ''"
)

str(m7_mortality) # 230916 observations in the new mortality dataset


# Test the linkage plan
str(pccf_short) # Remind ourselves what our pccf data looks like

sqldf(
  "SELECT uid,
          postcode AS pc_mort,
          postal_code AS pc_pccf,
          start_date,
          death_date,
          end_date,
          longitude,
          latitude
   FROM m7_mortality AS a JOIN pccf_short AS b ON a.postcode=b.postal_code
   WHERE a.death_date BETWEEN b.start_date AND b.end_date"
) |>
  head(n = 10)

# Linking the data
mortality_comp <- sqldf(
  "SELECT uid,
          postcode AS pc_mort,
          postal_code AS pc_pccf,
          start_date,
          death_date,
          end_date,
          longitude,
          latitude
   FROM m7_mortality AS a JOIN pccf_short AS b ON a.postcode=b.postal_code
   WHERE a.death_date BETWEEN b.start_date AND b.end_date"
)

str(mortality_comp) # Note that the number of observations has changed

# Look at the dropped observations. Since we know that any rows in m7_mortality
# without a corresponding entry (i.e. were dropped) will have a null id in 
# mortality_comp, we can produce a list of the dropped observations. 
sqldf(
  "SELECT a.uid AS orig_id,
          b.uid AS unlinked_id,
          a.postcode
   FROM m7_mortality AS a LEFT JOIN mortality_comp as b ON a.uid=b.uid
   WHERE b.uid is NULL"
) 
# We lost 15 observations 

# Let's investigate further...
sqldf(
  "SELECT a.uid,
          postcode,
          death_date,
          postal_code,
          start_date,
          end_date
   FROM (SELECT a.uid,
                b.uid AS unlinked_id,
                a.postcode,
                a.death_date
         FROM m7_mortality AS a LEFT JOIN mortality_comp AS b ON a.uid=b.uid
         WHERE b.uid is NULL) AS a
   LEFT JOIN pccf_short AS b ON a.postcode=b.postal_code"
)

# From this, we can see that the mortality data were dropped during linkage
# because the death dates were not found between the start and end dates

# Create the final geocoded dataset
mortality_geocoded <- sqldf(
  "SELECT uid,
          death_date,
          longitude,
          latitude
   FROM mortality_comp
   WHERE longitude is NOT NULL AND latitude is NOT NULL"
)

str(mortality_geocoded) # Verify that the dataset has 229557 rows as intended

# Save the final dataset to the m7 folder
getwd() # check what local directory you're in
setwd("/Users/andrewfullerton/Desktop/Code/spph553-in-r") # replace with local file path

if (!dir.exists("m7")) { # if no folder named m7 exists, create one
  dir.create("m7")
} 

saveRDS(mortality_geocoded, "m7/mortality_geocoded.rds") # save in m7 as RDS

##############################################
############### 4) MAPPING ###################
##############################################

# LINKING THE DATA
# Select only the variables we want to use going forward
mapping_mortality <- sqldf(
  "SELECT uid,
          death_date,
          lhacode
   FROM mortality 
   WHERE lhacode IS NOT NULL"
)

temp <- sqldf(
  "SELECT date,
          temperature_Min,
          temperature_Max
   FROM m4dat"
)

# Testing our linkage
sqldf(
  "SELECT a.*,
          b.temperature_Min,
          b.temperature_Max
   FROM mapping_mortality AS a LEFT JOIN temp AS b ON a.death_date=b.date"
) |>
  head(n = 10)

# Linking the data
mortality_lha <- sqldf(
  "SELECT a.*,
          b.temperature_Min,
          b.temperature_Max
   FROM mapping_mortality AS a LEFT JOIN temp AS b ON a.death_date=b.date"
)

# Verify that the dataset has 231178 rows as intended
str(mortality_lha) 

sqldf(
  "SELECT COUNT(*)
   FROM mortality_lha
   WHERE lhacode IS NOT NULL"
) # To be extra sure, run this SQL query

# CREATE HOT DAYS AND COLD DAYS DATASETS
# Store the 99.9th hottest temperature and the 0.1th coldest temperature
quantile(mortality_lha$temperature_Max, probs = 0.999) # hottest temps
quantile(mortality_lha$temperature_Min, probs = 0.001) # coldest temps

# Create hot days dataset
mortality_hot_days <- sqldf(
  "SELECT lhacode AS id_number,
          COUNT(uid) AS death_counts
   FROM mortality_lha
   WHERE temperature_Max > 29.5
   GROUP BY lhacode"
)

# Create cold days dataset
mortality_cold_days <- sqldf(
  "SELECT lhacode AS id_number,
          COUNT(uid) AS death_counts
   FROM mortality_lha
   WHERE temperature_Min < (-9.5)
   GROUP BY lhacode"
)

#######################################################
############### 5) CHOROPLETH MAPS ####################
#######################################################

# Unfortunately, base R doesn't support reading/writing shape files
# 'out of the box'. Technically, we could write a function to do this, but
# this would require dealing with regular expressions (and matrices) 
# and is way beyond our scope.

# So, below are two methods of mapping the data: 
# The first uses base R only and a bit of data processing magic. It falls short 
# of a choropleth map but is a visual representation of the data. The second uses 
# a lightweight package for handling GIS data called 'sf'.

gva <- c(161:166, 201, 202, 37, 38, 42, 44, 45, 43, 42, 75, 34, 35) # gva codes

mortality_hot_days_gva <- mortality_hot_days[mortality_hot_days$id_number %in% gva, ]
str(mortality_hot_days_gva) # View the new dataset

mortality_cold_days_gva <- mortality_cold_days[mortality_cold_days$id_number %in% gva, ]
str(mortality_cold_days_gva) # View the new dataset

#### BASE R METHOD (ISH) ####
bcmap_baseR <- readRDS("data/bcmap_data.rds") # Note that this is only possible with some data pre-processing

str(bcmap_baseR) # View the data we've just loaded into R

# CREATE THE MAP FOR HOT DAYS
gvamap_baseR_hot <- merge(bcmap_baseR, mortality_hot_days_gva, by.x = "ID_NUMBER", by.y = "id_number")
str(gvamap_baseR_hot) # Verify that the merge worked

par(mar = c(10, 4, 4, 2))
barplot(gvamap_baseR_hot$death_counts, 
        names.arg = gvamap_baseR_hot$LHA_NAME, # Region names on the x-axis
        col = "lightyellow", # Bar colour
        ylab = "Death Counts", # Y-axis label
        main = "Death Counts by GVA Region", # Plot title
        las = 2, # Rotate x-axis labels for readability
        cex.names = 0.7,  # Reduce label size
        ylim = c(0, 20)) # y-axis range

# CREATE THE MAP FOR COLD DAYS
gvamap_baseR_cold <- merge(bcmap_baseR, mortality_cold_days_gva, by.x = "ID_NUMBER", by.y = "id_number")
str(gvamap_baseR_cold) # Verify that the merge worked

par(mar = c(10, 4, 4, 2))
barplot(gvamap_baseR_cold$death_counts, 
        names.arg = gvamap_baseR_cold$LHA_NAME, # Region names on the x-axis
        col = "lightblue", # Bar colour
        ylab = "Death Counts", # Y-axis label
        main = "Death Counts by GVA Region", # Plot title
        las = 2, # Rotate x-axis labels for readability
        cex.names = 0.7,  # Reduce label size
        ylim = c(0, 20)) # y-axis range


#### SF (SIMPLE FEATURES) METHOD ####
library(sf) # load the 'sf' library

bcmap <- st_read("shapefile/lha.shp") # Read shapefile into R
str(bcmap) # View the data we've just loaded into R
plot(bcmap) # View the basemap we've just loaded into R

# CREATE THE MAP FOR HOT DAYS
gvamap_hot <- merge(bcmap, mortality_hot_days_gva, by.x = "ID_NUMBER", by.y = "id_number")
str(gvamap_hot) # Confirm the merge worked

plot(gvamap_hot["death_counts"], 
     key.pos = 1,
     main = "Death Counts by GVA Region")

# CREATE THE MAP FOR COLD DAYS
gvamap_cold <- merge(bcmap, mortality_cold_days_gva, by.x = "ID_NUMBER", by.y = "id_number")
str(gvamap_cold)

plot(gvamap_cold["death_counts"], 
     key.pos = 1,
     main = "Death Counts by GVA Region")

