Illustrative Examples
================
Andrew Fullerton
2024-11-07

``` r
library(sqldf)
```

    ## Loading required package: gsubfn

    ## Loading required package: proto

    ## Warning in doTryCatch(return(expr), name, parentenv, handler): unable to load shared object '/Library/Frameworks/R.framework/Resources/modules//R_X11.so':
    ##   dlopen(/Library/Frameworks/R.framework/Resources/modules//R_X11.so, 0x0006): Library not loaded: /opt/X11/lib/libSM.6.dylib
    ##   Referenced from: <BDCE065B-0E14-3F82-A5E6-7C0A970A6C32> /Library/Frameworks/R.framework/Versions/4.4-x86_64/Resources/modules/R_X11.so
    ##   Reason: tried: '/opt/X11/lib/libSM.6.dylib' (no such file), '/System/Volumes/Preboot/Cryptexes/OS/opt/X11/lib/libSM.6.dylib' (no such file), '/opt/X11/lib/libSM.6.dylib' (no such file), '/Library/Frameworks/R.framework/Resources/lib/libSM.6.dylib' (no such file), '/Library/Java/JavaVirtualMachines/jdk-11.0.18+10/Contents/Home/lib/server/libSM.6.dylib' (no such file)

    ## tcltk DLL is linked to '/opt/X11/lib/libX11.6.dylib'

    ## Could not load tcltk.  Will use slower R code instead.

    ## Loading required package: RSQLite

``` r
mortality_ill <- read.csv("data/m3_mortality.csv")
```

# SQL: Creating and accessing dataframes in R

``` r
str(mortality_ill)
```

    ## 'data.frame':    231178 obs. of  10 variables:
    ##  $ uid       : int  122745837 122745924 122745926 122745928 122745933 122745940 122745945 122745948 122745955 122745957 ...
    ##  $ death_date: chr  "2005-02-28" "2008-12-10" "2007-03-17" "2012-07-29" ...
    ##  $ age       : chr  "60 years" "50 years" "94 years" "87 years" ...
    ##  $ age_cat   : chr  "60-64 years" "50-54 years" "85+ years" "85+ years" ...
    ##  $ ucod      : chr  "C80" "W86" "C260" "INC" ...
    ##  $ sex       : chr  "Female" "Female" "Male" "Male" ...
    ##  $ lhacode   : int  162 34 34 34 41 75 42 163 75 75 ...
    ##  $ lhadesc   : chr  "Vancouver - Downtown Eastside (162)" "Abbotsford (034)" "Abbotsford (034)" "Abbotsford (034)" ...
    ##  $ location  : chr  "" "HOSPITAL" "" "RESIDENTIAL INSTITUTION" ...
    ##  $ postcode  : chr  "V6A1G3" "V2T3N9" "V2T5M2" "V2T6V3" ...

### Run this code. What happened?

``` r
sqldf(
  "CREATE TABLE mortality_ill_small AS
   SELECT uid,
          death_date,
          sex
   FROM mortality_ill"
)
```

    ## Warning in result_fetch(res@ptr, n = n): SQL statements must be issued with
    ## dbExecute() or dbSendStatement() instead of dbGetQuery() or dbSendQuery().

    ## data frame with 0 columns and 0 rows

### Now run this code. What happened?

``` r
mortality_ill_small <- sqldf(
  "SELECT uid,
          death_date,
          sex
   FROM mortality_ill"
)

str(mortality_ill_small) # You should see that your R object was created
```

    ## 'data.frame':    231178 obs. of  3 variables:
    ##  $ uid       : int  122745837 122745924 122745926 122745928 122745933 122745940 122745945 122745948 122745955 122745957 ...
    ##  $ death_date: chr  "2005-02-28" "2008-12-10" "2007-03-17" "2012-07-29" ...
    ##  $ sex       : chr  "Female" "Female" "Male" "Male" ...

This is because SQL is not integrated into R via `sqldf` the same way
that `PROC SQL` integrates SQL with SAS. We cannot write data within SQL
queries passed into `sqldf`.

# SQL: Accessing native R functions in `sqldf`

### Run this code. What happened?

``` r
mortality_ill_small_v2 <- sqldf(
  "SELECT uid,
          as.Date(death_date, format = '%m/%d/%Y')
   FROM mortality_ill"
)
```

    ## Error: near "as": syntax error

### Now run this code. What happened?

``` r
mortality_ill_small_v2 <- sqldf(
  "SELECT uid,
          death_date
   FROM mortality_ill"
)

mortality_ill_small_v2$death_date <- as.Date(mortality_ill_small_v2$death_date,
                                             format = '%Y-%m-%d')

str(mortality_ill_small_v2) # Let's see the new dataset we made
```

    ## 'data.frame':    231178 obs. of  2 variables:
    ##  $ uid       : int  122745837 122745924 122745926 122745928 122745933 122745940 122745945 122745948 122745955 122745957 ...
    ##  $ death_date: Date, format: "2005-02-28" "2008-12-10" ...

Our SQL query is not integrated into the R language the same way that
`PROC SQL` integrates SQL queries into SAS. We cannot (easily) access or
use R functions in SQL queries passed to `sqldf`.

We can only use standard SQL functions in `sqldf`.

# GIS: Reading shapefiles into our environment

Try to find a function that will read this shapefile into R. Don’t load
any packages! Hint: most base R read functions begin with `read`.

``` r
filepath <- "shapefile/lha.shp" # Try to read this filepath in the space below

# ...
# ...
# ...
```

Any luck?

# GIS: Try to find base R functions for spatial data

Now ask your favourite generative AI tool or search engine. What’d you
find? Note that ChatGPT may try to (incorrectly) tell you that R has a
package included by default called ‘maps’ that works with spatial data.
