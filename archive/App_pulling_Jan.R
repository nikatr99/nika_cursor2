
# ---- Load Libraries ----
library(shiny)
library(shinyjs)  # For JavaScript interactivity
library(shinydashboard)
library(googlesheets4)
library(ggplot2)
library(dplyr)
library(bslib)
library(shinydashboard)
library(tidyr)
library(plotly)
library(lubridate)
library(tidyverse)


# ---- Authentication and Google Sheets Setup ----
gs4_auth()
sheet_url_jan_2024 <-"https://docs.google.com/spreadsheets/d/1vX9O7cXFf38PsES6KLmKQeeyY7ZdZ6Kiauc8XuG0kSI"


# Pull data from Google Sheets and transpose as necessary
jan_dates <- read_sheet(sheet_url_jan_2024, range = "B1:Af1", col_names = FALSE) %>% 
  t() %>% 
  as.vector() %>% 
  as.Date(format = "%Y-%m-%d")  # adjust format if needed

# Create empty rows with same structure as revenue_data
empty_jan <- as_tibble(matrix(NA, nrow = length(jan_dates), ncol = ncol(revenue_data)))
colnames(empty_jan) <- colnames(revenue_data)

# Fill the Date column
empty_jan$Date <- jan_dates

# Add them before your existing revenue_data
revenue_data <- bind_rows(empty_jan, revenue_data)






summary_data <- read_sheet(sheet_url_jan_2024, sheet = "Summary")

summary_data <- summary_data %>%
  mutate(across(everything(), ~na_if(., "NULL")))

revenue_data$DTC_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[7, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Hardware[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[8, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Addons[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[9, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Merch[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[10, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Seeds[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[11, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Taxes[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[12, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Shipping[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[13, -1], use.names = FALSE)))[1:31]

revenue_data$Amazon_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[14, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Hardware[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[15, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Addons[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[16, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Tax[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[17, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Shipping[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[18, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_GiftWrap[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[19, -1], use.names = FALSE)))[1:31]

revenue_data$Rachio_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[21, -1], use.names = FALSE)))[1:31]
revenue_data$Weatherflow_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[25, -1], use.names = FALSE)))[1:31]
revenue_data$Digital_Marketplaces_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[20, -1], use.names = FALSE)))[1:31]

revenue_data$Total_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[29, -1], use.names = FALSE)))[1:31]
revenue_data$B2B_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[38, -1], use.names = FALSE)))[1:31]
revenue_data$BestBuy_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[32, -1], use.names = FALSE)))[1:31]
revenue_data$Target_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[35, -1], use.names = FALSE)))[1:31]
revenue_data$App_Revenue[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[45, -1], use.names = FALSE)))[1:31]
revenue_data$Google_Store[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[41, -1], use.names = FALSE)))[1:31]
revenue_data$Apple_Store[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[42, -1], use.names = FALSE)))[1:31]
revenue_data$App_Comission[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[43, -1], use.names = FALSE)))[1:31]
revenue_data$App_Tax[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[44, -1], use.names = FALSE)))[1:31]

revenue_data$DTC_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[48, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Hardware_Units[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[49, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Addons_Units[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[50, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Merch_Units[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[51, -1], use.names = FALSE)))[1:31]
revenue_data$DTC_Seeds_Units[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[52, -1], use.names = FALSE)))[1:31]

revenue_data$Amazon_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[53, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Hardware_Units[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[54, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Addons_Units[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[55, -1], use.names = FALSE)))[1:31]

revenue_data$Digital_Marketplaces_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[56, -1], use.names = FALSE)))[1:31]
revenue_data$Rachio_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[57, -1], use.names = FALSE)))[1:31]
revenue_data$Weatherflow_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[58, -1], use.names = FALSE)))[1:31]
revenue_data$Total_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[59, -1], use.names = FALSE)))[1:31]

revenue_data$B2B_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[64, -1], use.names = FALSE)))[1:31]
revenue_data$BestBuy_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[62, -1], use.names = FALSE)))[1:31]
revenue_data$Target_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[63, -1], use.names = FALSE)))[1:31]
revenue_data$App_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[69, -1], use.names = FALSE)))[1:31]
revenue_data$Google_Store_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[67, -1], use.names = FALSE)))[1:31]
revenue_data$Apple_Store_Orders[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[68, -1], use.names = FALSE)))[1:31]

revenue_data$Meta_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[72, -1], use.names = FALSE)))[1:31]
revenue_data$Google_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[73, -1], use.names = FALSE)))[1:31]
revenue_data$Bing_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[74, -1], use.names = FALSE)))[1:31]
revenue_data$TikTok_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[75, -1], use.names = FALSE)))[1:31]
revenue_data$Amazon_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[76, -1], use.names = FALSE)))[1:31]
revenue_data$Nextdoor_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[77, -1], use.names = FALSE)))[1:31]
revenue_data$IndieGoGo_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[78, -1], use.names = FALSE)))[1:31]
revenue_data$Affiliate_Fees[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[79, -1], use.names = FALSE)))[1:31]

