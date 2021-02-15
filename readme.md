### Notes
[Data Dictionary](https://docs.google.com/spreadsheets/d/1w-w7T3FAB0RLbvLk99KsqqPeYc_2AcSK3gtDrOsGLI0/edit#gid=188439690)

### Manual Data Editing

**src/school_types_include.csv** </br>
This is a subset of the schools that were not easily classifiable as charter/non-charter and as regular/non-regular in the data. For each school in this list discretion was used to determine if a school is to be included in the study. For some schools only certain years are excluded. The aim is to only include charter schools and traditional public schools in years that they were operational. 

**src/manually_corrected_locations.csv**</br>


### Data Sources
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
