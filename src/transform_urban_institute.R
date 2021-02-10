
# read
ui <- fread("src/ui_data_06_04_20.csv", stringsAsFactors = F, integer64 = "numeric", na.strings = c("","Missing/not reported","Not applicable","NA","†","‡","–")) %>% as.data.table

# detect na
na_if(ui,c("")) %>% na_if("Missing/not reported") %>% na_if("Not applicable")

# drop two rows without data
ui <- ui[!school_name == ""]

# create backups of all columns modified
ui$virtual_original <- ui$virtual; ui$school_status_original <- ui$school_status; 
ui$school_type_original <- ui$school_type; ui$charter_original <- ui$charter
ui$street_location_original <- ui$street_location; ui$city_location_original <- ui$city_location; ui$zip_location_original <- ui$zip_location
ui$nces_lat_original <- ui$latitude; ui$nces_lon_original <- ui$longitude
names(ui)[names(ui) %like% "lon"]

# fix the `virtual` column
# if a school is marked as virtual at least once it is recorded as virtual for all years. 
ui[,virtual:=tolower(virtual)]
ui[grepl("VIRTUAL|FLVS|CYBER|INTERNET|CONNECTIONS ACADEMY|ONLINE",school_name),virtual:="yes"]
ui[ncessch %in% ui[virtual=="yes", unique(ncessch)],virtual:="yes"]
ui[ncessch %in% ui[virtual=="no",unique(ncessch)],virtual:="no"]
ui[virtual %!in% c("yes","no"),virtual:="no"]

# fix the `school_type` column
ui[,school_type:=tolower(school_type)]
ui[lea_name == "FLORIDA SCHOOL FOR THE DEAF AND THE BLIND" | grepl("FSDB|DEAF|BLIND",school_name), school_type:="special education school"]
ui[grepl("DETENTION|SHERIFF|CORRECTIONS|STOP CAMP|HALFWAY HOUSE|RESOURCES SHELTER|WINGS ACADEMY|COMPETENCY RESTORATION",school_name),  school_type:="detention/correction center"]
ui[grepl("OFFICE(?!R)|SUPERIN",school_name,perl=T), school_type:="office"]
ui[grepl("ADULT",school_name), school_type:="adult education"]

# fix the nces_lat and nces_lon column
ui$nces_lat <- na_if(ui$latitude,"") %>% na_if(.,"Not applicable")
ui$nces_lon <- na_if(ui$longitude,"") %>% na_if(.,"Not applicable")

ui$nces_lat %>% nchar%>% table
# fix the `school_status` column
ui[,school_status:=tolower(school_status)]

# fix the `school_level` column
ui[,school_level:=tolower(school_level)]

# fix the `charter` column
ui[,charter:=tolower(charter)]

# create distnum schnum and key_sch
!grepl("^\\d{2}-\\d{4}$",ui$seasch) & !grepl("^\\d{1,4}$",ui$seasch) -> ui$invalid_seasch
ui$seasch[ui$invalid_seasch] <- NA
for (obs in unique(ui$ncessch[ui$invalid_seasch])) {
  ui$seasch[ui$ncessch == obs & is.na(ui$seasch)] <- sort(table(ui$seasch[ui$ncessch == obs]), descending = T) %>% names() }
ui$distnum_schnum <- 
  paste0(sprintf("%02d",as.numeric(substr(ui$state_leaid,nchar(ui$state_leaid)-1,nchar(ui$state_leaid)))), "-",
         sprintf("%04d",as.numeric(substr(ui$seasch,nchar(ui$seasch)-3,nchar(ui$seasch))))  )
ui$key_sch <- paste0(ui$distnum_schnum,"_",ui$year)
ui <- ui %>% select(-invalid_seasch)

# drop schools with closed or inactive status

# Data validation ----
rm(obs)