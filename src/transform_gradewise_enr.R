
# Read from file(s) -------------------------------------------------------


if (exists('gwe')) rm(gwe)
if (file.exists("src/gradewise_enr.csv")) { gwe <- fread("src/gradewise_enr.csv", integer64 = "double") %>% as.data.table } else {
  warning("gradewise_enr.csv didn't exist so it was created")
  # grades 1-12
  for (yf in c(1999,2004,2009,2014)) {
    t_f <- fread(paste0("src/gradewise_enrollment/gwe_",yf,"-",yf+4,".csv"), na.strings = c("","NA","†","‡","–"), integer64 = "double") %>% as.data.table
    for (y in yf:(yf+4)) {
      t_f %>%
        select(`School ID - NCES Assigned [Public School] Latest available year`, 
               paste0("Grade ",1:12," Students [Public School] ",y,"-",substr(y+1,3,4))) -> t_fy
      names(t_fy) <- c("ncessch", paste0("grade",1:12,"_enr"))
      t_fy[,year := y]
      if (exists('gwe')) { gwe <- rbind(gwe, t_fy) } else { gwe <- t_fy }
    }
  }
  # kindergarten and pre-k
  t_f <- fread(paste0("src/gradewise_enrollment/gwe_prek-k.csv"), na.strings = c("","NA","†","‡","–"), integer64 = "double") %>% as.data.table
  for (y in 1999:2018) {
    t_f %>%
      select(`School ID - NCES Assigned [Public School] Latest available year`, 
             paste0(c("Prekindergarten", "Kindergarten")," Students [Public School] ",y,"-",substr(y+1,3,4))) -> t_fy
    names(t_fy) <- c("ncessch", paste0(c("prek", "k"),"_enr"))
    t_fy[,year := y]
    if (exists('pk')) { pk <- rbind(pk, t_fy) } else { pk <- t_fy }
  }
  setkey(pk,ncessch,year); setkey(gwe,ncessch,year)
  pk[!is.na(ncessch)] -> pk; gwe[!is.na(ncessch)] -> gwe
  gwe <- gwe[pk,nomatch=NULL]
  rm(y,yf,pk,t_f,t_fy) -> t_
  if (exists('gwe')) fwrite(gwe, "src/gradewise_enr.csv")
}
if ("V1" %in% names(gwe)) { gwe[,V1:=NULL] }

# Create summary enrollments ----------------------------------------------


setnafill(gwe,fill=0)
gwe$enrollment <- rowSums(gwe[,c(paste0("grade",1:12,"_enr"),"k_enr","prek_enr")])
gwe$k12_enrollment <- rowSums(gwe[,c(paste0("grade",1:12,"_enr"),"k_enr")])

# gwe[,enr_primary := grade1_enr + grade2_enr + grade3_enr + grade4_enr + grade5_enr]
# gwe[,enr_middle := grade6_enr + grade7_enr + grade8_enr]
# gwe[,enr_high := grade9_enr + grade10_enr + grade11_enr + grade12_enr]