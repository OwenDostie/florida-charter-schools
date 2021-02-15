# Prepare ----


# look only at schools that aren't virtual, and are certainly regular.
df <- df[(distinct_charter==T | distinct_regular_nc==T) & enrollment > 0]

# remove PO boxes from street_location
df[grepl("P\\.O\\.|P O|P\\. O\\.|PO POST OFFICE|BOX|N\\/A",street_location),street_location:=NA]

# remove all . and , from addresses
df[,street_location:=str_replace_all(street_location, "\\.|\\,|\\#|\\`", "")]; df[,street_location:=str_replace_all(street_location, "\\&", "AND")]
df[,city_location:=str_replace_all(city_location, "\\.|\\,|\\#|\\`", "")]; df[,city_location:=str_replace_all(city_location, "\\&", "AND")]

# condense addresses to abbreviations
aa <- fread("src/address_abbreviations.csv")
for (r in 1:nrow(aa)) {
  df[,street_location:=gsub(aa$replace[r],aa$with[r],street_location)]
}

# assume that the most popular zip code with 5 digits is the correct one, otherwise NA
df[ncessch %in% df[nchar(zip_location)!=5,ncessch],zip_location:=if_else(sum(nchar(zip_location)==5)==0,as.character(NA),zip_location[nchar(zip_location)==5]%>%table()%>%sort(decreasing=T)%>%names()%>%head(1)),by=c("street_location","city_location")]


# Fill NA street_locations and corresponding city_location (13.5s) ----


setkey(df,ncessch,year)
ml <- df[is.na(street_location),ncessch]
for (nces in ml) {
  # print(nces)
  df[ncessch == nces,street_location] -> o
  if (all(is.na(o))) next
  o2 <- o; c <- df[ncessch == nces,city_location]
  for (i in which(is.na(o))) {
    # v is the indeces of valid values
    v = which(!is.na(o))
    # set the value of o at index i to the nearest name in v
    o2[i] <- o[v[last(which(abs(i - v) == min(abs(i - v))))]]
    c[i] <- c[v[last(which(abs(i - v) == min(abs(i - v))))]]
    c[v[last(which(abs(i - v) == min(abs(i - v))))]]
    c
  }
  df[ncessch == nces,street_location:=o2]
  df[ncessch == nces,city_location:=c]
}
#df[ncessch %in% ml] %>% select(ncessch,year,street_location,street_location_original,state_location,city_location,everything())


# Merge df with geocode ----


# Add ccd latitude & longitude to the final df
t_f <- fread("src/ccd_coordinates.csv", na.strings = c("","Missing/not reported","Not applicable","NA","†","‡","–"), integer64 = "double") %>% as.data.table
for (y in 2000:2018) {
  t_f
  select(t_f,ncessch = "School ID - NCES Assigned [Public School] Latest available year", 
         ccd_lon = paste0("Longitude [Public School] ",y,"-",substr(y+1,3,4)),
         ccd_lat = paste0("Latitude [Public School] ",y,"-",substr(y+1,3,4))) %>%
    mutate(year = y) -> t_fy
  if (exists('ll')) { ll <- rbind(ll, t_fy) } else { ll <- t_fy %>% as.data.table }
}
ll <- ll[!is.na(ncessch) & !is.na(year) & !is.na(ccd_lon) & !is.na(ccd_lat)]
setkey(ll,ncessch,year); setkey(df,ncessch,year)
df <- merge(df,ll,all.x=T)

