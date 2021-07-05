# My Contribution to the Research
Over the past two years I have been responsible for developing the technology to analyze the effects of charter competition on neighboring traditional public schools (TPS). The work was under the supervision of Dr. Jim Dewey, but largely independent. The aim is to inform research questions that are not fully addressed in the literature:
- When a new charter school emerges in Florida does it have time-series effects on neighboring TPS?
- What are the nature of these effects, if any?

## General Overview
- Extract data from multiple multiple public sources, and make sure the files stay current. 
- Combine the data, perform general cleaning steps, and homogenize key features that will be used later on. 
- Provide accurate location data for the schools. This is tricky because the data from public sources is not reliable. Since schools can change location several times or close, looking up their current location is not a valid approach. I used a hierarchical clustering model and fuzzy string matching, and cross-referenced it with Google Maps when possible. 
- Create a representative measure of charter competition. There are many ways to approach this, and most comparable literature uses simplified metrics that are less accurate. The linear algebra approach we settled on takes the product of distance and enrollment of all surrounding schools, fits a curving function with the best hyperparameters, and then sums these values. 
- Produce time-series models to explore the effects of charter school presence. This required a custom implementation of leave-one-out-cross-validation to improve runtime.

## Technologies Used
- R (tidyverse, data.table, plm, stringdist, ggplot)
- Stata
- Google Cloud Platform API
- Unsupervised machine learning
- Computational linear algebra
- Time-series regression

# Code

## Notes
[Data Dictionary](https://docs.google.com/spreadsheets/d/1w-w7T3FAB0RLbvLk99KsqqPeYc_2AcSK3gtDrOsGLI0/edit#gid=188439690)



## Manual Data Editing

**src/school_types_include.csv** </br>
This is a subset of the schools that were not easily classifiable as charter/non-charter and as regular/non-regular in the data. For each school in this list discretion was used to determine if a school is to be included in the study. For some schools only certain years are excluded. The aim is to only include charter schools and traditional public schools in years that they were operational. 

**src/manually_corrected_locations.csv**</br>


## Data Sources
All sources will eventually contain data 1999 through 2018, some are currently a year or two behind 2018

**Urban Institute Dataset** (https://educationdata.urban.org/data-explorer/schools/) downloaded 06/04/20 
Most information comes from the common core of data [partial data dictionary](https://nces.ed.gov/ccd/psadd.asp)
contains general information about:
- enrollment
- lowest/highest grade offered
- charter status
- virtual status
- latitude & longitude


**Latitude & Longitude** Pulled from one file from ELSI, source of coordinates is CCD
(https://nces.ed.gov/ccd/elsi/) downloaded 06/15/20


**Grade-wise enrollment** Pulled as four separate files from ELSI table generator, then combined 
(https://nces.ed.gov/ccd/elsi/) downloaded 06/05/20


**School grades datasets** (http://www.fldoe.org/accountability/accountability-reporting/school-grades/archives.stml)
1999 - 2017
- Test scores
- School grade


**Student demographics** (https://nces.ed.gov/ccd/elsi/tableGenerator.aspx)
1997 - 2016
- Total enrollment
- Highest and lowest grade
- Teachers & pupil teacher ratio