revenue_data$Rachio_Fees[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[80, -1], use.names = FALSE)))[1:31]
revenue_data$Weatherflow_Fees[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[81, -1], use.names = FALSE)))[1:31]
revenue_data$Fees[1:31] <- revenue_data$Rachio_Fees[1:31] + revenue_data$Weatherflow_Fees[1:31]

revenue_data$Total_DTC_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[82, -1], use.names = FALSE)))[1:31]
revenue_data$Total_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[83, -1], use.names = FALSE)))[1:31]
revenue_data$App_Spend_Meta[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[86, -1], use.names = FALSE)))[1:31]
revenue_data$App_Spend_Apple[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[87, -1], use.names = FALSE)))[1:31]
revenue_data$App_Spend_Google[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[88, -1], use.names = FALSE)))[1:31]
revenue_data$Total_App_Spend[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[89, -1], use.names = FALSE)))[1:31]

revenue_data$Blended_ROAS[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[91, -1], use.names = FALSE)))[1:31]
revenue_data$wROAS[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[92, -1], use.names = FALSE)))[1:31]
revenue_data$aROAS[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[93, -1], use.names = FALSE)))[1:31]
revenue_data$appROAS[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[94, -1], use.names = FALSE)))[1:31]
revenue_data$Blended_SPU[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[96, -1], use.names = FALSE)))[1:31]
revenue_data$wSPU[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[97, -1], use.names = FALSE)))[1:31]
revenue_data$aSPU[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[98, -1], use.names = FALSE)))[1:31]
revenue_data$appSPU[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[99, -1], use.names = FALSE)))[1:31]
revenue_data$Web_CR[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[101, -1], use.names = FALSE)))[1:31]
revenue_data$Web_AOV[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[102, -1], use.names = FALSE)))[1:31]
revenue_data$fAOV[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[103, -1], use.names = FALSE)))[1:31]
revenue_data$rAOV[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[104, -1], use.names = FALSE)))[1:31]
revenue_data$Returning_Customers[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[107, -1], use.names = FALSE)))[1:31]
revenue_data$First_Time_Customers[1:31] <- as.numeric(gsub(",", "", unlist(summary_data[108, -1], use.names = FALSE)))[1:31]





dtc_data <- read_sheet(sheet_url_jan_2024, sheet = "DTC - P&L")
library(dplyr)

dtc_data <- dtc_data %>%
  mutate(across(everything(),
                ~ gsub("NULL|^$", "0", .))) %>%       # turn NULL/empty into "0"
  mutate(across(-1, ~ as.numeric(gsub(",", "", .))))  # remove commas + numeric

revenue_data$`dtc_SKU 1 - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[53, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_SKU 2 - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[54, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_SKU 3 - Blue w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[55, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_SKU 4 - Yellow w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[56, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Wall Mount`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[59, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Suet Ball Holder`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[60, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_3-in-1 Nutrition Set - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[61, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_3-in-1 Nutrition Set - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[62, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Solar Roof Single - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[63, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Solar Roof Single - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[64, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Perch Extender - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[65, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Perch Extender - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[66, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Seasonal Curation - 8lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[69, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Seasonal Curation - 20lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[70, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Buddy Bites - 8lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[71, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Buddy Bites - 20lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[72, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Snack n' Soar - 8lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[73, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Snack n' Soar - 20lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[74, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Avian Choice - 8lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[75, -1], use.names = FALSE)))[1:31]
revenue_data$`dtc_Avian Choice - 20lb`[1:31] <- as.numeric(gsub(",", "", unlist(dtc_data[76, -1], use.names = FALSE)))[1:31]




# ---- amazon data ----
amazon_data <- read_sheet(sheet_url_jan_2024, sheet = "AMAZON - P&L")

revenue_data$`amazon_SKU 1 - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[27, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_SKU 2 - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[28, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_SKU 3 - Blue w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[29, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_SKU 4 - Yellow w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[30, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_Wall Mount`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[33, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_Suet Ball Holder`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[34, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_3-in-1 Nutrition Set - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[35, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_3-in-1 Nutrition Set - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[36, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_Solar Roof Single - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[37, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_Solar Roof Single - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[38, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_Perch Extender - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[39, -1], use.names = FALSE)))[1:31]
revenue_data$`amazon_Perch Extender - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(amazon_data[40, -1], use.names = FALSE)))[1:31]








# ---- rachio data ----
rachio_data <- read_sheet(sheet_url_jan_2024, sheet = "Digital Marketplaces - P & L")

revenue_data$`rachio_SKU 1 - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[12, -1], use.names = FALSE)))[1:31]
revenue_data$`rachio_SKU 2 - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[13, -1], use.names = FALSE)))[1:31]
revenue_data$`rachio_SKU 3 - Blue w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[14, -1], use.names = FALSE)))[1:31]
revenue_data$`rachio_SKU 4 - Yellow w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[15, -1], use.names = FALSE)))[1:31]
revenue_data$`weatherflow_SKU 1 - Blue`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[124, -1], use.names = FALSE)))[1:31]
revenue_data$`weatherflow_SKU 2 - Yellow`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[125, -1], use.names = FALSE)))[1:31]
revenue_data$`weatherflow_SKU 3 - Blue w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[126, -1], use.names = FALSE)))[1:31]
revenue_data$`weatherflow_SKU 4 - Yellow w/ Solar`[1:31] <- as.numeric(gsub(",", "", unlist(rachio_data[127, -1], use.names = FALSE)))[1:31]