# Add google geocoding to final df
# these csv files were created by src/geocode_addresses.R
adl <- fread("src/gm_addresses.csv", na.strings = "") %>% as.data.table() %>% distinct()
df <- merge(df,adl,by=c("street_location","city_location"),all.x=T)
if (df[,.(.N),by=.(ncessch,year)][N>1] %>% nrow > 1) warning("\nncessch,year is not a unique key")
# update gm_lat and gm_lon columns with second batch of query results 
adl2 <- fread("src/gm_addresses2.csv", na.strings = "") %>% filter(!is.na(street_location)) %>% as.data.table()
adl2[,zip_location:=as.character(zip_location)]
# the google geocoding queries are based on street_location, city_location and zip_location so the tables are joined based on these fields
df <- merge(df,adl2,by=c("street_location","city_location","zip_location"),all.x=T)
names(df)[grepl("\\.x|\\.y",names(df))] -> t_names
for (n in substr(t_names,1,nchar(t_names)-2) %>% unique) {
  df[!is.na(get(paste0(n,".y"))),c(paste0(n,".x")):=get(paste0(n,".y"))]
  df[,c(paste0(n,".y")):=NULL]
  setnames(df,c(paste0(n,".x")),c(paste0(n)))
}

# Correct single observations surrounded by a more common observation
df[,`:=`(gm_lat_original = gm_lat, gm_lon_original = gm_lon, gm_formatted_address_original = gm_formatted_address)]
setkey(df,ncessch,year)
for (nces in df[,.(ncoords=nrow(unique(.SD[,.(gm_lat,gm_lon)]))),by=ncessch][ncoords>1,ncessch]) {
  r <- df[ncessch == nces, .(gm_lat,gm_lon,gm_formatted_address)]
  # are we looking at a row that occupies less than half of the values, and is surrounded by values that are equal to eachother
  for (i in 1:max(1,nrow(r))) {
    if (i %!in% c(1,nrow(r))) {
      if (nrow(r[gm_lat == r[i,gm_lat] & gm_lon == r[i,gm_lon]]) / nrow(r) < 0.5) {
        if (all(r[i-1,c(gm_lat,gm_lon)] == r[i+1,c(gm_lat,gm_lon)])) {
          if (all(r[i,c(gm_lat,gm_lon)] != r[i+1,c(gm_lat,gm_lon)])) {
            #warning(paste0(i,"  ",nces," | "))
            r[i,`:=`(gm_lat = r[i+1,gm_lat], gm_lon = r[i+1,gm_lon], gm_formatted_address = r[i+1,gm_formatted_address])]
          }
        }
      }
    }
  }
  df[ncessch == nces,`:=`(gm_lat = r$gm_lat,gm_lon = r$gm_lon,gm_formatted_address = r$gm_formatted_address)]
}


# Data flagging & correction ----


# The flagging system works sequentially, so that once a school has been flagged it is no longer looked at for the remaining flags
# This allows us to sort through all of the schools that we can reasonably assume remained stationary.
# For certain simple errors we are able to correct the data programatically as well, which greatly reduced the amount of work that has to be done manually. 
# The flag of each school is marked in the wildcard (renamed to 'location_class') column of schools so that the type of error correction (if any) is traceable. 

# dominant address is the mode address
df[,wildcard:=as.numeric(NA)]
df[,`:=`(median_lat=median(gm_lat,na.rm=T), median_lon=median(gm_lon,na.rm=T), dominant_address=names(sort(table(gm_formatted_address,useNA="always"),dec=T))[1],
         dominant_address_share=mean(gm_formatted_address == names(sort(table(gm_formatted_address),dec=T))[1],na.rm=T)),by=ncessch]

# flag 1
# multiplication by 3.28084 is to convert from meters to feet. 
# any school where its location each year is no more than 1000 ft from its location every other year is flagged with wildcard=1 for all years.
# for these schools that we flagged 1 it is safe to assume that school has remained stationary for all years that we are observing. 
df[,.(mlat = median(gm_lat,na.rm=T), mlon = median(gm_lon,na.rm=T),
      maxdist = max(geosphere::distHaversine(c(median(gm_lon,na.rm=T),median(gm_lat,na.rm=T)), matrix(c(gm_lon,gm_lat),ncol=2,byrow=F)), na.rm=F)*3.28084
),by=ncessch][maxdist <= 1000,ncessch] -> t_nces
df[ncessch %in% t_nces,wildcard:=1]

