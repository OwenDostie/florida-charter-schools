# Add school grades & performance measures to the dataset
	

# load data
sg14 <- fread("src/school_grades/School_Grades_1999-2014_v2.csv", integer64 = "double") %>% as.data.table
sg19 <- fread("src/school_grades/School_Grades_2015-2019_v2.csv", integer64 = "double") %>% as.data.table

# school grades refer to the year at the end of the schoolyear, our data refers to the beginning of the schoolyear so to have the 
# merge work properly subtracting 1 from the year of the school grades makes sense. We don't care about grades in 1998
sg14$Year <- sg14$Year-1; sg19$Year <- sg19$Year-1; sg14 <- sg14[Year >= 1999]

# fix a couple of issues with sg19, including some duplicate rows that I don't know the source of
sg19[,Grade := `Grade in Year tested`]; sg19 <- unique(sg19)

# create distnum_schnum
sg19[,distnum_schnum := paste0(str_pad(`District Number`, 2, side="left", pad=0),"-", str_pad(`School Number`, 4, side="left", pad=0))]
sg14[Year%!in%c(2002,2003),distnum_schnum := paste0(str_pad(`District Number`, 2, side="left", pad=0),"-", str_pad(`School Number`, 4, side="left", pad=0))]
sg14[Year%in%c(2002,2003),distnum_schnum := (paste0(str_pad(`School Number`, 6, side="left", pad=0) %>% substr(1,2),"-", str_pad(`School Number`, 6, side="left", pad=0) %>% substr(3,6))) ]


# clean columns; create keys
setnames(sg14, names(sg14), gsub(" ","_",tolower(names(sg14)))); setnames(sg19, names(sg19), gsub(" ","_",tolower(names(sg19))))

# create ncessch_new in sg14 to capture whether a school had multiple grade levels at the same time
# and it was stored as several observations in the data
sg14[sg14[by=c("year","distnum_schnum"),,.N][N!=1], ncessch_suffix:=c("_e","_m","_h","_c")[school_type], on=c("year","distnum_schnum") ]

# drop irrelevant columns
sg19[,c("district_name","district_number","school_number","school_name","school_type","region","charter_school"):=NULL]
sg14[,c("district_name","district_number","school_number","school_name","school_type"):=NULL]

# merge the two school grades files
setkey(sg19,distnum_schnum,year); setkey(sg14,distnum_schnum,year)
sg <- merge(sg19,sg14,all=T)
sg[,`:=`(  comb_school_grade=coalesce(grade.x,grade.y), percent_tested = coalesce(percent_tested.x,percent_tested.y)  )]
sg[,names(sg)[grep("\\.[xy]",names(sg))] := NULL]
suppressWarnings(df[,setdiff(names(sg),c("distnum_schnum","year")):=NULL])

# merge them with df, this will add rows; create ncessch_new
setkey(df,distnum_schnum,year); setkey(sg,distnum_schnum,year)
df <- merge(df,sg,all.x=T)
df[is.na(ncessch_new),ncessch_new:=paste0(ncessch,replace_na(ncessch_suffix,""))]
df[ncessch_suffix=="_e",c(paste0("grade",c(6:12),"_enr")):=0]
df[ncessch_suffix=="_m",c(paste0("grade",c(1:5,9:12),"_enr")):=0]
df[ncessch_suffix=="_h",c(paste0("grade",c(1:8),"_enr")):=0]
df[ncessch_suffix %in% c("_m","_h"), "k_enr":=0]
df[,ncessch_suffix:=NULL]


# Performance measures ----
# Create aggregate school performance columns & other fixes
# depending on the year there is a different measure for school grades. 
# it is necessary to coalesce these test scores into one column for the regression.
# any variation in the test scores will be accounted for by the year dummy. 


names(df)

# math_proficiency
df[,comb_math_proficiency:=coalesce(math,percent_level_3_and_above_fcat_math)]

# ela proficiency
df[,comb_ela_proficiency:=coalesce(english_language_arts, rowMeans(matrix(c(percent_level_3_and_above_fcat_reading, percent_level_3_and_above_writing),ncol=2,byrow=F), na.rm=T))]

