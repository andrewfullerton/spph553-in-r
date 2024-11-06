library(sqldf)

mortality_ill <- read.csv("data/m3_mortality.csv")

###################################################
### SQL: CREATING AND ACCESSING DATAFRAMES IN R ###
###################################################

str(mortality_ill)

# Run this code. What happened?
sqldf(
  "CREATE TABLE mortality_ill_small AS
   SELECT uid,
          death_date,
          sex
   FROM mortality_ill")

# Now run this code. What happened?
mortality_ill_small <- sqldf(
  "SELECT uid,
          death_date,
          sex
   FROM mortality_ill"
)

str(mortality_ill_small) # You should see that your R object was created

# This is because SQL is not integrated into R via sqldf the same way that
# PROC SQL integrates SQL with SAS. We cannot read and write data into/from 
# our R environment using sqldf. 





###################################################
### SQL: ACCESSING NATIVE R FUNCTIONS IN SQLDF ####
###################################################

# Run this code. What happened?
mortality_ill_small_v2 <- sqldf(
  "SELECT uid,
          as.Date(death_date, format = '%m/%d/%Y')
   FROM mortality_ill"
)

# Now run this code. What happened?
mortality_ill_small_v2 <- sqldf(
  "SELECT uid,
          death_date
   FROM mortality_ill"
)

mortality_ill_small_v2$death_date <- as.Date(mortality_ill_small_v2$death_date, 
                                             format = '%m/%d/%Y')

str(mortality_ill_small_v2) # Let's see the new dataset we made

# Our SQL query is not integrated into the R language the same way that
# PROC SQL integrates SQL queries into SAS. We cannot (easily) access or use R
# functions in SQL queries passed to sqldf.

# We can only use standard SQL functions in sqldf.




#####################################################
### GIS: READING SHAPEFILES INTO OUR ENVIRONMENT ####
#####################################################

# Try to find a function that will this shapefile into R. Don't
# load any packages! Hint: most base R read functions begin with "read"

filepath <- "shapefile/lha.shp" # Try to read this filepath in the space below


# Any luck? 





###########################################################
### GIS: TRY TO FIND BASE R FUNCTIONS FOR SPATIAL DATA ####
###########################################################

# Now ask your favourite generative AI tool or search engine. What'd you find?

# Note that ChatGPT may try to (incorrectly) tell you that R has a package 
# included by default called 'maps' that works with spatial data.