# flag 2
# flag 2 only looks at schools that have not yet been flagged
# 2) Is this true: The address is the same over half the years, and in each year the address differs from the most common address, in the year before and after it was equal to the most common address. If yes, adopt the median latitude and median longitude associated with the address over all years. If not:

setkey(df,ncessch,year)
for (nces in df[is.na(wildcard) & dominant_address_share > 0.5,unique(ncessch)]) {
  r <- df[ncessch == nces, .(gm_formatted_address,dominant_address)]
  maddress <- r[,first(dominant_address)]
  # are we looking at a row that occupies less than half of the values, and is surrounded by values that are equal to eachother
  success = T
  for (i in 1:max(1,nrow(r))) {
    if (i %!in% c(1,nrow(r))) {
      if (r[i,gm_formatted_address != maddress]) {
        if (r[i-1,gm_formatted_address] != maddress | r[i+1,gm_formatted_address] != maddress) {
          success = F
        }
      }
    }
  }
  if (success == T) df[ncessch == nces,wildcard:=2]
}

# flag 3
# 3) Is this true: The address is the same over half the years, and the latitude and longitude provided by nces are within a 1K radius for all years? If yes, adopt the median latitude and median longitude associated with the address over all years. If not:
df[is.na(wildcard) & dominant_address_share > 0.5,.(mlat = median(ccd_lat,na.rm=T), mlon = median(ccd_lon,na.rm=T),
                                                    maxdist = max(geosphere::distHaversine(c(median(ccd_lon,na.rm=T),median(ccd_lat,na.rm=T)), matrix(c(ccd_lon,ccd_lat),ncol=2,byrow=F)), na.rm=F)*3.28084
),by=ncessch][maxdist <= 1000,ncessch] -> t_nces
df[ncessch %in% t_nces,wildcard:=3]

# flag 4
# 4) Is this true: The address is the same over half the years, and takes on that common value in the first and last years. If it differs in year t, the address was the same in t-1 and t+1? If yes, adopt the median latitude and median longitude associated with the address over all years. If not:
for (nces in df[is.na(wildcard) & dominant_address_share > 0.5,unique(ncessch)]) {
  r <- df[ncessch == nces, .(gm_formatted_address,dominant_address)]
  maddress <- r[,first(dominant_address)]
  # are we looking at a row that occupies less than half of the values, and is surrounded by values that are equal to eachother
  success = T
  if (r[1,gm_formatted_address] != maddress | r[nrow(r),gm_formatted_address] != maddress) { success = F; break}
  for (i in 1:max(1,nrow(r))) {
    if (i %!in% c(1,nrow(r))) {
      if (r[i,gm_formatted_address != maddress]) {
        if (r[i-1,gm_formatted_address] == r[i+1,gm_formatted_address]) {
          success = F
        }
      }
    }
  }
  if (success == T) df[ncessch == nces,wildcard:=4]
}

# flag 5
# 5) Is this true: The address is the same over half the years, and if it differs in year t, and year t is not the first or last year, the address was the same in t-1 and t+1, if the address differs in the first or last year, the latitude and longitude provided by nces are nearly the same (I know these seem to vary randomly, so not identical, but within say 500 feet) in first year as the second year, and/or in the last year as in the second to last year? If yes, adopt the median latitude and median longitude associated with the address over all years. If not:
for (nces in df[is.na(wildcard) & dominant_address_share > 0.5,unique(ncessch)]) {
  r <- df[ncessch == nces, .(gm_formatted_address,dominant_address,ccd_lon,ccd_lat,median_lon,median_lat)]
  maddress <- r[,first(dominant_address)]
  # are we looking at a row that occupies less than half of the values, and is surrounded by values that are equal to eachother
  success = T
  if (is.na(r[1,ccd_lon]) | is.na(r[1,ccd_lat]) | is.na(r[nrow(r),ccd_lon]) | is.na(r[nrow(r),ccd_lat])) {success = F; break}
  if (geosphere::distHaversine(r[1,.(ccd_lon,ccd_lat)],r[2,.(ccd_lon,ccd_lat)])*3.28084 > 1000) {
    success = F; break }
  if (geosphere::distHaversine(r[1,.(ccd_lon,ccd_lat)],r[2,.(ccd_lon,ccd_lat)])*3.28084 > 1000) {
    success = F }
  for (i in 1:max(1,nrow(r))) {
    if (i %!in% c(1,nrow(r))) {
      if (r[i,gm_formatted_address != maddress]) {
        if (r[i-1,gm_formatted_address] == r[i+1,gm_formatted_address]) {
          success = F
        }
      }
    }
  }
  if (success == T) df[ncessch == nces,wildcard:=5]
}