app_data <- read_sheet(sheet_url_jan_2024, sheet = "App - P&L")

revenue_data$`apple_yearly_sub`[1:31] <- as.numeric(gsub(",", "", unlist(app_data[14, -1], use.names = FALSE)))[1:31]
revenue_data$`apple_monthly_sub`[1:31] <- as.numeric(gsub(",", "", unlist(app_data[15, -1], use.names = FALSE)))[1:31]
revenue_data$`google_yearly_sub`[1:31] <- as.numeric(gsub(",", "", unlist(app_data[17, -1], use.names = FALSE)))[1:31]
revenue_data$`google_monthly_sub`[1:31] <- as.numeric(gsub(",", "", unlist(app_data[18, -1], use.names = FALSE)))[1:31]

saveRDS(revenue_data, file = "revenue_data.rds")





campaign_notes_df <- data.frame(
  note = c(
    "Increased SKU4 stock by 50",
    "13:20 - SKU1 Amazon button, SKU2 updated to 194 stock, SKU3 back in stock with 393, SKU4 updated to 200 stock. On shop page, we show SKU3 instead of SKU4.",
    "Seeds Launch",
    "11:00 - SKU4 out of stock / Pro Bundle, yellow out of stock",
    "13:27 - 20% off promo ending / Reduced pricing for add-ons",
    "First order with new A/B test prices: #131667 (12:31)",
    "Pricing A/B Test",
    "All yellow units option out of stock (15:37)",
    
    "Valentines Day Sale: 33% off 2nd feeder",
    "Flash Sale: 30% off (MAP Price Model)",
    "A/B Testing - Seeds #1 (First bag free & $26.90 Price)",
    "HBF Pre-Launch (PRO)",
    "Women's Day Offer: 30% off (MAP Price Model)",
    "HBF Main Launch"
  ),
  start = as.Date(c("2024-01-07",
                    "2024-01-08",
                    "2024-01-15",
                    "2024-01-19",
                    "2024-01-19",
                    "2024-01-24",
                    "2024-01-24",
                    "2024-01-31",
                    
                    "2024-02-05", 
                    "2024-02-15",
                    "2024-02-22",
                    "2024-02-28", 
                    "2024-02-29", 
                    "2024-02-29")),
  end = as.Date(c("2024-01-07",
                  "2024-01-08",
                  "2024-01-15",
                  "2024-01-19",
                  "2024-01-19",
                  "2024-01-24",
                  "2024-01-31",
                  "2024-01-31",
                  
                  "2024-02-14", 
                  "2024-02-27",
                  "2024-02-29",
                  "2024-02-28", 
                  "2024-02-29", 
                  "2024-02-29")),
  stringsAsFactors = FALSE
)

# 1. Read the Post-purchase survey sheet
pps_data <- read_sheet(sheet_url_jan_2024, sheet = "PP - Data")

# Create empty rows with same structure as revenue_data
empty_jan <- as_tibble(matrix(NA, nrow = length(jan_dates), ncol = ncol(survey_data)))
colnames(empty_jan) <- colnames(survey_data)

# Fill the Date column
empty_jan$Date <- jan_dates

# Add them before your existing revenue_data
survey_data <- bind_rows(empty_jan, survey_data)

survey_data[1:31, 2]<- as.numeric(gsub(",", "", unlist(pps_data[1, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 3]<- as.numeric(gsub(",", "", unlist(pps_data[2, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 4]<- as.numeric(gsub(",", "", unlist(pps_data[3, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 5]<- as.numeric(gsub(",", "", unlist(pps_data[4, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 6]<- as.numeric(gsub(",", "", unlist(pps_data[5, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 7]<- as.numeric(gsub(",", "", unlist(pps_data[6, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 8]<- as.numeric(gsub(",", "", unlist(pps_data[7, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 9]<- as.numeric(gsub(",", "", unlist(pps_data[8, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 10]<- as.numeric(gsub(",", "", unlist(pps_data[22, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 11]<- as.numeric(gsub(",", "", unlist(pps_data[23, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 12]<- as.numeric(gsub(",", "", unlist(pps_data[24, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 13]<- as.numeric(gsub(",", "", unlist(pps_data[35, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 14]<- as.numeric(gsub(",", "", unlist(pps_data[41, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 15]<- as.numeric(gsub(",", "", unlist(pps_data[47, -1], use.names = FALSE)))[1:31]
survey_data[1:31, 16]<- as.numeric(gsub(",", "", unlist(pps_data[53, -1], use.names = FALSE)))[1:31]






saveRDS(campaign_notes_df, file = "campaign_notes_df.rds")
saveRDS(revenue_data, file = "revenue_data.rds")
saveRDS(survey_data, file = "survey_data.rds")

