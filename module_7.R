#######################
###### 1) SETUP #######
#######################

library(sqldf)

# Import mortality data
mortality <- read.csv("data/m3_mortality.csv")
mortality$death_date <- as.Date(mortality$death_date)

# Import pccf data
pccf <- read.csv("data/postal_code_conversion_file.csv")
pccf$end_date <- as.Date(pccf$end_date)

# Import m4dat data
m4dat <- read.csv("data/m4dat.csv")
m4dat$date <- as.Date(m4dat$date)

################################
### 2) EXAMINING THE PCCF ######
################################

str(pccf) # Lets see what the data looks like

pccf <- pccf[order(pccf$postal_code, -as.numeric(pccf$end_date)), ] # Order by postal code (ascending) and by end_date (descending)

head(pccf[, c("postal_code", "start_date", "end_date")], n = 10) # View first 10 rows, only these three variables

# Reduce the dataset to the essential variables
pccf_short <- sqldf(
       "SELECT postal_code, 
              start_date, 
              end_date,
              longitude,
              latitude
       FROM pccf"
       )

str(pccf_short)

# Count the distinct postal codes
sqldf(
  "SELECT count(postal_code) AS tot_postal_code,
          count(distinct(postal_code)) AS unique_postal_code
   FROM pccf_short"
  )

sqldf(
  "SELECT postal_code,
          count(postal_code) AS pc_count
   FROM pccf_short
   GROUP BY postal_code
   LIMIT 10"
)

# Get the average, min,and max number of time each postal code appears
sqldf("
  SELECT AVG(pc_count) AS mean_pc_count,
         MIN(pc_count) AS mini_pc_count,
         MAX(pc_count) AS max_pc_count
  FROM (SELECT COUNT(postal_code) AS pc_count
        FROM pccf_short
        GROUP BY postal_code)
      ")

####################################################
######## 3) GEOCODING THE MORTALITY DATASET ########
####################################################
str(mortality)

sum(is.na(mortality$postcode))

# Count null postal codes
sqldf(
  "SELECT COUNT(uid)
   FROM mortality
   WHERE postcode = ''"
)

# Create a version of the mortality data with no missing values
m7_mortality <- sqldf(
  "SELECT *
   FROM mortality
   WHERE postcode != ''"
)

str(m7_mortality) # 230916 observations in the new mortality dataset

# We need to convert to dates before we can do this next SQL query
pccf_short$start_date <- as.Date(pccf_short$start_date)
pccf_short$end_date <- as.Date(pccf_short$end_date)
m7_mortality$death_date <- as.Date(m7_mortality$death_date)

# Test the linkage plan
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
# Note that the number of observations has changed

str(mortality_comp) 

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
# because ...

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

# SELECTING ONLY THE NECESSSARY VARIABLE
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

# LINKING THE DATA
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

# To be extra sure, run this SQL query
sqldf(
  "SELECT COUNT(*)
   FROM mortality_lha
   WHERE lhacode IS NOT NULL"
)

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
############### 4) CHLOROPLETH MAPS ###################
#######################################################

# Unfortunately, base R doesn't support reading/writing shape files
# 'out of the box', so below are two methods of creating a chloropleth
# map (of sorts): the first using base R only, and the second using a light
# weight package for handling GIS data called 'sf'

gva <- c(161:166, 201, 202, 37, 38, 42, 44, 45, 43, 42, 75, 34, 35) # stores gva lha codes

# BASE R METHOD


# SF (SIMPLE FEATURES) METHOD
library(sf)

bcmap <- st_read("shapefile/lha.shp") # Read shapefile into R

plot(bcmap) # Here's the map we've just brought into R

mortality_hot_days_gva <- mortality_hot_days[mortality_hot_days$id_number %in% gva, ]
colnames(mortality_hot_days_gva) <- toupper(colnames(mortality_hot_days))

str(mortality_hot_days_gva)

gvamap <- merge(bcmap, mortality_hot_days_gva, by = "ID_NUMBER")

# MAKE THE CHLOROPLETH MAP
# Store the number of colors based on the unique DEATH_COUNTS
num_colors <- length(unique(gvamap$DEATH_COUNTS))

# Create a color palette based on the number of unique values
colors <- terrain.colors(num_colors)

# Map DEATH_COUNTS to color indices
color_indices <- as.numeric(cut(gvamap$DEATH_COUNTS, 
                                breaks = num_colors, 
                                labels = FALSE))

# Make the choropleth map
plot(st_geometry(gvamap), col = colors[color_indices], border = "black")
legend("topright",  
       legend = sort(unique(gvamap$DEATH_COUNTS)),  # Unique values for legend labels
       fill = colors,  # Use the generated color palette
       title = "Death Counts")