pp = 0
p <- function() {pp <<- pp+1; print(pp)}

# flag 6
# 6) Is this true: The latitude and longitude provided by nces are within a 1K radius for all years? If yes, adopt the median latitude and median longitude from NCES. If not:
df[is.na(wildcard),.(mlat = median(ccd_lat,na.rm=T), mlon = median(ccd_lon,na.rm=T),
                     maxdist = max(geosphere::distHaversine(c(median(ccd_lon,na.rm=T),median(ccd_lat,na.rm=T)), matrix(c(ccd_lon,ccd_lat),ncol=2,byrow=F)), na.rm=F)*3.28084
),by=ncessch][maxdist <= 1000,ncessch] -> t_nces
df[ncessch %in% t_nces,wildcard:=6]

# rename wildcard
setnames(df,"wildcard","location_class")

rm(t_nces, maddress, r, nces)

# create location_verificaton_method
df[,location_verification_method:=""]

# c - single coordinates verification
df[ncessch %in% df[,nrow(unique(.SD[,.(gm_lat,gm_lon)]))==1,by=ncessch][V1==T,ncessch], 
   location_verification_method:=paste0(location_verification_method,"c")]

# fill(df,c(manual_lon_original,manual_lat_original), .direction = "up") %>% select(manual_lon_original, manual_lat_original)

# l - latlon verification 
df[!is.na(manual_lat_original) & #geosphere::distHaversine(matrix(c(gm_lon,gm_lat),ncol=2,byrow=F), matrix(c(geo_longitude,geo_latitude),ncol=2,byrow=F))*3.28084 < 1000 & 
     geosphere::distHaversine(matrix(c(gm_lon,gm_lat),ncol=2,byrow=F), matrix(c(manual_lon_original,manual_lat_original),ncol=2,byrow=F))*3.28084 < 1000,
   location_verification_method:=paste0(location_verification_method,"l")] #%>% select(gm_formatted_address,street_location,zip_location, city_location,location_verification_method) %>% filter(stringi::stri_detect_fixed(gm_formatted_address,zip_location)) %>% View

# z - zip verification
df[stringi::stri_detect_fixed(gm_formatted_address, zip_location),location_verification_method:=paste0(location_verification_method,"z")]

# r - radius verification (and s) #### 

nrow(unique(df[,.(gm_lat,gm_lon)]))
ncs <- df[,.(ncoords=nrow(unique(.SD[,.(gm_lat,gm_lon)])),nvalid=sum(!is.na(gm_lat))),by=ncessch][nvalid>=2]
for (nces in ncs[ncoords>1,ncessch]) {
  # for (nces in 120003003981) {  
  lids <- df[ncessch == nces & !is.na(gm_lon), .(location_id = .GRP,firstyear=first(year),lastyear=last(year)), by=.(gm_lat,gm_lon)]
  ld <- dist(lids[,.(gm_lat, gm_lon)], method="euclidean")
  hc <- hclust(ld, method = "average")
  lids[,cluster:=cutree(hc,h=0.0032)]
  
  # if the school didn't move more than 1000 ft.
  if (length(unique(lids$cluster)) == 1) {
    df[ncessch == nces, `:=`(gm_formatted_address = names(sort(table(gm_formatted_address),dec=T))[1],
                             gm_lat = names(sort(table(gm_lat),dec=T))[1] %>% as.double(), gm_lon = names(sort(table(gm_lon),dec=T))[1] %>% as.double(),
                             location_verification_method=paste0(location_verification_method,"r"))]
  }
  if (length(unique(lids$cluster)) > 1) {
    t_y <- as.numeric(NA)
    for (i in 1:nrow(lids)) {
      t_y <- c(t_y,lids[i,c(firstyear:lastyear)])
    }
    if (duplicated(t_y) %>% sum == 0) df[ncessch == nces, latlon_verification_method:=paste0(location_verification_method,"R")]
    df[ncessch == nces,max_move_dist:=max(dist(lids[,.(gm_lon,gm_lat)]))]
  }
}