# ela_gains
df[,comb_ela_gains:=coalesce(english_language_arts_gains, percente_making_learning_gains_in_reading)]
df[,comb_math_gains:=coalesce(math_gains, percente_making_learning_gains_in_math)]
df[,comb_ela_gains_lowest_25:=coalesce(`english_language_arts_gains_of_lowest_25%`, percent_of_lowest_25p_making_learning_gains_in_reading)]

# grades is a character vector of all the grades
grades <- paste0(c("k",paste0("grade",1:12)),"_enr")

# generate teacher_enrollment_ratio
df$teacher_student_ratio <- df$teachers_fte/df$enrollment

# abbreviate pct
setnames(df, names(df), gsub("percente?","pct" ,names(df)))

# replace names
setnames(df, c("english_language_arts_gains_of_lowest_25%", "college_&_career_acceleration(prev_year)", "pct_of_economically_disadvantaged_students", "pct_level_3_and_above_fcat_reading" , "pct_making_learning_gains_in_reading",  "pct_making_learning_gains_in_math", "pct_of_lowest_25p_making_learning_gains_in_reading"), 
         c("ela_gains_lowest_25","college_and_career_acc", "pct_econ_disadv_students", "pct_l3_and_above_reading","pct_making_gains_reading",  "pct_making_gains_math", "pct_lowest_25p_gains_reading"), skip_absent = T)

# drop fully irrelevant columns
df[,c("gm_street_number","gm_route","gm_postal_code"):=NULL]

# groupagg turns a vector of numeric values to the sum, and turns a non-numeric vector to the first value
groupagg <- function(x) {
  if (length(unique(x)) > 1 & is.numeric(x)) {
    return(sum(x,na.rm=T) %>% as.double)
  } else {
    return(first(x))
  }
}

# when a school grade is not unanimous remove the school
df[by=.(ncessch,year),,.N][N > 1,.(ncessch,year)] -> dups
df[dups,on=.(ncessch,year), comb_school_grade:=NA]

# convert the columns we're going to aggregate to double 
repcols = c("pct_l3_and_above_reading","pct_level_3_and_above_fcat_math","pct_level_3_and_above_writing","pct_tested","comb_ela_proficiency","comb_math_proficiency")
df[,(repcols):=lapply(.SD,as.double),.SDcols=repcols]

# correct the enrollment column for aggregated schools
df[dups,on=.(ncessch,year),  enrollment:=rowSums(sapply(grades,function(x) df[dups,on=.(ncessch,year)][[x]])) ]

# creaate aggregate columns, and then collapse duplicates from the dataset.
df[dups,on=.(ncessch,year),by=.(ncessch,year),(repcols):=lapply(.SD*enrollment, function(x) groupagg(x)/sum(enrollment,na.rm=T)),.SDcols=repcols]
df[dups,on=.(ncessch,year),by=.(ncessch,year),(c(grades,"enrollment")):=lapply(.SD, function(x) sum(x,na.rm=T)),.SDcols=c(grades,"enrollment")]

# drop duplicate rows
df[,ncessch_new:=substr(ncessch_new,1,12)]; df %>% distinct -> df

# order the columns the way that I like
df %>% select(
  ncessch,year,
  school_name, distinct_charter, distinct_regular_nc,
  k12_enrollment, 
  gm_formatted_address, gm_lat,gm_lon,
  street_location, city_location, zip_location,
  school_type,  charter, 
  c(names(df)[grepl(".*_enr",names(df))]),
  location_verification_method, latlon_verification_method,
  everything()
) -> df

# lets clean the environment
#rm(sg14,sg19,dups,groupagg,repcols,grades)

# Validation ----

if (df[by=year,,sum(!is.na(comb_ela_proficiency))][V1==0,nrow(.SD)] > 0) warning("\nSome years have no values for comb_ela_proficiency")
if (sg[nchar(distnum_schnum) != 7] %>% nrow() > 0) warning("\nNot all distnum_schnum are 7 characters")

