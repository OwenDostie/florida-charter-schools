
# DISCRETE RADIUS CHARTER PENETRATION ----

# Generate the following statistics for 1, 2.5, 5, and 10 mile radii centered around each location_id, for each grade.
# The statistics are: charter enrollment, tps enrollmennt, number of charter schools, number of tps
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

  # CREATE ENNROLLMENT METRICS

  for (r in c("1m","2.5m","5m","10m")) {
    for (g in c("k",paste0("g",1:12))) {
      df[[paste0("pct_charter_",r,"_",g)]] <- data.table(df[[paste0("ce_",r,"_",g)]]/(df[[paste0("tpse_",r,"_",g)]] + df[[paste0("ce_",r,"_",g)]]))[is.nan(V1) | V1==Inf, V1:=0][,V1] # coerce Inf and NaN to 0
    }
  }
  
  # gradewise enrollments as a matrix
  # compute for each grade: charter enrollment in radius, divided by tps enrollment in radius
  # multiply these by the enrollment at target school for the corresponding graade, sum all 13 grade levels, 
  # then divide by the number of students at the selected school
  for (r in c("1m","2.5m","5m","10m")) {
    df[[paste0("weighted_pct_charter_",r)]] <- ((df %>% select(grades) %>% unlist(use.names = F) %>% matrix(.,ncol=13)) * (df %>% select(paste0("pct_charter_",r,"_", c("k",paste0("g",1:12)))) %>% unlist(use.names = F) %>% matrix(.,ncol=13))) %*% matrix(rep(1,13),ncol=1) / ((df %>% select(grades) %>% unlist(use.names = F) %>% matrix(.,ncol=13)) %*% matrix(rep(1,13),ncol=1))
  }
  
  # make sure k12_enrollment is correct
  df[,k12_enrollment:=df %>% select(grades) %>% rowSums()]

# GRAVITY WEIGHTED CHARTER PENENTRATION ---- 
  dm <- fread("src/distance_matrix.csv",integer64 = "double") %>% as.matrix()
  dm2 <- round(1/(dm^2),8) %>% replace(.,is.infinite(.),0)
  grades <- paste0(c("k",paste0("grade",1:12)),"_enr")
  dm2[1:10,1:10]; dm3[1:10,1:10]
  # round 4 will do this: anything beyond 21.54 miles gets the coefficient rounded to 0;
  # round 8
  rm("t_lids")
  for (y in 1999:2018) {
    data.table(dm2 %*% (merge(data.table(location_id=1:nrow(dm)),df[year == y, lapply(.SD,function(x) sum(x,na.rm=T)), by=location_id, .SDcols = grades], by="location_id", all.x=T) %>% select(2:14) %>% replace(.,is.na(.),0) %>% as.matrix)) -> t_dm
    data.table(dm2 %*% (merge(data.table(location_id=1:nrow(dm)),df[year == y & charter == "yes", lapply(.SD,function(x) sum(x,na.rm=T)), by=location_id, .SDcols = grades], by="location_id", all.x=T) %>% select(2:14) %>% replace(.,is.na(.),0) %>% as.matrix)) -> t_dm_charter
    setnames(t_dm,names(t_dm),paste0("gravity_",names(t_dm)));     setnames(t_dm_charter,names(t_dm_charter),paste0("gravity_",names(t_dm_charter),"_charter"))
    t_dm[,`:=`(location_id = 1:nrow(.SD), year=y)]; t_dm_charter[,`:=`(location_id = 1:nrow(.SD), year=y)]
    t_dm <- merge(t_dm,t_dm_charter,on=.(location_id,year),all.x=T)
    if (!exists("t_lids")) t_lids <- t_dm else t_lids <- rbind(t_lids, t_dm)
  }
  
  setkey(df,location_id,year); setkey(t_lids,location_id,year)
  if ("gravity_grade1_enr" %!in% names(df)) df <- merge(df,t_lids,all.x=T)
  
  df$gravity_penetration <- (rowSums(((df %>% select(paste0("gravity_",grades,"_charter")) %>% as.matrix)*(df %>% select(grades) %>% as.matrix) / (df %>% select(paste0("gravity_",grades)) %>% as.matrix) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0)) / df$k12_enrollment) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0))
  
  df$gravity_penetration_surrounding <- (rowSums(((df %>% select(paste0("gravity_",grades,"_charter")) %>% as.matrix - (df$charter=="yes")*(df %>% select(grades) %>% as.matrix))*(df %>% select(grades) %>% as.matrix) / (df %>% select(paste0("gravity_",grades)) %>% as.matrix - (df %>% select(grades) %>% as.matrix))) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0)) / df$k12_enrollment) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0)
  
  
  # same operation using distance + 1
  dm3 <- round(1/((dm+1)^2),8) %>% replace(.,is.infinite(.),0)
  
  # round 4 will do this: anything beyond 21.54 miles gets the coefficient rounded to 0;
  # round 8
  rm("t_lids")
  for (y in 1999:2018) {
    data.table(dm2 %*% (merge(data.table(location_id=1:nrow(dm)),df[year == y, lapply(.SD,function(x) sum(x,na.rm=T)), by=location_id, .SDcols = grades], by="location_id", all.x=T) %>% select(2:14) %>% replace(.,is.na(.),0) %>% as.matrix)) -> t_dm
    data.table(dm2 %*% (merge(data.table(location_id=1:nrow(dm)),df[year == y & charter == "yes", lapply(.SD,function(x) sum(x,na.rm=T)), by=location_id, .SDcols = grades], by="location_id", all.x=T) %>% select(2:14) %>% replace(.,is.na(.),0) %>% as.matrix)) -> t_dm_charter
    setnames(t_dm,names(t_dm),paste0("gravity_",names(t_dm)));     setnames(t_dm_charter,names(t_dm_charter),paste0("gravity_",names(t_dm_charter),"_charter"))
    t_dm[,`:=`(location_id = 1:nrow(.SD), year=y)]; t_dm_charter[,`:=`(location_id = 1:nrow(.SD), year=y)]
    t_dm <- merge(t_dm,t_dm_charter,on=.(location_id,year),all.x=T)
    if (!exists("t_lids")) t_lids <- t_dm else t_lids <- rbind(t_lids, t_dm)
  }
  
  setkey(df,location_id,year); setkey(t_lids,location_id,year)
  if ("gravity_grade1_enr" %!in% names(df)) df <- merge(df,t_lids,all.x=T)
  
  df$gravity_penetration_1p <- (rowSums(((df %>% select(paste0("gravity_",grades,"_charter")) %>% as.matrix)*(df %>% select(grades) %>% as.matrix) / (df %>% select(paste0("gravity_",grades)) %>% as.matrix) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0)) / df$k12_enrollment) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0))
  
  df$gravity_pen_surrounding_1p <- (rowSums(((df %>% select(paste0("gravity_",grades,"_charter")) %>% as.matrix - (df$charter=="yes")*(df %>% select(grades) %>% as.matrix))*(df %>% select(grades) %>% as.matrix) / (df %>% select(paste0("gravity_",grades)) %>% as.matrix - (df %>% select(grades) %>% as.matrix))) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0)) / df$k12_enrollment) %>% replace(.,is.na(.) | is.nan(.) | is.infinite(.),0)