# ordering the groups in time so that the periods of time are continuous. 

#for (nces in ncs[ncoords==1,ncessch]) {df[ncessch == nces, location_verification_method:=paste0(location_verification_method,"s")]}


# Manually alter rows ----

dv <- fread("src/manually_corrected_locations.csv",integer64 = "double") %>% as.data.table
dv$ncessch <- as.numeric(dv$ncessch)

df$manual_exclude <- FALSE
df$ncessch_new <- as.character(NA)
for (row in 1:nrow(dv)) {
  if (dv[row,rep_type] == "") next
  
  if (dv[row,rep_type] == "n") {
    df[ncessch == dv[row,ncessch],ncessch_new:=dv[row,ncessch_rep]]; next
  }
  
  if (dv[row,rep_type] == "na") {
    if (!is.na(dv[row,rep_year])) { 
      df[ncessch == dv[row,ncessch],`:=`(
        gm_lat = df[ncessch == dv[row,ncessch_rep] & year == dv[row,rep_year],gm_lat],
        gm_lon = df[ncessch == dv[row,ncessch_rep] & year == dv[row,rep_year],gm_lon],
        gm_formatted_address = df[ncessch == dv[row,ncessch_rep] & year == dv[row,rep_year],gm_formatted_address],
        ncessch = dv[row,ncessch])
        ] }
    df[ncessch == dv[row,ncessch],ncessch_new:=dv[row,ncessch_rep]]
    next
  }
  
  if (dv[row,rep_type] == "ngeo") {
    # want to use address_mailing for this one, and the geocoded location
    next
  }
  
  if (dv[row,rep_type] == "d") {
    df[ncessch == dv[row,ncessch],manual_exclude:=TRUE]
  }
  
  if (dv[row,rep_type] %!in% c("m","y","f")) next
  
  # address replacements ----
  
  
  y <- as.numeric(dv[row,substr(year,1,4)]):as.numeric(dv[row,substr(year,nchar(year)-3,nchar(year))])
  
  if (dv[row,rep_type] == "m") {
    df[ncessch == dv[row,ncessch] & year %in% y, `:=`(gm_formatted_address=df[ncessch == dv[row,ncessch] & year %!in% y,head(names(sort(table(gm_formatted_address),decr=T)),1)],
                                                      gm_lat=df[ncessch == dv[row,ncessch] & year %!in% y,median(gm_lat,na.rm=T)], gm_lon=df[ncessch == dv[row,ncessch] & year %!in% y,median(gm_lon,na.rm=T)])]
  }
  
  if (dv[row,rep_type] == "y") {
    df[ncessch == dv[row,ncessch] & year %in% y, `:=`(gm_formatted_address=df[ncessch == dv[row,ncessch] & year == dv[row,rep_year], gm_formatted_address],
                                                      gm_lat=df[ncessch == dv[row,ncessch] & year == dv[row,rep_year], gm_lat], gm_lon=df[ncessch == dv[row,ncessch] & year == dv[row,rep_year], gm_lon])]
  }
  
  if (dv[row,rep_type] == "f") {
    df[ncessch == dv[row,ncessch] & year %in% y, `:=`(gm_formatted_address=dv[row,gm_formatted_address],
                                                      gm_lat=dv[row,gm_lat], gm_lon=dv[row,gm_lon])]
  }
}


# Create distance matrix ----

