# Now that we've managed to get the vector data into an R dataframe with some
# magical data pre-processing (or access to an R-supported format of the shapefile)
# we can extract the geometric data from the dataset

# EXTRACTING THE GEOMETRIC DATA
str(gvamap_baseR$geometry) # See what format our geometric data is stored in

gvamap_baseR$geometry[[1]]
# This is showing us how the geometric data is formatted/stored. In fact, this
# is a specific style of formatting called the well-known text (WKT) format for
# storing polygon and geometric data.

gvamap_baseR$LHA_NAME[[1]] # This tells us that the above geographic data corresponds to Abbotsford

wkt_string <- gvamap_baseR$geometry[[1]] # Store geom data in an object

# Clean the WKT string
coordinates_str <- gsub("MULTIPOLYGON \\(\\((.*)\\)\\)", "\\1", wkt_string)
coordinates_str <- gsub("^list\\(c\\(|\\)$", "", coordinates_str)
coordinates_str <- gsub("\\)$", "", coordinates_str)

# Split by commas to separate each coordinate pair
coordinates_split <- strsplit(coordinates_str, ",")[[1]]

# Remove trailing or leading whitespace
coords_split <- trimws(coordinates_split)

# Split each coordinate pair into individual x and y values
coords_numeric <- as.numeric(unlist(strsplit(coords_split, " ")))

coords_matrix <- matrix(coords_numeric, ncol = 2, byrow = TRUE)

# Extract x and y coordinates
x_coords <- coords_matrix[, 1]  # Longitude
y_coords <- coords_matrix[, 2]  # Latitude

# Initialize an empty plot with the appropriate limits
plot(NA, xlim = c(min(x_coords) - 1000, max(x_coords) + 1000),
     ylim = c(min(y_coords) - 1000, max(y_coords) + 1000),
     xlab = "Longitude", ylab = "Latitude", main = "Map of Abbotsford")

# Plot the polygon using the x and y coordinates
polygon(x_coords, y_coords, col = "lightblue", border = "black")

# ... and it really just get a lot more complicated from here with a bunch of 
# matrices ... so here's a nice, simple barplot to show the death counts instead