# EXPONENTIAL DECAY CHARTER PENETRATION (V1) ----
  # init stuff
  dm <- fread("src/distance_matrix.csv",integer64 = "double") %>% as.matrix()
  grades <- paste0(c("k",paste0("grade",1:12)),"_enr")
  
  # for (r in c(-0.01,-0.025,-0.05,-0.075,seq(from=-0.1,to=-1,by=-0.05))) {
  for (r in seq(from=-0.005,to=-0.3,by=-0.005)) {
    print(r)
    e <- exp(dm*r) #%>% replace(.,is.infinite(.),0)
    rm("t_lids")
    for (y in 1999:2018) {
      data.table(dme %*% (merge(data.table(location_id=1:nrow(dme)),df[year == y, lapply(.SD,function(x) sum(x,na.rm=T)), by=location_id, .SDcols = grades], by="location_id", all.x=T) %>% select(2:14) %>% replace(.,is.na(.),0) %>% as.matrix)) -> t_dm
      data.table(dme %*% (merge(data.table(location_id=1:nrow(dme)),df[year == y & charter=="yes", lapply(.SD,function(x) sum(x,na.rm=T)), by=location_id, .SDcols = grades], by="location_id", all.x=T) %>% select(2:14) %>% replace(.,is.na(.),0) %>% as.matrix)) -> t_dmc
      setnames(t_dm,names(t_dm),paste0("exp_decay_",names(t_dm))); setnames(t_dmc,names(t_dmc),paste0("exp_decay_",names(t_dmc),"_charter"))
      t_dm[,`:=`(location_id = 1:nrow(.SD), year=y)]; t_dmc[,`:=`(location_id = 1:nrow(.SD), year=y)]
      t_dm <- merge(t_dm,t_dmc,on=.(location_id,year),all.x=T)
      if (!exists("t_lids")) t_lids <- t_dm else t_lids <- rbind(t_lids, t_dm)
    }
    # merge with df
    t_m <- merge(df,t_lids,all.x=T,by=c("location_id","year"))
    (  rowSums(  (  as.matrix(select(t_m, paste0("exp_decay_",grades,"_charter"))) / as.matrix(select(t_m, paste0("exp_decay_",grades,"")))  )  *  as.matrix(select(t_m,grades))  ) * as.matrix(1/t_m$k12_enrollment)  ) -> df[[paste0("exp_decay_r",abs(r))]]
    setnames(t_lids, names(t_lids)[grepl("exp",names(t_lids))], paste0(names(t_lids)[grepl("exp",names(t_lids))], "_r",abs(r)) %>% gsub("charter","ch",.))
    
    #df <- merge(df,t_lids,all.x=T,by=c("location_id","year"))
  }
  
  seq(from=-0.005,to=-.3,by=-0.005) %>% abs %>% gsub("\\.","",.) %>% paste0(collapse = " ")