#if (file.exists("src/distance_matrix.csv")) { dm <- fread("src/distance_matrix.csv"); stop("Distance matrix load ed from file (not a real error)") }
dmlids <- df[!is.na(gm_lat) & !is.na(gm_lon),.(location_id=.GRP),by=c("gm_lat","gm_lon")]
dm <- matrix(data = as.numeric(NA), ncol=nrow(dmlids), nrow = nrow(dmlids))
for (row in 1:nrow(dmlids)) {
  dm[row,] <- geosphere::distHaversine(dmlids[row,.(gm_lon,gm_lat)], dmlids[,.(gm_lon,gm_lat)])
}

# convert from meters to miles
dm <- dm*0.000621371

if !(file.exists("src/distance_matrix.csv")) fwrite(dm,"src/distance_matrix.csv")
df <- merge(df,dmlids,all.x=T,by=c("gm_lat","gm_lon"))


# create enrollment columns ----


nrow(df)
# delete all names that are generated by the algorithm so that we don't add duplicate columns
df[,names(df)[grep("tpse|^ce|ntps|ncharter",names(df))] := NULL]
as.numeric(grep("tpse|^ce|ntps|ncharter",names(df)))


for (r in c(1,2.5,5,10)) {
  dm_bool <- (dm < r)
  for (y in 1999:2018) {
    tps_ids <- df[charter=="no" & year == y,.(k_enr=sum(k_enr,na.rm=T),g1_enr=sum(grade1_enr,na.rm=T),g2_enr=sum(grade2_enr,na.rm=T),g3_enr=sum(grade3_enr,na.rm=T),g4_enr=sum(grade4_enr,na.rm=T),g5_enr=sum(grade5_enr,na.rm=T), g6_enr=sum(grade6_enr,na.rm=T),g7_enr=sum(grade7_enr),g8_enr=sum(grade8_enr,na.rm=T),g9_enr=sum(grade9_enr,na.rm=T),g10_enr=sum(grade10_enr,na.rm=T),g11_enr=sum(grade11_enr,na.rm=T),g12_enr=sum(grade12_enr,na.rm=T),tot_enr=sum(enrollment,na.rm=T)),by=location_id][!is.na(location_id)]
    charter_ids <- df[charter=="yes" & year == y,.(k_enr=sum(k_enr,na.rm=T),g1_enr=sum(grade1_enr,na.rm=T),g2_enr=sum(grade2_enr,na.rm=T),g3_enr=sum(grade3_enr,na.rm=T),g4_enr=sum(grade4_enr,na.rm=T),g5_enr=sum(grade5_enr,na.rm=T), g6_enr=sum(grade6_enr,na.rm=T),g7_enr=sum(grade7_enr),g8_enr=sum(grade8_enr,na.rm=T),g9_enr=sum(grade9_enr,na.rm=T),g10_enr=sum(grade10_enr,na.rm=T),g11_enr=sum(grade11_enr,na.rm=T),g12_enr=sum(grade12_enr,na.rm=T),tot_enr=sum(enrollment,na.rm=T)),by=location_id][!is.na(location_id)]
    #tps enrollments
    loc_enr <- merge(data.table(location_id=c(1:nrow(dm)),key="location_id"),tps_ids,all.x=T,by="location_id") %>% map_df(~nafill(.,fill=0)) %>% as.data.table()
    # charter enrollments
    loc_enr2 <- merge(data.table(location_id=c(1:nrow(dm)),key="location_id"),charter_ids,all.x=T,by="location_id") %>% map_df(~nafill(.,fill=0)) %>% as.data.table()
    setkey(tps_ids,location_id); setkey(charter_ids,location_id)
    
    if (exists("big_enr_charter")) { 
      big_enr_charter <- rbind(big_enr_charter, ((1*dm_bool) %*% as.matrix(loc_enr2[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))])) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y)) 
    } else {
      big_enr_charter <- ((1*dm_bool) %*% as.matrix(loc_enr2[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))])) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y) 
    }
    if (exists("big_enr_tps")) { 
      big_enr_tps <- rbind(big_enr_tps, ((1*dm_bool) %*% as.matrix(loc_enr[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))])) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y)) 
    } else {
      big_enr_tps <- ((1*dm_bool) %*% as.matrix(loc_enr[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))])) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y) 
    }
    if (exists("n_charter")) { 
      n_charter <- rbind(n_charter, ((1*dm_bool) %*% as.matrix(loc_enr2[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))]>=1)) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y)) 
    } else {
      n_charter <- ((1*dm_bool) %*% as.matrix(loc_enr2[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))]>=1)) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y) 
    }
    if (exists("n_tps")) { 
      n_tps <- rbind(n_tps, ((1*dm_bool) %*% as.matrix(loc_enr[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))]>=1)) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y)) 
    } else {
      n_tps <- ((1*dm_bool) %*% as.matrix(loc_enr[,c(paste0(c(paste0("g",1:12),"k"),"_enr"))]>=1)) %>% as.data.table %>% mutate(location_id = 1:nrow(dm), year=y) 
    }
  }
  big_enr_charter <- as.data.table(big_enr_charter); big_enr_tps <- as.data.table(big_enr_tps)
  n_charter <- as.data.table(n_charter); n_tps <- as.data.table(n_tps)
  names(big_enr_charter) <- c(paste0("ce_",r,"m_",names(big_enr_charter)[1:13]),"location_id","year"); names(big_enr_charter) <- gsub("\\_enr","",names(big_enr_charter))
  names(big_enr_tps) <- c(paste0("tpse_",r,"m_",names(big_enr_tps)[1:13]),"location_id","year"); names(big_enr_tps) <- gsub("\\_enr","",names(big_enr_tps))
  names(n_charter) <- c(paste0("ncharter_",r,"m_",names(n_charter)[1:13]),"location_id","year"); names(n_charter) <- gsub("\\_enr","",names(n_charter))
  names(n_tps) <- c(paste0("ntps_",r,"m_",names(n_tps)[1:13]),"location_id","year"); names(n_tps) <- gsub("\\_enr","",names(n_tps))
  df <- merge(df,big_enr_charter,all.x=T,by=c("location_id","year"))
  df <- merge(df,big_enr_tps,all.x=T,by=c("location_id","year"))
  df <- merge(df,n_charter,all.x=T,by=c("location_id","year"))
  df <- merge(df,n_tps,all.x=T,by=c("location_id","year"))
  big_enr_charter <- NULL; big_enr_tps <- NULL;
  n_charter <- NULL; n_tps <- NULL;
}


