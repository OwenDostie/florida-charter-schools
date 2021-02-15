

# merge and fix ----

# merge urban institure (ui) with enrollment (gwe)
setkey(ui,ncessch,year); setkey(gwe,ncessch,year)
merge(ui %>% select(-enrollment),gwe,all.x=T,by=c("ncessch","year")) -> df
if (nrow(ui) != nrow(df)) warning("New df has a different number of rows than the urban institute data, and it shouldn't")
df[is.na(enrollment),enrollment:=0]; df[,prek_enr:=nafill(prek_enr)]; df[,k_enr:=nafill(k_enr)]
for (col in c("prek_enr","k_enr",paste0("grade",1:12,"_enr"))) { df[[col]]<-nafill(df[[col]], fill=0) }

# get latlon from df_old 
# this step is unnecessary for anyone attempting to reproduce the code, but was helpful for manually correcting coordinates
setkey(df_old,key_sch); setkey(df,key_sch)
df <- merge(df %>% select(-latitude,-longitude),df_old %>% select(manual_lat_original = latitude,manual_lon_original = longitude, key_sch, moved),all.x = T)

# mark school type for schools that have never had a k-12 student
df[ncessch %in% (df[,sum(enrollment),by=ncessch] %>% filter(V1 == 0) %>% pull(ncessch)) & school_type == "regular school",school_type:="never any k-12 students"]

# correctly label NA values
df[street_location %in% c("Missing/not reported",""), street_location:=NA]
df[city_location %in% c("Missing/not reported",""), city_location:=NA]

# create inclusion columns ----

# create columns for distinctly charter and distinctly regular schools. 
# for the origins of the fields used in this calculation, see src/transform_urban_institute.R
df[,`:=`(distinct_regular = F, distinct_charter = F, distinct_regular_nc = F)]
# we have defined a distinct regular school as a non-virtual school where school_type == "regular school" for every year that k12 enrollment is greater than 0
df[ncessch %in% df[k12_enrollment > 0 & virtual == "no",mean(school_type == "regular school"),by=ncessch][V1 == 1,ncessch],distinct_regular:=T]
# we have defined a distinct charter school as a non-virtual charter where charter == "yes" for every year that k12 enrollment is greater than 0
df[ncessch %in% df[k12_enrollment > 0 & virtual == "no",mean(charter == "yes"),by=ncessch][V1 == 1,ncessch],distinct_charter:=T]
# we have defined a distinct regular non-charter as non-virtual charter where charter == "no" for every year that k12 enrollment is greater than 0
df[ncessch %in% df[k12_enrollment > 0 & virtual == "no" & distinct_regular==T,mean(charter == "no"),by=ncessch][V1 == 1,ncessch],distinct_regular_nc:=T]
#df[,distinct_regular:=NULL]

# create include column
# a school is unambiguous regular/non-regular if it is the same school type for all years where enrollment > 0
if (sum(is.na(df$school_type)) > 0) warning("there are observations with a missing school_type")
df[enrollment > 0,.(include = case_when(
  mean(school_type == "regular school") == 1 ~ "unambiguous-regular",
  mean(school_type == "regular school") == 0 ~ "unambiguous-nonregular",
  TRUE ~ "ambiguous-exclude-rule"
)),by=ncessch] %>% as.data.table -> st
df <- merge(df,st,all.x=T,by="ncessch")
# manually include/exclude schools that are not distinct and unambiguous. For details on the criteria for inclusion see readme.md
st <- fread("src/school_types_include.csv") %>% as.data.table %>% select(ncessch,year,Include)
df <- merge(df,st, by=c("ncessch","year"),all.x=T)
df <- df[!is.na(Include),include:=case_when(Include == 1 ~ "ambiguous-include-manual", Include == 0 ~ "ambiguous-exclude-manual")] %>% select(-Include)


# finish off ----


# additional data validation
if (df[,.N,by=.(ncessch,year)][N > 1] %>% nrow() > 0) warning("ncessch, year is no longer a unique key. This may be an issue with one of the merges\n")
#rm(gwe,ui,df_old,st)
