# To read in all previous files and output to new CUAHSI format
library(readr)
library(lubridate)

im <- list.files("/Users/davidkahler/Documents/Hydrology_and_WRM/Limpopo_Basin_Study/LimpopoData/Mutale/", 
                 pattern = "*.csv", 
                 full.names = TRUE, 
                 recursive = TRUE, 
                 ignore.case=TRUE, 
                 include.dirs = TRUE)
site <- "mutale" # mutale OR medike, or other site
offsetHRS <- 2 # UTC offset for SAST is 2 hours
offset <- offsetHRS*3600

for (j in 1:length(im)) {
      fl <- read_csv(im[j])
      cuahsi <- fl %>%
            mutate(dt=ymd_hms(paste0(YEAR,"-",MNTH,"-",DAYN,"T",HOUR,":",MINU,":00"))-offset) %>% # Time in UTC
            mutate(LocalDateTime=as.character(as_datetime(dt, tz = "Africa/Johannesburg"))) %>%
            mutate(UTCOffset=offsetHRS) %>%
            mutate(DateTimeUTC=as.character(as_datetime(dt))) %>%
            pivot_longer(c(PRCP,SRAD,TEMP,RHMD,APRS,WSPD,WDIR), names_to = "VariableCode", values_to = "DataValue") # Remember, old files didn't retain vapor pressure!!!
      SiteCode = array(site, dim=nrow(cuahsi))
      MethodCode = array("", dim=nrow(cuahsi))
      SourceCode = array("LimpopoResilienceLab", dim=nrow(cuahsi))
      QualityControlLevelCode = array("", dim=nrow(cuahsi))
      for (i in 1:nrow(cuahsi)) {
            if ( (cuahsi$VariableCode[i] == "PRCP") | (cuahsi$VariableCode[i] == "SRAD") | (cuahsi$VariableCode[i] == "TEMP") | (cuahsi$VariableCode[i] == "VPRS") | (cuahsi$VariableCode[i] == "APRS") | (cuahsi$VariableCode[i] == "WSPD") | (cuahsi$VariableCode[i] == "WDIR") ) {
                  MethodCode[i] <- "Atmos41"
                  QualityControlLevelCode[i] <- 0
            } else if (cuahsi$VariableCode[i] == "RHMD") {
                  MethodCode[i] <- "Atmos41"
                  QualityControlLevelCode[i] <- 2
            } else if (cuahsi$VariableCode[i] == "RIVS") {
                  MethodCode[i] <- "Hydros21"
                  QualityControlLevelCode[i] <- 2
            }else if ( (cuahsi$VariableCode[i] == "COND") | (cuahsi$VariableCode[i] == "WTMP") ) {
                  MethodCode[i] <- "Hydros21"
                  QualityControlLevelCode[i] <- 0
            }
      }
      cuahsi <- data.frame(cuahsi$DataValue,cuahsi$LocalDateTime,cuahsi$UTCOffset,cuahsi$DateTimeUTC,SiteCode,cuahsi$VariableCode,MethodCode,SourceCode,QualityControlLevelCode)
      cuahsi <- cuahsi %>%
            rename(
                  DataValue=cuahsi.DataValue,
                  LocalDateTime=cuahsi.LocalDateTime,
                  UTCOffset=cuahsi.UTCOffset,
                  DateTimeUTC=cuahsi.DateTimeUTC,
                  VariableCode=cuahsi.VariableCode
            )
      if (j == 1) {
            upload <- cuahsi
      } else {
            upload <- rbind(upload,cuahsi)
      }
}

h <- names(upload)
s <- length(h)
hl <- array("a", dim = c(1,s))
for (i in 1:length(h)) {
      hl[1,i] <- h[i]
}
hl <- data.frame(hl)
write_csv(hl, paste0(site, "_", "fromUSAID", ".cuahsi.csv"), append = TRUE, eol = "\n") # writes headers
write_csv(upload, paste0(site, "_", "fromUSAID", ".cuahsi.csv"), na = "NA", append = TRUE, eol = "\n") # writes data, UNIX standard end of line, comma-delimited, decimal point used "."