# Data validation----


setkey(df,ncessch,year); setkey(ui,ncessch,year)
if (df[manual_exclude == F & (is.na(gm_lat) | is.na(gm_lon))] %>% nrow + df[manual_exclude == F & (is.na(gm_lat) | is.na(gm_lon))] %>% nrow > 0) 
  warning("\nThere is at least one row with a missing address or missing coordinates.")
if (nrow(df[manual_exclude == F & distinct_charter == T & ncharter_1m_g10 == 0][grade10_enr != 0]) > 0)
  warning("\nncharter_1m_g10 does not line up with the grade10 enrollment number recorded with distinct charter schools.")
if (max(df[manual_exclude == F,ncharter_5m_g6]) != nrow(df[year == 2018 & distinct_charter==T & grade6_enr > 0 & location_id %in% which(dm[922,]<= 5)]))
  warning("\nA location in Dade county that previouly had 18 6th grade charter schools within 5 miles has had this calculation altered.")
(nrow(ui) - (nrow(ui[!df]) + nrow(df[manual_exclude==F])) ) %>% 
  warning(paste0("rows are included in neither sch_exclude nor sch_include"))
# there are still NA values remaining
if (length(t_names) != 12) warning("\ndifferent number of columns than expected after merging 2nd batch of locations")
rm(adl2,t_names,o2,o,ml,v,i,nces,t_f,t_fy,r,aa)
