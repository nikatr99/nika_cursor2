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
library(magick)
library(lubridate)
library(forcats)

# ---- Authentication and Google Sheets Setup ----
# Include this so rsconnect picks it up


revenue_data <- readRDS("revenue_data.rds")
campaign_notes_df <- readRDS("campaign_notes_df.rds")
survey_data <- readRDS("survey_data.rds")


# 1. Define the additive measures
additive_cols <- c(
  "DTC_Revenue", "DTC_Hardware", "DTC_Addons", "DTC_Merch", "DTC_Seeds","DTC_Subscription",
  "DTC_Taxes", "DTC_Shipping", "Amazon_Revenue", "Amazon_Hardware", 
  "Amazon_Addons", "Amazon_Tax", "Amazon_Shipping", "Amazon_GiftWrap",
  "Rachio_Revenue", "Weatherflow_Revenue", "Digital_Marketplaces_Revenue",
  "Total_Revenue", "B2B_Revenue", "BestBuy_Revenue", "Target_Revenue","Walmart_Revenue",
  "App_Revenue", "Google_Store", "Apple_Store",
  "DTC_Orders", "DTC_Hardware_Units", "DTC_Addons_Units","DTC_Subscription_Units",
  "Amazon_Orders", "Amazon_Hardware_Units", "Amazon_Addons_Units",
  "Total_Orders", "B2B_Orders", "BestBuy_Orders", "Target_Orders","Walmart_Orders",
  "App_Orders", "Google_Store_Orders", "Apple_Store_Orders",
  "Meta_Spend", "Google_Spend", "Bing_Spend", "TikTok_Spend", 
  "Amazon_Spend", "Nextdoor_Spend", "IndieGoGo_Spend",
  "Affiliate_Fees", "Rachio_Fees", "Weatherflow_Fees",
  "Total_DTC_Spend", "Total_Spend", "App_Spend_Meta",
  "App_Spend_Apple", "App_Spend_Google", "Total_App_Spend"
)

# 2. Apply NA→0 only to those
revenue_data <- revenue_data %>%
  mutate(across(all_of(additive_cols), ~ replace_na(.x, 0)))




# ---- UI Definition ----
# UI Definition

ui <- dashboardPage(
  dashboardHeader(disable = TRUE),
  dashboardSidebar(
    width = 250, # Sidebar width
    tags$style(HTML("
      .skin-blue .main-sidebar {
        background-color: #f5f5f5 !important; /* Light gray background for sidebar */
        border-right: 1px solid #ddd;
      }
      .skin-blue .sidebar-menu > li > a {
        color: #333 !important; /* Black text for menu items */
        font-family: 'Montserrat', sans-serif;
        font-weight: bold;
        font-size: 14px;
      }
      .skin-blue .sidebar-menu > li.active > a {
        background-color: #e0e0e0 !important; /* Highlight for active menu item */
        color: #333 !important;
      }
      .skin-blue .sidebar-menu > li > a:hover {
        background-color: #e0e0e0 !important;
        color: #333 !important;
      }
    ")),
    sidebarMenu(
      id = "tabs",
      menuItem("Summary", tabName = "summary", icon = icon("chart-line")),
      menuItem("Visualization", tabName = "visualization", icon = icon("chart-bar")),
      menuItem("P&L", tabName = "pnl", icon = icon("dollar-sign")),
      menuItem("P&L Visualizations", tabName = "pnl_viz", icon = icon("chart-pie")),
      menuItem("Post Purchase Survey", tabName = "survey", icon = icon("clipboard-check"))
      
    ),
    
    tags$style(HTML("
      .sidebar {
        background-color: #ffffff !important; /* White background for sidebar */
      }
      .sidebar .sidebar-menu a {
        color: black !important; /* Black text for menu items */
        font-family: 'Montserrat', sans-serif;
        font-weight: bold;
      }
    "))
  ),
  dashboardBody(
    useShinyjs(),  # For interactive stuff
    tags$head(
      tags$link(
        href = "https://fonts.googleapis.com/css2?family=Montserrat:wght@400;700&display=swap", 
        rel = "stylesheet"
      )
    ),
    
    div(
      style = "display: flex; justify-content: flex-end; padding: 15px;",
      
      div(
        style = "display: flex; flex-direction: column; align-items: flex-end; gap: 8px;",
        
        dateRangeInput(
          inputId = "selected_date_range",
          label = "Select Date Range:",
          start = min(revenue_data$Date, na.rm = TRUE),
          end   = max(revenue_data$Date, na.rm = TRUE),
          min   = min(revenue_data$Date, na.rm = TRUE),
          max   = max(revenue_data$Date, na.rm = TRUE),
          format = "yyyy-mm-dd",
          weekstart = 1
        ),
        
        div(
          style = "text-align: right; width: 100%;",
          checkboxInput(
            inputId = "viz_by_month",
            label   = "By month",
            value   = FALSE
          )
        )
      )
    ),
    
    
    
    # Wrap the tabs
    tabItems(
      
      # ---- Summary Tab ----
      tabItem(tabName = "summary",
              
              tags$style(HTML("
          body {
            font-family: 'Montserrat', sans-serif;
          }
          .date-select-container label {
            font-family: 'Montserrat', sans-serif;
            font-weight: bold;
            font-size: 18px;
            color: #333;
          }
        
          .form-control {
            font-family: 'Montserrat', sans-serif;
            font-size: 16px;
            padding: 10px 12px;
            border-radius: 10px;
            border: 1px solid #ccc;
          }
        
          .form-control:focus {
            border-color: #2ecc71;
            box-shadow: 0 0 5px rgba(46, 204, 113, 0.5);
          }
          .total-revenue-container {
            background-color: #2ecc71;
            padding: 20px;
            border-radius: 15px;
            text-align: center;
            color: white;
            margin-bottom: 40px;
          }
          .total-spend-container {
            background-color: #A52A2A;
            padding: 20px;
            border-radius: 15px;
            text-align: center;
            color: white;
            margin-top: 40px;
            margin-bottom: 40px;
          }
          .revenue-label {
            font-size: 18px;
            font-weight: bold;
            display: inline;
          }
          .percentage-change {
            font-size: 12px;
            color: #ffffff;
            font-weight: normal;
            margin-left: 10px;
          }
          .positive-change {
            color: #2ecc71;
          }
          .negative-change {
            color: #e74c3c;
          }
          .revenue-value-white {
            font-size: 40px;
            font-weight: bold;
            color: white;
          }
          .revenue-value-brown {
            font-size: 40px;
            font-weight: bold;
            color: white;
          }
          .revenue-item-container {
            display: flex;
            justify-content: space-between;
            margin-bottom: 40px;
          }
          .revenue-item {
            text-align: center;
            flex: 1;
          }
          .revenue-sub-label {
            font-size: 14px;
            font-weight: bold;
            color: #333333;
          }
          .revenue-value-green {
            font-size: 24px;
            color: #2ecc71;
            font-weight: 400;
          }
          .revenue-value-red {
            font-size: 24px;
            color: #A52A2A;
            font-weight: 400;
          }
          .small-revenue-value {
            font-size: 30px;
            color: black;
            font-weight: normal;
          }
          .green-title {
            color: #2ecc71;
            font-size: 18px;
            font-weight: bold;
          }
          .red-title {
            color: #A52A2A;
            font-size: 18px;
            font-weight: bold;
          }
          .revenue-label-with-tooltip {
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
          }
          
          .tooltip-container {
            position: relative;
            display: inline-block;
          }
          
          .info-circle {
            width: 20px;
            height: 20px;
            background-color: white;
            color: #2ecc71;
            font-weight: bold;
            font-family: 'Montserrat', sans-serif;
            font-size: 14px;
            text-align: center;
            line-height: 20px;
            border-radius: 50%;
            cursor: pointer;
            box-shadow: 0 0 5px rgba(0,0,0,0.15);
          }
          
          .tooltip-text {
            visibility: hidden;
            background-color: white;
            color: #333;
            font-family: 'Montserrat', sans-serif;
            font-size: 13px;
            font-weight: normal;
            text-align: center;
            border-radius: 10px;
            padding: 10px;
            position: absolute;
            z-index: 100;
            bottom: 125%; /* Show above the icon */
            left: 50%;
            transform: translateX(-50%);
            width: 260px;
            box-shadow: 0 2px 10px rgba(0, 0, 0, 0.2);
            opacity: 0;
            transition: opacity 0.3s ease;
          }
          
          .tooltip-container:hover .tooltip-text {
            visibility: visible;
            opacity: 1;
          }
          .info-circle-red {
            color: #A52A2A; /* white icon color inside */
            background-color: #ffffff; /* white background to match revenue icon */
            box-shadow: 0 0 5px rgba(0,0,0,0.15); /* same as green one */
          }




        ")),
              uiOutput("campaign_notes_ui"),  # dynamically includes button + notes only if needed
              
              
              div(class = "total-revenue-container",
                  div(
                    class = "revenue-label-with-tooltip",
                    HTML('
                      <span class="revenue-label">Total Revenue</span>
                      <div class="tooltip-container">
                        <div class="info-circle">i</div>
                        <div class="tooltip-text">Includes DTC Revenue, Amazon Revenue and Digital Marketplaces Revenue</div>
                      </div>
                    '),
                    span(textOutput("total_percentage_change"), class = "percentage-change")
                  ),
                  
                  div(textOutput("total_revenue_output"), class = "revenue-value-white")
              ),
              div(class = "revenue-item-container",
                  div(
                    div("DTC Revenue", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("dtc_revenue_output"),
                      class = "revenue-value-green",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_dtc_revenue', Math.random())"),
                    class = "revenue-item",
                    uiOutput("dtc_revenue_details") # Placeholder for dynamic content
                  ),
                  div(
                    div("Amazon Revenue", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("amazon_revenue_output"),
                      class = "revenue-value-green",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_amazon_revenue', Math.random())"),
                    class = "revenue-item",
                    uiOutput("amazon_revenue_details") # Placeholder for dynamic content
                  ),
                  div(
                    div("Digital Marketplaces", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("digital_marketplaces_output"),
                      class = "revenue-value-green",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_digital_marketplaces', Math.random())"),
                    class = "revenue-item",
                    uiOutput("digital_marketplaces_details")
                  )
              ),
              div(class = "revenue-item-container",
                  div(
                    div("Retail Revenue", class = "green-title"),
                    div(tags$span(
                      textOutput("b2b_revenue_output"),
                      class = "small-revenue-value",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_b2b_revenue', Math.random())")
                  ),
                  div(
                    div("App Revenue", class = "green-title"),
                    div(tags$span(
                      textOutput("app_revenue_output"),
                      class = "small-revenue-value",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_app_revenue', Math.random())")
                  )
              ),
              # Place expandable boxes below this flex row
              div(
                style = "display: flex; justify-content: space-between;",
                uiOutput("b2b_revenue_details"),
                uiOutput("app_revenue_details")
              ),
              div(class = "total-spend-container",
                  div(
                    class = "revenue-label-with-tooltip",
                    HTML('
                        <span class="revenue-label">Total Spend</span>
                        <div class="tooltip-container">
                          <div class="info-circle info-circle-red">i</div>
                          <div class="tooltip-text">Includes DTC Spend, Amazon Spend, IndieGoGo Spend and Fees</div>
                        </div>
                      '),
                    span(textOutput("total_spend_percentage_change"), class = "percentage-change")
                  ),
                  
                  div(textOutput("total_spend_output"), class = "revenue-value-brown")
              ),
              div(class = "revenue-item-container",
                  div(
                    div("DTC Spend", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("dtc_spend_output"),
                      class = "revenue-value-red",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_dtc_spend', Math.random())"),
                    class = "revenue-item",
                    uiOutput("dtc_spend_details")
                  ),
                  div(
                    div("Amazon Spend", class = "revenue-sub-label"),
                    div(textOutput("amazon_spend_output"), class = "revenue-value-red"),
                    class = "revenue-item"
                  ),
                  div(
                    div("IndieGoGo Spend", class = "revenue-sub-label"),
                    div(textOutput("indiegogo_spend_output"), class = "revenue-value-red"),
                    class = "revenue-item"
                  ),
                  div(
                    div("Fees", class = "revenue-sub-label"),
                    div(tags$span(
                      textOutput("fees_output"),
                      class = "revenue-value-red",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_fees', Math.random())"),
                    class = "revenue-item",
                    uiOutput("fees_details")
                  )
              ),
              div(class = "revenue-item-container",
                  div(
                    div("Total App Spend", class = "red-title"),
                    div(tags$span(
                      textOutput("total_app_spend_output"),
                      class = "small-revenue-value",
                      style = "cursor: pointer;"
                    ), onclick = "Shiny.onInputChange('toggle_app_spend', Math.random())"),
                    class = "revenue-item",
                    uiOutput("app_spend_details") # Placeholder for dynamic content
                  )
              ),
              # ---- UI: Adding Expandable Container for Blended ROAS ----
              # Dark grey container with 4 metrics
              div(class = "custom-container",
                  style = "background-color: #7b868c; padding: 20px; border-radius: 15px; text-align: center; color: white; margin-top: 40px;",
                  div(
                    style = "display: flex; justify-content: space-between; align-items: center;",
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      div(
                        style = "cursor: pointer;",
                        strong("Blended ROAS:"),
                        div(
                          span(
                            textOutput("blended_roas_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_blended_roas', Math.random())"
                          )
                        )
                      ),
                      uiOutput("blended_roas_details")  # <-- stays inside this column
                    ),
                    
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      div(
                        style = "cursor: pointer;",
                        strong("Blended Spend per Unit:"),
                        div(
                          span(
                            textOutput("blended_SPU_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_blended_SPU', Math.random())"
                          )
                        )
                      ),
                      uiOutput("blended_SPU_details")  # ← The new expandable content
                    ),
                    
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      strong("Web CR:"),
                      span(textOutput("web_cr_output"), style = "font-size: 24px; font-weight: bold;")
                    ),
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      div(
                        style = "cursor: pointer;",
                        strong("Web AOV:"),
                        div(
                          span(
                            textOutput("web_aov_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_web_aov', Math.random())"
                          )
                        )
                      ),
                      uiOutput("web_aov_details")  # ← new container rendered inside column
                    ),
                    div(
                      style = "flex: 1; text-align: center; margin: 0 10px;",
                      strong("Returning Customers:"),
                      div(textOutput("returning_customer_output"), style = "font-size: 24px; font-weight: bold;")
                    )
                    
                    
                  )
              ),
              # ---- UI: Orders Summary Section ----
              # ---- UI: Orders Summary Section ----
              div(
                style = "margin-top: 30px; padding: 20px; background-color: #f0f0f0; border-radius: 15px;",
                fluidRow(
                  style = "margin-bottom: 40px;",  # Add spacing after the first row
                  column(4, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("dtc_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_dtc_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "DTC Orders"),
                    uiOutput("dtc_orders_details")  # 👈 this line shows the grey breakdown
                  )),
                  
                  column(4, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("amazon_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_amazon_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "Amazon Orders"),
                    uiOutput("amazon_orders_details")  # 👈 attaches the grey box
                  )),
                  
                  column(4, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("digital_marketplaces_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_digital_marketplaces_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "Digital Marketplaces Orders"),
                    uiOutput("digital_marketplaces_orders_details")  # 👈 attaches the expandable box
                  ))
                  
                ),
                fluidRow(
                  column(6, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("b2b_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_b2b_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "Retail Orders"),
                    uiOutput("b2b_orders_details")
                  )),
                  
                  column(6, div(
                    style = "text-align: center;",
                    div(
                      style = "font-size: 42px; font-weight: normal; cursor: pointer;",
                      span(
                        textOutput("app_orders_output"),
                        onclick = "Shiny.onInputChange('toggle_app_orders', Math.random())"
                      )
                    ),
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "App Orders"),
                    uiOutput("app_orders_details")
                  ))
                  
                )
              )
              
              
              
              
              
      ),
      # Blank Page
      tabItem(
        tabName = "visualization",
        # In tabItem(tabName = "visualization")
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
    <span style='color:#2ecc71;'>Revenue</span> vs 
    <span style='color:#A52A2A;'>Spend</span> Over Time
  </h2>"),
            
            # Dropdown on the right
            div(style = "display: flex; gap: 12px;",
                selectInput(
                  inputId = "selected_view_mode",
                  label = NULL,
                  choices = c("Absolute", "Relative"),
                  selected = "Absolute",
                  width = "150px"
                ),
                selectInput(
                  inputId = "selected_revenue_spend_type",
                  label = NULL,
                  choices = c("Total" = "Total", "DTC" = "DTC", "Amazon" = "Amazon", "App" = "App", "Retail" = "Retail"),
                  selected = "Total",
                  width = "200px"
                )
            )
            
          ),
          
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("revenue_vs_spend_plot", height = "500px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # ---- Title and Dropdown in Same Row ----
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#2ecc71;'>ROAS</span> per Day
    </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_roas_type",
              label = NULL,
              choices = c("Blended ROAS" = "Blended_ROAS",
                          "DTC ROAS (wROAS)" = "wROAS",
                          "Amazon ROAS (aROAS)" = "aROAS",
                          "App ROAS (appROAS)" = "appROAS"),
              selected = "Blended_ROAS",
              width = "250px"
            )
          ),
          
          # ---- Chart Container ----
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("blended_roas_bar_chart", height = "500px")
          )
        ),
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # ---- Title and Dropdown in Same Row ----
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#A52A2A;'>Spend per Unit</span> per Day
    </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_SPU_type",
              label = NULL,
              choices = c("Blended Spend per Unit" = "Blended_SPU",
                          "DTC Spend per Unit" = "wSPU",
                          "Amazon Spend per Unit" = "aSPU",
                          "App Spend per Unit" = "appSPU"),
              selected = "Blended_SPU",
              width = "250px"
            )
          ),
          
          # ---- Chart Container ----
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("blended_SPU_bar_chart", height = "500px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # Title
          HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin-bottom: 20px;'>
    <span style='color:#7b868c;'>Conversion Rate</span> per Day
  </h2>"),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("cr_bar_chart", height = "500px")
          )
        ),
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # --- Title + Dropdown ---
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#3498db;'>AOV</span> per Day
    </h2>"),
            selectInput(
              inputId = "selected_aov_type",
              label = NULL,
              choices = c("Web AOV" = "Web_AOV", "Customer Segments AOV" = "Segmented_AOV"),
              
              selected = "Web_AOV",
              width = "300px"
            )
          ),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("aov_bar_chart", height = "500px")
          )
        ),
        
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # Title
          HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin-bottom: 20px;'>
    <span style='color:#2ecc71;'>Returning</span> vs 
    <span style='color:#3498db;'>First-Time</span> Customers (%)
  </h2>"),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("customer_split_chart", height = "500px")
          )
        ),
        
        

        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
    Revenue Composition Over Time
  </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_revenue_view_mode",
              label = NULL,
              choices = c("Relative", "Absolute"),  # Default is relative
              selected = "Relative",
              width = "200px"
            )
          ),
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("revenue_share_chart", height = "500px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          
          # --- Title + Dropdown in Flex Row ---
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            
            # Title on the left
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      Spend Composition Over Time
    </h2>"),
            
            # Dropdown on the right
            div(
              style = "display: flex; gap: 12px;",
              selectInput(
                inputId = "selected_spend_view_mode",
                label = NULL,
                choices = c("Relative", "Absolute"),
                selected = "Relative",
                width = "200px"
              ),
              selectInput(
                inputId = "selected_spend_composition",
                label = NULL,
                choices = c("Total Spend" = "Total", "DTC Spend" = "DTC"),
                selected = "Total",
                width = "250px"
              )
            )
            
          ),
          
          # Chart container
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("spend_composition_chart", height = "500px")
          )
        )
        
        
        
        
        
        
      ),
      
      tabItem(tabName = "pnl",
              # ---- Units Sold (Gross) Section ----
              div(
                style = "background-color: rgba(255, 255, 255, 0.2); border-radius: 20px; padding: 30px; margin-top: 20px;",
                
                # Header row
                div(
                  style = "display: flex; align-items: center; padding: 15px;",
                  div("Units Sold (Gross)",
                      style = "font-family: 'Montserrat'; font-size: 24px; font-weight: bold; flex: 1;"
                  ),
                  div(
                    style = "display: flex; width: 770px; justify-content: space-between;",
                    div("DTC",    style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Amazon", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Rachio", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Weatherflow", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Walmart", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div(HTML("ALL<br/>CHANNELS"),
                        style = "font-size: 10px; font-weight: 500; color: #555; text-align: center; width: 150px;")
                  )
                ),
                
                # SKU rows container
                div(style = "display: flex; flex-direction: column; gap: 20px;",
                    
                    # Blue SKU block
                    div(
                      style = "display: flex; align-items: center; background:#fff; border-radius:15px;
           padding:15px; box-shadow:0 0 10px rgba(0,0,0,0.05);",
                      
                      # 2a) Image + title = flex:1
                      uiOutput("blue_sku_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #2980b9;">Blue</span> Smart Bird Feeder')
                          ),
                          
                          div(style = "font-size: 10px; color: #888888;", "BBG1002BAB BBG1002BAC")
                        ),
                        # 2b) DTC & Amazon counts container
                        div(
                          style = "display: flex; width: 770px; justify-content: space-between;",
                          
                          # DTC count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_sku_count")
                          ),
                          
                          # Amazon count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_sku_amazon_count")
                          ),
                          # Rachio count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_sku_rachio_count")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_sku_weatherflow_count")
                          ),
                          # Walmart count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_sku_walmart_count")
                          ),
                          # all
                          div(
                            style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                            textOutput("blue_sku_all_channels")
                          )
                        )
                        
                      )
                    )
                    ,
                    
                    # Yellow SKU block
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("yellow_sku_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #f1c40f;">Yellow</span> Smart Bird Feeder')
                          ),
                          
                          div(style = "font-size: 10px; color: #888888;", "BYG1002BAB BYG1002BAC")
                        ),
                        # 2b) DTC & Amazon counts container
                        div(
                          style = "display: flex; width: 770px; justify-content: space-between;",
                          
                          # DTC count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_sku_count")
                          ),
                          
                          # Amazon count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_sku_amazon_count")
                          ),
                          # Rachio count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_sku_rachio_count")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_sku_weatherflow_count")
                          ),
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_sku_walmart_count")
                          ),
                          # all
                          div(
                            style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                            textOutput("yellow_sku_all_channels")
                          )
                        )
                        
                      )
                    ),
                    # Blue with Solar SKU block
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("blue_roof_sku_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #2980b9;">Blue</span> Smart Bird Feeder with Solar Roof')
                          ),
                          div(style = "font-size: 10px; color: #888888;", "BBG1003BAB	BBG1003BAC")
                        ),
                        # 2b) DTC & Amazon counts container
                        div(
                          style = "display: flex; width: 770px; justify-content: space-between;",
                          
                          # DTC count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_roof_sku_count")
                          ),
                          
                          # Amazon count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_roof_sku_amazon_count")
                          ),
                          # Rachio count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_roof_sku_rachio_count")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_roof_sku_weatherflow_count")
                          ),
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("blue_roof_sku_walmart_count")
                          ),
                          # all
                          div(
                            style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                            textOutput("blue_roof_sku_all_channels")
                          )
                        )
                      )
                    ),
                    
                    # Yellow with Solar SKU block
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("yellow_roof_sku_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #f1c40f;">Yellow</span> Smart Bird Feeder with Solar Roof')
                          ),
                          div(style = "font-size: 10px; color: #888888;", "BYG1003BAB	BYG1003BAC")
                        ),
                        # 2b) DTC & Amazon counts container
                        div(
                          style = "display: flex; width: 770px; justify-content: space-between;",
                          
                          # DTC count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_roof_sku_count")
                          ),
                          
                          # Amazon count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_roof_sku_amazon_count")
                          ),
                          # Rachio count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_roof_sku_rachio_count")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_roof_sku_weatherflow_count")
                          ),
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("yellow_roof_sku_walmart_count")
                          ),
                          # all
                          div(
                            style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                            textOutput("yellow_roof_sku_all_channels")
                          )
                        )
                      )
                    ),
                    # Smart Hummingbird Feeder
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("hbf_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML("Smart Hummingbird Feeder")
                          ),
                          div(style = "font-size: 10px; color: #888888;", "BWH1023BAA	BWH1023BAB")
                        ),
                        # 2b) DTC & Amazon counts container
                        div(
                          style = "display: flex; width: 770px; justify-content: space-between;",
                          
                          # DTC count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("hbf_count")
                          ),
                          
                          # Amazon count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # Rachio count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # all
                          div(
                            style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                            textOutput("hbf_all_channels")
                          )
                        )
                      )
                    ),
                    
                    # Smart Hummingbird Feeder with Solar Roof
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("hbf_solar_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML("Smart Hummingbird Feeder with Solar Roof")
                          ),
                          div(style = "font-size: 10px; color: #888888;", "BWH1025BAA	BWH1025BAB")
                        ),
                        # 2b) DTC & Amazon counts container
                        div(
                          style = "display: flex; width: 770px; justify-content: space-between;",
                          
                          # DTC count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("hbf_solar_count")
                          ),
                          
                          # Amazon count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # Rachio count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # WF count
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          # all
                          div(
                            style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                            textOutput("hbf_solar_all_channels")
                          )
                        )
                      )
                    ),
                    
                    # …after all your SKU blocks…
                    
                    # …inside your tabItem(tabName = "pnl", …) after all SKU blocks…
                    
                    # Totals row
                    div(
                      style = "display: flex;
           align-items: center;
           background-color: transparent;
           padding: 15px;",
                      
                      # Push everything left so totals stick to the right
                      div(style = "flex: 1;"),
                      
                      # Fixed-width two-column wrapper matching header (2 × 80px + gutter)
                      div(
                        style = "display: flex;
             width: 770px;
             justify-content: space-between;",
                        
                        # DTC TOTAL
                        div(
                          style = "width: 100px;
               text-align: center;",
                          div(HTML("DTC<br/>TOTAL"),
                              style = "font-size: 10px;
             font-weight: 500;
             color: #555;
             line-height: 1.2;"),
                          div(textOutput("sku_total_units"),
                              style = "font-size: 18px;
                   font-weight: bold;
                   color: #727272;")
                        ),
                        
                        # AMAZON TOTAL
                        div(
                          style = "width: 100px;
               text-align: center;",
                          div(HTML("AMAZON<br/>TOTAL"),
                              style = "font-size: 10px;
             font-weight: 500;
             color: #555;
             line-height: 1.2;"),
                          div(textOutput("sku_total_amazon_units"),
                              style = "font-size: 18px;
                   font-weight: bold;
                   color: #727272;")
                        ),
                        # RACHIO TOTAL
                        div(
                          style = "width: 100px; text-align: center;",
                          div(HTML("RACHIO<br/>TOTAL"),
                              style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                          div(textOutput("sku_total_rachio_units"),
                              style = "font-size: 18px; font-weight: bold; color: #727272;")
                        ),
                        # wf TOTAL
                        div(
                          style = "width: 100px; text-align: center;",
                          div(HTML("WEATHERFLOW<br/>TOTAL"),
                              style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                          div(textOutput("sku_total_weatherflow_units"),
                              style = "font-size: 18px; font-weight: bold; color: #727272;")
                        ),
                        div(
                          style = "width: 100px; text-align: center;",
                          div(HTML("WALMART<br/>TOTAL"),
                              style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                          div(textOutput("sku_total_walmart_units"),
                              style = "font-size: 18px; font-weight: bold; color: #727272;")
                        ),
                        # TOTAL
                        div(
                          style = "width: 150px; text-align: center;",
                          div(HTML("GRAND<br/>TOTAL"),
                              style = "font-size: 10px; font-weight: 500; color: #000000; line-height: 1.2;"),
                          div(textOutput("grand_total_all_channels"),
                              style = "font-size: 18px; font-weight: bold; color: #000000;")
                        )
                      )
                    )
                    
                    
                )  
                    
                    
                    
                    
                ),
              # ---- Add-ons Sold (Gross) Section ----
              div(
                style = "background-color: rgba(255, 255, 255, 0.2); border-radius: 20px; padding: 30px; margin-top: 20px;",
                
                # Header row
                div(
                  style = "display: flex; align-items: center; padding: 15px;",
                  div("Add-ons Sold (Gross)",
                      style = "font-family: 'Montserrat'; font-size: 24px; font-weight: bold; flex: 1;"
                  ),
                  div(
                    style = "display: flex; width: 400px; justify-content: space-between;",
                    div("DTC",    style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Amazon", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div(HTML("ALL<br/>CHANNELS"),
                        style = "font-size: 10px; font-weight: 500; color: #555; text-align: center; width: 150px;")
                  )
                ),
                
                # Add-on rows
                div(style = "display: flex; flex-direction: column; gap: 20px;",
                      # Wall Mount
                      div(
                        style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_wall_mount_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div("Wall Mount", style = "font-size: 16px; font-weight: bold; color: #000000;"),
                            div("BNG1009BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_wall_mount_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_wall_mount_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_wall_mount_all_channels")
                            )
                          )
                          
                        )
                      ),
                      
                      # Suet Ball Holder
                      div(
                        style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_suet_ball_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div("Suet Ball Holder", style = "font-size: 16px; font-weight: bold; color: #000000;"),
                            div("BNG1011BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_suet_ball_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_suet_ball_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_suet_ball_all_channels")
                            )
                          )
                        )
                      ),
                      
                      # Blue 3-in-1 Nutrition Set
                      div(
                        style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_blue_nutrition_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #2980b9;">Blue</span> 3-in-1 Nutrition Set')
                            ),
                            div("BCG1013BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_blue_nutrition_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_3in1_blue_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_blue_nutrition_all_channels")
                            )
                          )
                        )
                      ),
                      
                      # Yellow 3-in-1 Nutrition Set
                      div(
                        style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_yellow_nutrition_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #f1c40f;">Yellow</span> 3-in-1 Nutrition Set')
                            ),
                            div("BYG1013BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_yellow_nutrition_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_3in1_yellow_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_yellow_nutrition_all_channels")
                            )
                          )
                        )
                        ),
                      
                      
                      # Blue Solar Roof Single
                      div(
                        style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_solar_roof_blue_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #2980b9;">Blue</span> Solar Roof Single')
                            ),
                            div("BBG1005BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_solar_roof_blue_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_solar_roof_blue_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_solar_roof_blue_all_channels")
                            )
                          )
                        )
                      ),
                      
                      # Yellow Solar Roof Single
                      div(
                        style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_solar_roof_yellow_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #f1c40f;">Yellow</span> Solar Roof Single')
                            ),
                            div("BYG1005BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_solar_roof_yellow_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_solar_roof_yellow_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_solar_roof_yellow_all_channels")
                            )
                          )
                        )
                      ),
                      
                      
                      # Blue Perch Extender
                      div(
                        style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_perch_extender_blue_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #2980b9;">Blue</span> Perch Extender')
                            ),
                            div("BBG1021BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_perch_extender_blue_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_perch_extender_blue_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_perch_extender_blue_all_channels")
                            )
                          )
                        )
                      ),
                      
                      # Yellow Perch Extender
                      div(
                        style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_perch_extender_yellow_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #f1c40f;">Yellow</span> Perch Extender')
                            ),
                            div("BYG1021BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_perch_extender_yellow_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_perch_extender_yellow_amz_count")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_perch_extender_yellow_all_channels")
                            )
                          )
                        )
                      ),
                      
                      # Solar Roof (HBF)
                      div(
                        style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_hbf_solar_roof_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #b12625;">HBF</span> Solar Roof Single')
                            ),
                            div("BWH1026BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_hbf_solar_roof_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_hbf_solar_roof_all_channels")
                            )
                          )
                        )
                      ),
                      
                      # Housing - only (HBF)
                      div(
                        style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                        uiOutput("addon_hbf_housing_image"),
                        div(
                          style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                          div(
                            div(
                              style = "font-size: 16px; font-weight: bold; color: #000000;",
                              HTML('<span style="color: #b12625;">HBF</span> Housing')
                            ),
                            div("BWH1022BAA", style = "font-size: 10px; color: #888888;")
                          ),
                          # 2b) DTC & Amazon counts container
                          div(
                            style = "display: flex; width: 400px; justify-content: space-between;",
                            
                            # DTC count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("addon_hbf_housing_count")
                            ),
                            
                            # Amazon count
                            div(
                              style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                              textOutput("")
                            ),
                            # all
                            div(
                              style = "width:150px; text-align:center; font-size:18px; font-weight: bold; color: #727272;",
                              textOutput("addon_hbf_housing_all_channels")
                            )
                          )
                        )
                      )
                      ),
                      
                # …after all your add-on blocks…
                div(
                  style = "display: flex; align-items: center; background-color: transparent; padding: 15px; justify-content: space-between;",
                  div(),  # spacer pushes totals to the right
                  div(
                    style = "display: flex; width: 400px; justify-content: space-between;",
                    # DTC TOTAL
                    div(
                      style = "width: 100px; text-align: center;",
                      div(HTML("DTC<br/>TOTAL"),
                          style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                      div(textOutput("addon_total_units"),
                          style = "font-size: 18px; font-weight: bold; color: #727272;")
                    ),
                    # AMAZON TOTAL
                    div(
                      style = "width: 100px; text-align: center;",
                      div(HTML("AMAZON<br/>TOTAL"),
                          style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                      div(textOutput("addon_4_total_amz_units"),
                          style = "font-size: 18px; font-weight: bold; color: #727272;")
                    ),
                    # ALL-CHANNELS GRAND TOTAL
                    div(
                      style = "width: 150px; text-align: center;",
                      div(HTML("GRAND<br/>TOTAL"), style = "font-size: 10px; font-weight: 500; color: #000000; line-height: 1.2;"),
                      div(textOutput("addon_grand_total_all_channels"), style = "font-size: 18px; font-weight: bold; color: #000000;")
                    )
                  )
                )
              ),
      
              # ---- App Subscriptions Section ----
              div(
                style = "background-color: rgba(255, 255, 255, 0.2); border-radius: 20px; padding: 30px; margin-top: 20px;",
                
                # Header row
                div(
                  style = "display: flex; align-items: center; padding: 15px;",
                  div("App Subscriptions",
                      style = "font-family: 'Montserrat'; font-size: 24px; font-weight: bold; flex: 1;"
                  ),
                  div(
                    style = "display: flex; width: 500px; justify-content: space-between;",
                    div("DTC",    style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Apple",  style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Google", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div(HTML("ALL<br/>CHANNELS"),
                        style = "font-size: 10px; font-weight: 500; color: #555; text-align: center; width: 150px;")
                  )
                ),
                
                # Subscription rows
                div(style = "display: flex; flex-direction: column; gap: 20px;",
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("premium_subscription_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML("1 Year Birdbuddy Premium Subscription")
                          ),
                          div(style = "font-size: 10px; color: #888888;", "BN24PROCAA BN24FAMCAA")
                        ),
                        # Counts
                        div(
                          style = "display: flex; width: 500px; justify-content: space-between;",
                          div(style = "width: 100px; text-align: center; font-size: 16px; font-weight: 400;", textOutput("dtc_subs_count")),
                          div(style = "width: 100px; text-align: center; font-size: 16px; font-weight: 400;", textOutput("apple_subs_count")),
                          div(style = "width: 100px; text-align: center; font-size: 16px; font-weight: 400;", textOutput("google_subs_count")),
                          div(style = "width: 150px; text-align: center; font-size: 18px; font-weight: bold; color: #727272;", textOutput("total_subs_all_channels"))
                        )
                      )
                    ),
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("premium_monthly_subscription_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML("Monthly Birdbuddy Premium Subscription")
                          ),
                          div(style = "font-size: 10px; color: #888888;", " ")
                        ),
                        # Counts
                        div(
                          style = "display: flex; width: 500px; justify-content: space-between;",
                          div(
                            style = "width:100px; text-align:center; font-size:16px; font-weight:400;",
                            textOutput("")
                          ),
                          div(style = "width: 100px; text-align: center; font-size: 16px; font-weight: 400;", textOutput("apple_monthly_subs_count")),
                          div(style = "width: 100px; text-align: center; font-size: 16px; font-weight: 400;", textOutput("google_monthly_subs_count")),
                          div(style = "width: 150px; text-align: center; font-size: 18px; font-weight: bold; color: #727272;", textOutput("total_subs_monthly_all_channels"))
                        )
                      )
                    )
                    
                ),
                
                # …after all your add-on blocks…
                div(
                  style = "display: flex; align-items: center; background-color: transparent; padding: 15px; justify-content: space-between;",
                  div(),  # spacer pushes totals to the right
                  div(
                    style = "display: flex; width: 500px; justify-content: space-between;",
                    # DTC TOTAL
                    div(
                      style = "width: 100px; text-align: center;",
                      div(HTML("DTC<br/>TOTAL"),
                          style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                      div(textOutput("subs_total_dtc"),
                          style = "font-size: 18px; font-weight: bold; color: #727272;")
                    ),
                    # AMAZON TOTAL
                    div(
                      style = "width: 100px; text-align: center;",
                      div(HTML("APPLE<br/>TOTAL"),
                          style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                      div(textOutput("subs_total_apple"),
                          style = "font-size: 18px; font-weight: bold; color: #727272;")
                    ),
                    # AMAZON TOTAL
                    div(
                      style = "width: 100px; text-align: center;",
                      div(HTML("GOOGLE<br/>TOTAL"),
                          style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                      div(textOutput("subs_total_google"),
                          style = "font-size: 18px; font-weight: bold; color: #727272;")
                    ),
                    # ALL-CHANNELS GRAND TOTAL
                    div(
                      style = "width: 150px; text-align: center;",
                      div(HTML("GRAND<br/>TOTAL"), style = "font-size: 10px; font-weight: 500; color: #000000; line-height: 1.2;"),
                      div(textOutput("subs_total_all_channels"), style = "font-size: 18px; font-weight: bold; color: #000000;")
                    )
                  )
                )
              ),
              
              
                      
      # ---- Seeds Sold (Gross) Section ----
      div(
        style = "background-color: rgba(255, 255, 255, 0.2); border-radius: 20px; padding: 30px; margin-top: 20px;",
        
        # Header row
        div(
          style = "display: flex; align-items: center; padding: 15px;",
          div("Seeds Sold (Gross)",
              style = "font-family: 'Montserrat'; font-size: 24px; font-weight: bold; flex: 1;"
          ),
          div("DTC", style = "font-size: 16px; font-weight: bold; text-align: center; width: 150px;")
        ),
        
        # Seed rows
        div(style = "display: flex; flex-direction: column; gap: 20px;",
                # Seeds Blocks
                div(style = "display: flex; flex-direction: column; gap: 20px;",
                    # Seasonal Curation - 8lb
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("seasonal_8lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #2b243f;">8lb</span> Seasonal Curation')
                          ),
                          div("BNE1035PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_seasonal_8lb"))
                        )
                      )
                    ),
                    # Seasonal Curation - 20lb
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("seasonal_20lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #806ac6;">20lb</span> Seasonal Curation')
                          ),
                          div("BNT1035PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_seasonal_20lb"))
                        )
                      )
                    ),
                    # Buddy Bites - 8lb
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("buddy_bites_8lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #2b243f;">8lb</span> Buddy Bites')
                          ),
                          div("BNE1033PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_buddy_8lb"))
                        )
                      )
                    ),
                    # Buddy Bites - 20lb
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("buddy_bites_20lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #806ac6;">20lb</span> Buddy Bites')
                          ),
                          div("BNT1033PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_buddy_20lb"))
                        )
                      )
                    ),
                    # Snack n' Soar - 8lb
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("snack_8lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #2b243f;">8lb</span> Snack n Soar')
                          ),
                          div("BNE1035PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_snack_8lb"))
                        )
                      )
                    ),
                    # Snack n' Soar - 20lb
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("snack_20lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #806ac6;">20lb</span> Snack n Soar')
                          ),
                          div("BNT1035PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_snack_20lb"))
                        )
                      )
                    ),
                    # Avian Choice - 8lb
                    div(
                      style = "display: flex; align-items: center; background-color: #ffffff; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("avian_8lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #2b243f;">8lb</span> Avian Choice')
                          ),
                          div("BNE1034PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_avian_8lb"))
                        )
                      )
                    ),
                    # Avian Choice - 20lb
                    div(
                      style = "display: flex; align-items: center; background-color: #f3f3f3; border-radius: 15px; padding: 15px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
                      uiOutput("avian_20lb_image"),
                      div(
                        style = "width: 100%; display: flex; justify-content: space-between; align-items: center;",
                        div(
                          div(
                            style = "font-size: 16px; font-weight: bold; color: #000000;",
                            HTML('<span style="color: #806ac6;">20lb</span> Avian Choice')
                          ),
                          div("BNT1034PUA", style = "font-size: 10px; color: #888888;")
                        ),
                        div(style = "width: 150px; text-align: center;",
                            div(style = "font-size: 16px; font-weight: 400; color: black;", textOutput("seed_avian_20lb"))
                        )
                      )
                    ),
                    
                    
                div(
                  style = "display: flex; align-items: center; background-color: transparent; padding: 15px; justify-content: space-between;",
                  div(),
                  div(
                    style = "width: 150px; text-align: center;",
                    div(HTML("DTC<br/>TOTAL"),
                        style = "font-size: 10px; font-weight: 500; color: #555; line-height: 1.2;"),
                    div(textOutput("seed_total_units"), style = "font-size: 18px; font-weight: bold; color: #727272;")
                  )
                )
                
                )
        )
      )
              
      ),
      # New P&L Visualizations tab
      tabItem(
        tabName = "pnl_viz",
        # In your UI (wherever you dropped the Units panel), change to:
        
        # ---------- UI ----------
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      <span style='color:#2ecc71;'>Units</span>, 
      <span style='color:#3498db;'>Add-ons</span> & 
      <span style='color:#f39c12;'>Seeds</span> by Channel
    </h2>"),
            div(
              style = "display: flex; gap: 12px; align-items: center;",
              
              # only when “Absolute” is selected, but force it to be a flex row with no extra margins
              conditionalPanel(
                condition = "input.units_ua_view == 'Absolute'",
                style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                checkboxInput(
                  "units_line_view",
                  "Line chart view",
                  value = FALSE,
                  width = "150px"
                )
              ),
              
              # force this one too, just to be symmetric
              div(
                style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                checkboxInput(
                  "units_include_seeds",
                  "Include Seeds",
                  value = TRUE,
                  width = "130px"
                )
              ),
              
              selectInput(
                "units_ua_channel", NULL,
                choices = c(
                  "All" = "All",
                  "DTC" = "DTC",
                  "Amazon" = "Amazon",
                  "Digital Marketplaces" = "Digital"
                ),
                selected = "All",
                width = "180px"
              ),
              
              selectInput(
                "units_ua_view", NULL,
                choices = c("Absolute", "Relative"),
                selected = "Absolute",
                width = "150px"
              )
            )
            
            
          ),
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px;
             box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("units_ua_plot", height = "800px")
          )
        ),
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
      Unit Count by Channel
    </h2>"),
            div(id    = "topbar",
                style = "display:flex; gap:12px; align-items:center;",
                ## new: line/column toggle –visible only in ABSOLUTE mode
                conditionalPanel(
                  style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                  "input.sbf_hbf_view == 'Absolute' ||
           input.grouped_skus_view == 'Absolute' ||
           input.sku_view == 'Absolute'",
                  checkboxInput("line_view", "Line chart view", FALSE,
                                width = "130px")
                ),
                div(
                  style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                checkboxInput("by_type",        "By Type",          FALSE, width="110px"),
                checkboxInput("by_type_colour", "By Type & Colour", FALSE, width="150px"),
                ),
                
                # push everything that follows to the right
                div(style="margin-left:auto; display:flex; gap:12px; align-items:center;",
                    
                    uiOutput("compact_filters")
                    
                    
                )
            )
            
        ),
        
        ## the rest of your layout .................................................
        uiOutput("long_filters"),           # SKUs / groups (second row, if needed)
        div(style = "background:#fff; border-radius:20px; padding:20px;
              box-shadow:0 0 10px rgba(0,0,0,.05);",
            plotlyOutput("sku_plot", height = "800px")
        )
        ),
        
        
        
        
        ## ────────────────────────────────────────────────────────────────
        ## ADD‑ON DASHBOARD BLOCK  (UI)
        ## ────────────────────────────────────────────────────────────────
        div(
          style = "font-family:'Montserrat',sans-serif; padding:20px;",
          
          ## ── Header row ────────────────────────────────────────────────
          div(
            style = "display:flex; justify-content:space-between;
             align-items:center; margin-bottom:20px;",
            
            HTML("<h2 style='font-family:Montserrat; font-weight:bold;
                 color:#333; margin:0;'>
            Add‑on Count by Channel
          </h2>"),
            
            ## top‑bar controls ---------------------------------------------------------
            div(id    = "topbar_addon",
                style = "display:flex; gap:12px; align-items:center;",
                
                ## (1) optional Line‑chart toggle  – visible only when an
                ##     *Absolute* add‑on view is selected
                ##     (re‑use the global `line_view` checkbox if you already
                ##      created it for “Units”; otherwise leave as‑is)
                conditionalPanel(
                  style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                  "input.addon_view == 'Absolute' ||
           input.grouped_addons_view == 'Absolute'",
                  checkboxInput("line_view", "Line chart view",
                                FALSE, width = "130px")
                ),
                
                ## (2) granularity toggle  – only one for add‑ons
                div(
                  style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                checkboxInput("by_colour_addon", "By Colour",
                              FALSE, width = "110px"),
                ),
                ## push the compact selectors to the right
                div(style = "margin-left:auto; display:flex;
                     gap:12px; align-items:center;",
                    uiOutput("compact_addon_filters")
                )
            )
          ),
          
          ## ── 2nd‑row selectors (shown if needed) ───────────────────────
          uiOutput("long_addon_filters"),
          
          ## ── Plot container ────────────────────────────────────────────
          div(
            style = "background:#fff; border-radius:20px; padding:20px;
             box-shadow:0 0 10px rgba(0,0,0,.05);",
            plotlyOutput("addon_plot", height = "800px")
          )
        ),
        
        
        # UI
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>
          Seed Count by Type
        </h2>"),
            
            ## top‑bar controls ---------------------------------------------------------
            div(id    = "seed_topbar",
                style = "display:flex; gap:12px; align-items:center;",
                ## (2) granularity toggle  – only one for add‑ons
                div(
                  style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                  checkboxInput("seed_by_weight", "By Weight",
                                FALSE, width = "110px"),
                ),
                
                ## (1) optional Line‑chart toggle  – visible only when an
                ##     *Absolute* add‑on view is selected
                ##     (re‑use the global `line_view` checkbox if you already
                ##      created it for “Units”; otherwise leave as‑is)
                conditionalPanel(
                  style = "display: flex; align-items: center; margin-top: 0; margin-bottom: 0;",
                  "input.seed_view_mode == 'Absolute'",
                  checkboxInput("seed_line_view", "Line chart view",
                                FALSE, width = "130px")
                ),
                selectInput("seed_view_mode", NULL,
                            c("Absolute", "Relative"),
                            selected = "Absolute", width = "120px")
                
                
            )
            
            
            
          ),
          uiOutput("seed_selector_ui"),
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("seed_plot", height = "700px")
          )
        ),
        # --- App Subscription by Channel ---
        div(
          style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
          div(
            style = "display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px;",
            HTML("<h2 style='font-family: Montserrat; font-weight: bold; color: #333; margin: 0;'>App Subscription by Channel</h2>"),
            div(
              style = "display:flex; gap:12px; align-items:center;",
              
              conditionalPanel(
                condition = "input.appsubs_view == 'Absolute'",
                style = "display:flex; align-items:center;",
                checkboxInput("appsubs_line_view", "Line chart view", value = FALSE, width = "150px")
              ),
              
              selectInput(
                "appsubs_channel", NULL,
                choices = c("All" = "All", "DTC" = "DTC", "Apple" = "Apple", "Google" = "Google"),
                selected = "All", width = "180px"
              ),
              
              selectInput(
                "appsubs_view", NULL,
                choices = c("Absolute", "Relative"), selected = "Absolute", width = "150px"
              )
            )
          ),
          plotlyOutput("app_subs_by_channel_plot", height = "520px")
        )
        
        
        
        
        
          
      ),
      tabItem(
        tabName = "survey",
        div(style = "font-family: 'Montserrat', sans-serif; padding: 20px;",
            
            # Header row: title (left) + segment picker (right)
            div(
              style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:20px;",
              h2(
                htmlOutput("overview_title"),
                style = "font-family: Montserrat; font-weight: bold; color: #333; margin: 0;"
              ),
              uiOutput("seg_picker")   # <-- right-aligned slot for the segment dropdown
            ),
            
            # Controller input — keep it off-screen, not display:none
            div(style = "position:absolute; left:-9999px; top:-9999px; width:0; height:0; overflow:hidden;",
                selectInput("survey_view", label = NULL,
                            choices = c("All","Q1","Q2","Q3","Q4","Q5","Q6"),
                            selected = "All")
            ),
            
            uiOutput("survey_layout"),
            
            
            # ↓ Put this right BELOW the Q1 stacked % block in your survey tab UI
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(
                style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                h4("Engagement Rate by Day",
                   style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q1_engagement_bar", height = "400px")
            ),
            
            
            # Full-width Q1 by day (stacked %)
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q1: Where did you hear about Bird Buddy?",
                     style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q1_daily_stack", height = "700px")
            ),
            
            # Full-width Q2 by day (stacked %)
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q2: Where on FB/IG have you heard about Bird Buddy?",
                     style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q2_daily_stack", height = "700px")
            ),
            
            # Full-width Q3 by day (stacked %)
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q3: Who is this for?",
                     style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q3_daily_stack", height = "700px")
            ),
            
            # Full-width Q4 by day (stacked %)
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q4: Are you a new or existing customer?",
                     style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q4_daily_stack", height = "700px")
            ),
            # Full-width Q5 by day (stacked %)
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q5: Did you buy this for your household?",
                     style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q5_daily_stack", height = "700px")
            ),
            # Full-width Q6 by day (stacked %)
            div(
              style = "margin-top: 20px; background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style = "display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q6: Did you buy this as a gift??",
                     style = "font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;")
              ),
              plotlyOutput("q6_daily_stack", height = "700px")
            ),
        )
      )
      
      
      
      
      
      
      
      
      
      
        )   
      
      
    )
    
    
    
  )





# ---- Server Logic ----
# Define Server Logic
server <- function(input, output, session) {
  # Reactive value to track if the additional app spend details are visible
  

  
  app_spend_visible <- reactiveVal(FALSE)
  dtc_revenue_visible <- reactiveVal(FALSE)
  amazon_revenue_visible <- reactiveVal(FALSE)
  dtc_spend_visible <- reactiveVal(FALSE)
  fees_visible <- reactiveVal(FALSE)
  digital_marketplaces_visible <- reactiveVal(FALSE)
  b2b_visible <- reactiveVal(FALSE)
  app_revenue_visible <- reactiveVal(FALSE)
  dtc_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_dtc_orders, {
    dtc_orders_visible(!dtc_orders_visible())
  })
  amazon_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_amazon_orders, {
    amazon_orders_visible(!amazon_orders_visible())
  })
  
  digital_marketplaces_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_digital_marketplaces_orders, {
    digital_marketplaces_orders_visible(!digital_marketplaces_orders_visible())
  })
  b2b_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_b2b_orders, {
    b2b_orders_visible(!b2b_orders_visible())
  })
  app_orders_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_app_orders, {
    app_orders_visible(!app_orders_visible())
  })
  
  
  # Toggle visibility when the button is clicked
  observeEvent(input$toggle_app_spend, {
    app_spend_visible(!app_spend_visible())
  })
  observeEvent(input$toggle_dtc_revenue, {
    dtc_revenue_visible(!dtc_revenue_visible())
  })
  observeEvent(input$toggle_amazon_revenue, { # New toggle for Amazon Revenue
    amazon_revenue_visible(!amazon_revenue_visible())
  })
  observeEvent(input$toggle_dtc_spend, {
    dtc_spend_visible(!dtc_spend_visible())
  })
  observeEvent(input$toggle_fees, {
    fees_visible(!fees_visible())
  })
  observeEvent(input$toggle_digital_marketplaces, {
    digital_marketplaces_visible(!digital_marketplaces_visible())
  })
  observeEvent(input$toggle_b2b_revenue, {
    b2b_visible(!b2b_visible())
  })
  observeEvent(input$toggle_app_revenue, {
    app_revenue_visible(!app_revenue_visible())
  })
  
  # Function to calculate percentage change
  percentage_change <- function(current, previous) {
    if (is.na(previous) || previous == 0) {
      return(NA)
    }
    return((current - previous) / previous * 100)
  }
  
  # Reactive data for selected date
  selected_data <- reactive({
    req(input$selected_date_range)
    range_dates <- input$selected_date_range
    filtered_data <- revenue_data %>%
      filter(Date >= range_dates[1] & Date <= range_dates[2])
    
    total_revenue <- sum(filtered_data$Total_Revenue, na.rm = TRUE)
    total_spend <- sum(filtered_data$Total_Spend, na.rm = TRUE)
    dtc_revenue <- sum(filtered_data$DTC_Revenue, na.rm = TRUE)
    dtc_spend <- sum(filtered_data$Total_DTC_Spend, na.rm = TRUE)
    amazon_revenue <- sum(filtered_data$Amazon_Revenue, na.rm = TRUE)
    amazon_spend <- sum(filtered_data$Amazon_Spend, na.rm = TRUE)
    app_revenue <- sum(filtered_data$App_Revenue, na.rm = TRUE)
    app_spend <- sum(filtered_data$Total_App_Spend, na.rm = TRUE)
    
    blue_sku_count <- sum(filtered_data$`dtc_SKU 1 - Blue`, na.rm = TRUE)
    yellow_sku_count <- sum(filtered_data$`dtc_SKU 2 - Yellow`, na.rm = TRUE)
    blue_roof_sku_count <- sum(filtered_data$`dtc_SKU 3 - Blue w/ Solar`, na.rm = TRUE)
    yellow_roof_sku_count <- sum(filtered_data$`dtc_SKU 4 - Yellow w/ Solar`, na.rm = TRUE)
    hbf_count <- sum(filtered_data$`dtc_SKU 5 - HBF`, na.rm = TRUE)
    hbf_solar_count <- sum(filtered_data$`dtc_SKU 6 - HBF w/ Solar`, na.rm = TRUE)
    # Add-on Units
    wall_mount_units <- sum(filtered_data$`dtc_Wall Mount`, na.rm = TRUE)
    suet_ball_units <- sum(filtered_data$`dtc_Suet Ball Holder`, na.rm = TRUE)
    blue_nutrition_units <- sum(filtered_data$`dtc_3-in-1 Nutrition Set - Blue`, na.rm = TRUE)
    yellow_nutrition_units <- sum(filtered_data$`dtc_3-in-1 Nutrition Set - Yellow`, na.rm = TRUE)
    solar_roof_blue_units <- sum(filtered_data$`dtc_Solar Roof Single - Blue`, na.rm = TRUE)
    solar_roof_yellow_units <- sum(filtered_data$`dtc_Solar Roof Single - Yellow`, na.rm = TRUE)
    perch_extender_blue_units <- sum(filtered_data$`dtc_Perch Extender - Blue`, na.rm = TRUE)
    perch_extender_yellow_units <- sum(filtered_data$`dtc_Perch Extender - Yellow`, na.rm = TRUE)
    hbf_solar_roof_units <- sum(filtered_data$`dtc_Solar Roof (HBF)`, na.rm = TRUE)
    hbf_housing_units <- sum(filtered_data$`dtc_Housing - only (HBF)`, na.rm = TRUE)
    
    # Seeds
    seasonal_8lb_units <- sum(filtered_data$`dtc_Seasonal Curation - 8lb`, na.rm = TRUE)
    seasonal_20lb_units <- sum(filtered_data$`dtc_Seasonal Curation - 20lb`, na.rm = TRUE)
    buddy_bites_8lb_units <- sum(filtered_data$`dtc_Buddy Bites - 8lb`, na.rm = TRUE)
    buddy_bites_20lb_units <- sum(filtered_data$`dtc_Buddy Bites - 20lb`, na.rm = TRUE)
    snack_soar_8lb_units <- sum(filtered_data$`dtc_Snack n' Soar - 8lb`, na.rm = TRUE)
    snack_soar_20lb_units <- sum(filtered_data$`dtc_Snack n' Soar - 20lb`, na.rm = TRUE)
    avian_choice_8lb_units <- sum(filtered_data$`dtc_Avian Choice - 8lb`, na.rm = TRUE)
    avian_choice_20lb_units <- sum(filtered_data$`dtc_Avian Choice - 20lb`, na.rm = TRUE)
    
    #AMAZON
    
    blue_sku_amz_count        <- sum(filtered_data$`amazon_SKU 1 - Blue`,           na.rm = TRUE)
    yellow_sku_amz_count      <- sum(filtered_data$`amazon_SKU 2 - Yellow`,         na.rm = TRUE)
    blue_roof_sku_amz_count   <- sum(filtered_data$`amazon_SKU 3 - Blue w/ Solar`,  na.rm = TRUE)
    yellow_roof_sku_amz_count <- sum(filtered_data$`amazon_SKU 4 - Yellow w/ Solar`,na.rm = TRUE)
    amz_wall_mount_units      <- sum(filtered_data$`amazon_Wall Mount`,           na.rm = TRUE)
    amz_suet_ball_units       <- sum(filtered_data$`amazon_Suet Ball Holder`,    na.rm = TRUE)
    amz_3in1_blue_units      <- sum(filtered_data$`amazon_3-in-1 Nutrition Set - Blue`,   na.rm = TRUE)
    amz_3in1_yellow_units    <- sum(filtered_data$`amazon_3-in-1 Nutrition Set - Yellow`, na.rm = TRUE)
    amz_solar_blue_units     <- sum(filtered_data$`amazon_Solar Roof Single - Blue`,      na.rm = TRUE)
    amz_solar_yellow_units   <- sum(filtered_data$`amazon_Solar Roof Single - Yellow`,    na.rm = TRUE)
    amz_perch_blue_units     <- sum(filtered_data$`amazon_Perch Extender - Blue`,        na.rm = TRUE)
    amz_perch_yellow_units   <- sum(filtered_data$`amazon_Perch Extender - Yellow`,  na.rm = TRUE)
    
    
    # — Rachio units for each SKU —
    rachio_blue_count        <- sum(filtered_data$`rachio_SKU 1 - Blue`,           na.rm = TRUE)
    rachio_yellow_count      <- sum(filtered_data$`rachio_SKU 2 - Yellow`,         na.rm = TRUE)
    rachio_blue_roof_count   <- sum(filtered_data$`rachio_SKU 3 - Blue w/ Solar`,  na.rm = TRUE)
    rachio_yellow_roof_count <- sum(filtered_data$`rachio_SKU 4 - Yellow w/ Solar`,na.rm = TRUE)
    
    # — Weatherflow units for each SKU —
    wf_blue_count        <- sum(filtered_data$`weatherflow_SKU 1 - Blue`,           na.rm = TRUE)
    wf_yellow_count      <- sum(filtered_data$`weatherflow_SKU 2 - Yellow`,         na.rm = TRUE)
    wf_blue_roof_count   <- sum(filtered_data$`weatherflow_SKU 3 - Blue w/ Solar`,  na.rm = TRUE)
    wf_yellow_roof_count <- sum(filtered_data$`weatherflow_SKU 4 - Yellow w/ Solar`,na.rm = TRUE)
    
    # — WALMART units for each SKU —
    walmart_blue_sku_count        <- sum(filtered_data$`walmart_SKU 1 - Blue`,              na.rm = TRUE)
    walmart_yellow_sku_count      <- sum(filtered_data$`walmart_SKU 2 - Yellow`,            na.rm = TRUE)
    walmart_blue_roof_sku_count   <- sum(filtered_data$`walmart_SKU 3 - Blue w/ Solar`,     na.rm = TRUE)
    walmart_yellow_roof_sku_count <- sum(filtered_data$`walmart_SKU 4 - Yellow w/ Solar`,   na.rm = TRUE)
    
    # — WALMART add-ons —
    walmart_wall_mount_units        <- sum(filtered_data$`walmart_Wall Mount`,                    na.rm = TRUE)
    walmart_suet_ball_units         <- sum(filtered_data$`walmart_Suet Ball Holder`,              na.rm = TRUE)
    walmart_3in1_blue_units         <- sum(filtered_data$`walmart_3-in-1 Nutrition Set - Blue`,   na.rm = TRUE)
    walmart_3in1_yellow_units       <- sum(filtered_data$`walmart_3-in-1 Nutrition Set - Yellow`, na.rm = TRUE)
    walmart_solar_blue_units        <- sum(filtered_data$`walmart_Solar Roof Single - Blue`,      na.rm = TRUE)
    walmart_solar_yellow_units      <- sum(filtered_data$`walmart_Solar Roof Single - Yellow`,    na.rm = TRUE)
    walmart_perch_blue_units        <- sum(filtered_data$`walmart_Perch Extender - Blue`,         na.rm = TRUE)
    walmart_perch_yellow_units      <- sum(filtered_data$`walmart_Perch Extender - Yellow`,       na.rm = TRUE)
    
    
    
    
    # ROAS values
    blended_roas <- ifelse(total_spend == 0, NA, total_revenue / total_spend)
    wroas <- ifelse(dtc_spend == 0, NA, dtc_revenue / dtc_spend)
    aroas <- ifelse(amazon_spend == 0, NA, amazon_revenue / amazon_spend)
    approas <- ifelse(app_spend == 0, NA, app_revenue / app_spend)
    
    # helper to avoid divide-by-zero issues
    safe_div <- function(num, den) ifelse(is.na(den) | den == 0, NA, num / den)
    
    # ---- Blended SPU (hardware only) ----
    blended_units <- sum(
      coalesce(filtered_data$DTC_Hardware_Units, 0),
      coalesce(filtered_data$Amazon_Hardware_Units, 0),
      na.rm = TRUE
    )
    blended_SPU <- safe_div(sum(filtered_data$Total_Spend, na.rm = TRUE), blended_units)
    
    # ---- DTC SPU (hardware only) ----
    dtc_units <- sum(coalesce(filtered_data$DTC_Hardware_Units, 0), na.rm = TRUE)
    wSPU <- safe_div(sum(filtered_data$Total_DTC_Spend, na.rm = TRUE), dtc_units)
    
    # ---- Amazon SPU (hardware only) ----
    amazon_units <- sum(coalesce(filtered_data$Amazon_Hardware_Units, 0), na.rm = TRUE)
    aSPU <- safe_div(sum(filtered_data$Amazon_Spend, na.rm = TRUE), amazon_units)
    appSPU <- ifelse(sum(filtered_data$App_Orders, na.rm = TRUE) == 0, NA,
                     sum(filtered_data$Total_App_Spend, na.rm = TRUE) / sum(filtered_data$App_Orders, na.rm = TRUE))
    
    
    # Weighted averages
    # New CR + AOV logic (based on orders)
    web_cr <- weighted.mean(filtered_data$Web_CR, w = filtered_data$DTC_Orders, na.rm = TRUE)
    web_aov <- weighted.mean(filtered_data$Web_AOV, w = filtered_data$DTC_Orders, na.rm = TRUE)
    
    fAOV <- weighted.mean(filtered_data$fAOV, w = filtered_data$DTC_Orders, na.rm = TRUE)
    rAOV <- weighted.mean(filtered_data$rAOV, w = filtered_data$DTC_Orders, na.rm = TRUE)
    # Calculate weighted % of returning customers (based on DTC orders)
    returning_customer_rate <- weighted.mean(filtered_data$Returning_Customers, w = filtered_data$DTC_Orders, na.rm = TRUE)
    
    
    
    
    # Summarize everything else
    current_summary <- filtered_data %>%
      summarise(across(where(is.numeric), ~sum(.x, na.rm = TRUE)))
    
    # Add calculated values
    current_summary$Blended_ROAS <- blended_roas
    current_summary$wROAS <- wroas
    current_summary$aROAS <- aroas
    current_summary$appROAS <- approas
    current_summary$Web_CR <- web_cr
    current_summary$Web_AOV <- web_aov
    current_summary$fAOV <- fAOV
    current_summary$rAOV <- rAOV
    
    current_summary$Blue_SKU_Count <- blue_sku_count
    current_summary$Yellow_SKU_Count <- yellow_sku_count
    current_summary$Blue_Roof_SKU_Count <- blue_roof_sku_count
    current_summary$Yellow_Roof_SKU_Count <- yellow_roof_sku_count
    current_summary$HBF_Count <- hbf_count
    current_summary$HBF_Solar_Count <- hbf_solar_count
    current_summary$Wall_Mount_Units <- wall_mount_units
    current_summary$Suet_Ball_Units <- suet_ball_units
    current_summary$Blue_Nutrition_Units <- blue_nutrition_units
    current_summary$Yellow_Nutrition_Units <- yellow_nutrition_units
    current_summary$Solar_Roof_Blue_Units <- solar_roof_blue_units
    current_summary$Solar_Roof_Yellow_Units <- solar_roof_yellow_units
    current_summary$Perch_Extender_Blue_Units <- perch_extender_blue_units
    current_summary$Perch_Extender_Yellow_Units <- perch_extender_yellow_units
    current_summary$HBF_Solar_Roof_Units <- hbf_solar_roof_units
    current_summary$HBF_Housing_Units <- hbf_housing_units
    
    current_summary$Seasonal_Curation_8lb <- seasonal_8lb_units
    current_summary$Seasonal_Curation_20lb <- seasonal_20lb_units
    current_summary$Buddy_Bites_8lb <- buddy_bites_8lb_units
    current_summary$Buddy_Bites_20lb <- buddy_bites_20lb_units
    current_summary$Snack_Soar_8lb <- snack_soar_8lb_units
    current_summary$Snack_Soar_20lb <- snack_soar_20lb_units
    current_summary$Avian_Choice_8lb <- avian_choice_8lb_units
    current_summary$Avian_Choice_20lb <- avian_choice_20lb_units
    
    current_summary$Blue_SKU_AZ_Count        <- blue_sku_amz_count
    current_summary$Yellow_SKU_AZ_Count      <- yellow_sku_amz_count
    current_summary$Blue_Roof_SKU_AZ_Count   <- blue_roof_sku_amz_count
    current_summary$Yellow_Roof_SKU_AZ_Count <- yellow_roof_sku_amz_count
    current_summary$AMZ_Wall_Mount_Units        <- amz_wall_mount_units
    current_summary$AMZ_Suet_Ball_Units         <- amz_suet_ball_units
    current_summary$AMZ_3in1_Blue_Units         <- amz_3in1_blue_units
    current_summary$AMZ_3in1_Yellow_Units       <- amz_3in1_yellow_units
    current_summary$AMZ_Solar_Roof_Blue_Units   <- amz_solar_blue_units
    current_summary$AMZ_Solar_Roof_Yellow_Units <- amz_solar_yellow_units
    current_summary$AMZ_Perch_Extender_Blue_Units   <- amz_perch_blue_units
    current_summary$AMZ_Perch_Extender_Yellow_Units <- amz_perch_yellow_units
    
    current_summary$Rachio_Blue_SKU_Count        <- rachio_blue_count
    current_summary$Rachio_Yellow_SKU_Count      <- rachio_yellow_count
    current_summary$Rachio_Blue_Roof_SKU_Count   <- rachio_blue_roof_count
    current_summary$Rachio_Yellow_Roof_SKU_Count <- rachio_yellow_roof_count
    
    current_summary$Weatherflow_Blue_SKU_Count        <- wf_blue_count
    current_summary$Weatherflow_Yellow_SKU_Count      <- wf_yellow_count
    current_summary$Weatherflow_Blue_Roof_SKU_Count   <- wf_blue_roof_count
    current_summary$Weatherflow_Yellow_Roof_SKU_Count <- wf_yellow_roof_count
    
    # SKU counts
    current_summary$Walmart_Blue_SKU_Count        <- walmart_blue_sku_count
    current_summary$Walmart_Yellow_SKU_Count      <- walmart_yellow_sku_count
    current_summary$Walmart_Blue_Roof_SKU_Count   <- walmart_blue_roof_sku_count
    current_summary$Walmart_Yellow_Roof_SKU_Count <- walmart_yellow_roof_sku_count
    
    # Add-on units
    current_summary$Walmart_Wall_Mount_Units          <- walmart_wall_mount_units
    current_summary$Walmart_Suet_Ball_Units           <- walmart_suet_ball_units
    current_summary$Walmart_3in1_Blue_Units           <- walmart_3in1_blue_units
    current_summary$Walmart_3in1_Yellow_Units         <- walmart_3in1_yellow_units
    current_summary$Walmart_Solar_Roof_Blue_Units     <- walmart_solar_blue_units
    current_summary$Walmart_Solar_Roof_Yellow_Units   <- walmart_solar_yellow_units
    current_summary$Walmart_Perch_Extender_Blue_Units <- walmart_perch_blue_units
    current_summary$Walmart_Perch_Extender_Yellow_Units <- walmart_perch_yellow_units
    
    
    
    current_summary$Blended_SPU <- blended_SPU
    current_summary$wSPU <- wSPU
    current_summary$aSPU <- aSPU
    current_summary$appSPU <- appSPU
    current_summary$Returning_Customer_Rate <- returning_customer_rate
    
    
    list(
      current = current_summary,
      previous = NULL
    )
  })
  
  # Show/hide state
  notes_visible <- reactiveVal(FALSE)
  
  # Toggle visibility
  observeEvent(input$toggle_notes, {
    notes_visible(!notes_visible())
  })
  
  # Conditionally show button and notes if there are any
  output$campaign_notes_ui <- renderUI({
    req(input$selected_date_range)
    
    start_date <- input$selected_date_range[1]
    end_date   <- input$selected_date_range[2]
    
    relevant_notes <- campaign_notes_df %>%
      filter(start <= end_date & end >= start_date)
    
    if (nrow(relevant_notes) == 0) return(NULL)
    
    note_lines <- apply(relevant_notes, 1, function(row) {
      note_text <- gsub("\n", "<br>", row["note"])
      start_str <- format(as.Date(row["start"]), "%Y-%m-%d")
      end_str   <- format(as.Date(row["end"]), "%Y-%m-%d")
      paste0(
        "<span style='color:#7f8c8d;'>From <strong>", start_str,
        "</strong> until <strong>", end_str, "</strong>:</span> ",
        note_text
      )
    })
    
    tagList(
      actionButton(
        "toggle_notes",
        label = if (notes_visible()) "Hide Notes" else "Show Notes",
        icon = icon(if (notes_visible()) "angle-up" else "angle-down"),
        style = "background-color: #e0e0e0; border: none; font-family: Montserrat, sans-serif; font-size: 12px; margin-bottom: 10px;"
      ),
      if (notes_visible()) {
        HTML(paste0(
          "<div style='font-family: Montserrat, sans-serif;
                      font-size: 12px;
                      margin-bottom: 20px;
                      background-color: #f4f4f4;
                      padding: 10px;
                      border-radius: 10px;'>",
          paste(note_lines, collapse = "<br><br>"),
          "</div>"
        ))
      }
    )
  })
  
  
  
  
  
  
  # Total Revenue Output
  output$total_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$Total_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Total Revenue Percentage Change
  output$total_percentage_change <- renderText({
    if (!is.null(selected_data()$previous)) {
      change <- percentage_change(selected_data()$current$Total_Revenue, selected_data()$previous$Total_Revenue)
      if (!is.na(change)) {
        paste0("(", format(round(change, 2), nsmall = 2), "%)")
      }
    }
  })
  
  # DTC Revenue Output
  output$dtc_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$DTC_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Dynamically render the container with DTC Revenue subcategories
  output$dtc_revenue_details <- renderUI({
    if (dtc_revenue_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(
          HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$DTC_Hardware, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$DTC_Addons, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Merchandise:</strong> ", format(round(selected_data()$current$DTC_Merch, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Seeds:</strong> ", format(round(selected_data()$current$DTC_Seeds, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Premium Subscription:</strong> ", format(round(selected_data()$current$DTC_Subscription, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Taxes:</strong> ", format(round(selected_data()$current$DTC_Taxes, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Shipping:</strong> ", format(round(selected_data()$current$DTC_Shipping, 2), nsmall = 2, big.mark = ","), " $"))
        )
      )
    } else {
      NULL
    }
  })
  

  
  # Amazon Revenue Output
  output$amazon_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$Amazon_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  # Dynamically render the container with Amazon Revenue subcategories
  output$amazon_revenue_details <- renderUI({
    if (amazon_revenue_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(
          HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$Amazon_Hardware, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$Amazon_Addons, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Tax:</strong> ", format(round(selected_data()$current$Amazon_Tax, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Shipping:</strong> ", format(round(selected_data()$current$Amazon_Shipping, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Gift Wrap:</strong> ", format(round(selected_data()$current$Amazon_GiftWrap, 2), nsmall = 2, big.mark = ","), " $"))
        )
      )
    } else {
      NULL
    }
  })
  
  # Digital Marketplaces Revenue Output
  output$digital_marketplaces_output <- renderText({
    paste0(format(round(selected_data()$current$Digital_Marketplaces_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  output$digital_marketplaces_details <- renderUI({
    if (digital_marketplaces_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(HTML(paste0("<strong>Rachio Revenue:</strong> ", format(round(selected_data()$current$Rachio_Revenue, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Weatherflow Revenue:</strong> ", format(round(selected_data()$current$Weatherflow_Revenue, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # B2B Revenue Output
  output$b2b_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$B2B_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  output$b2b_revenue_details <- renderUI({
    if (b2b_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 20px;
        border-radius: 15px;
        margin-top: 1px;
        width: 130%;
        max-width: 700px;
        text-align: left;
        box-shadow: 0 2px 6px rgba(0,0,0,0.1);
      ",
        div(HTML(paste0("<strong>BestBuy Revenue: </strong>", 
                        format(round(selected_data()$current$BestBuy_Revenue, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Target Revenue: </strong>", 
                        format(round(selected_data()$current$Target_Revenue, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Walmart Revenue: </strong>", 
                        format(round(selected_data()$current$Walmart_Revenue, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # App Revenue Output
  output$app_revenue_output <- renderText({
    paste0(format(round(selected_data()$current$App_Revenue, 2), nsmall = 2, big.mark = ","), " $")
  })
  output$app_revenue_details <- renderUI({
    if (app_revenue_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 20px;
        border-radius: 15px;
        margin-top: 1px;
        width: 130%;
        max-width: 700px;
        text-align: right;
        float: right;
        box-shadow: 0 2px 6px rgba(0,0,0,0.1);
      ",
        div(HTML(paste0("<strong>Google Store:</strong> ",
                        format(round(selected_data()$current$Google_Store, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Apple Store:</strong> ",
                        format(round(selected_data()$current$Apple_Store, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Commission:</strong> ",
                        format(round(selected_data()$current$App_Comission, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Tax:</strong> ",
                        format(round(selected_data()$current$App_Tax, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # Total Spend Output
  output$total_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Total_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Total Spend Percentage Change
  output$total_spend_percentage_change <- renderText({
    if (!is.null(selected_data()$previous)) {
      change <- percentage_change(selected_data()$current$Total_Spend, selected_data()$previous$Total_Spend)
      if (!is.na(change)) {
        paste0("(", format(round(change, 2), nsmall = 2), "%)")
      }
    }
  })
  
  # DTC Spend Output
  output$dtc_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Total_DTC_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  output$dtc_spend_details <- renderUI({
    if (dtc_spend_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(HTML(paste0("<strong>Meta Spend:</strong> ", format(round(selected_data()$current$Meta_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Google Spend:</strong> ", format(round(selected_data()$current$Google_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Bing Spend:</strong> ", format(round(selected_data()$current$Bing_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>TikTok Spend:</strong> ", format(round(selected_data()$current$TikTok_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Nextdoor Spend:</strong> ", format(round(selected_data()$current$Nextdoor_Spend, 2), nsmall = 2, big.mark = ","), " $"))),
        div(HTML(paste0("<strong>Affiliate Fees:</strong> ", format(round(selected_data()$current$Affiliate_Fees, 2), nsmall = 2, big.mark = ","), " $")))
      )
    } else {
      NULL
    }
  })
  
  # Amazon Spend Output
  output$amazon_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Amazon_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  
  output$indiegogo_spend_output <- renderText({
    paste0(format(round(selected_data()$current$IndieGoGo_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  output$fees_output <- renderText({
    paste0(format(round(selected_data()$current$Fees, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  output$fees_details <- renderUI({
    if (fees_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 15px; border-radius: 10px; margin-top: 10px; width: 80%; margin-left: auto; margin-right: auto;",
        div(HTML(paste0("<strong>Rachio Fees:</strong> ", format(round(selected_data()$current$Rachio_Fees, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>Weatherflow Fees:</strong> ", format(round(selected_data()$current$Weatherflow_Fees, 2), nsmall = 2), " $")))
      )
    } else {
      NULL
    }
  })
  
  # Total App Spend Output
  output$total_app_spend_output <- renderText({
    paste0(format(round(selected_data()$current$Total_App_Spend, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Dynamically render the gray container with app spend details
  output$app_spend_details <- renderUI({
    if (app_spend_visible()) {
      div(
        style = "background-color: #d3d3d3; padding: 10px; border-radius: 10px; margin-top: 10px; width: 40%; margin-left: auto; margin-right: auto;",
        div(
          HTML(paste0("<strong>Meta App Spend:</strong> ", format(round(selected_data()$current$App_Spend_Meta, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Apple App Spend:</strong> ", format(round(selected_data()$current$App_Spend_Apple, 2), nsmall = 2, big.mark = ","), " $"))
        ),
        div(
          HTML(paste0("<strong>Google App Spend:</strong> ", format(round(selected_data()$current$App_Spend_Google, 2), nsmall = 2, big.mark = ","), " $"))
        )
      )
    } else {
      NULL
    }
  })
  
  
  
  # Populate date dropdown choices dynamically
  observe({
    updateSelectInput(session, "selected_date", choices = revenue_data$Date, selected = revenue_data$Date[1])
  })
  # Blended ROAS
  output$blended_roas_output <- renderText({
    paste0(format(round(selected_data()$current$Blended_ROAS, 2), nsmall = 2, big.mark = ","))
  })
  
  # Blended SPU
  output$blended_SPU_output <- renderText({
    paste0(format(round(selected_data()$current$Blended_SPU, 2), nsmall = 2, big.mark = ","), " $")
  })
  
  # Web CR
  output$web_cr_output <- renderText({
    paste0(format(round(selected_data()$current$Web_CR * 100, 2), nsmall = 2), " %")  # Assuming Web CR is a ratio
  })
  
  # Web AOV
  output$web_aov_output <- renderText({
    paste0(format(round(selected_data()$current$Web_AOV, 2), nsmall = 2, big.mark = ","), " $")
  })
  # ---- Reactive Value for Blended ROAS Visibility ----
  blended_roas_visible <- reactiveVal(FALSE)
  
  # Toggle visibility when the button is clicked
  observeEvent(input$toggle_blended_roas, {
    blended_roas_visible(!blended_roas_visible())
  })
  
  # Dynamically render the container with Blended ROAS details
  output$blended_roas_details <- renderUI({
    if (blended_roas_visible()) {
      div(
        style = "
        background-color: #ffffff;
        padding: 10px;
        border-radius: 10px;
        margin-top: 10px;
        text-align: center;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>wROAS:</strong> ", format(round(selected_data()$current$wROAS, 2), nsmall = 2)))),
        div(HTML(paste0("<strong>aROAS:</strong> ", format(round(selected_data()$current$aROAS, 2), nsmall = 2)))),
        div(HTML(paste0("<strong>appROAS:</strong> ", format(round(selected_data()$current$appROAS, 2), nsmall = 2))))
      )
    } else {
      NULL
    }
  })
  # ---- Reactive Value for Blended SPU Visibility ----
  # Reactive toggle for SPU details
  blended_SPU_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_blended_SPU, {
    blended_SPU_visible(!blended_SPU_visible())
  })
  output$blended_SPU_details <- renderUI({
    if (blended_SPU_visible()) {
      div(
        style = "
        background-color: #ffffff;
        padding: 10px;
        border-radius: 10px;
        margin-top: 10px;
        text-align: center;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>wSPU:</strong> ", format(round(selected_data()$current$wSPU, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>aSPU:</strong> ", format(round(selected_data()$current$aSPU, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>appSPU:</strong> ", format(round(selected_data()$current$appSPU, 2), nsmall = 2), " $")))
      )
    } else {
      NULL
    }
  })
  
  # ---- Reactive Value for Web AOV Visibility ----
  web_aov_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_web_aov, {
    web_aov_visible(!web_aov_visible())
  })
  
  output$web_aov_details <- renderUI({
    if (web_aov_visible()) {
      div(
        style = "
        background-color: #ffffff;
        padding: 10px;
        border-radius: 10px;
        margin-top: 10px;
        text-align: center;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>fAOV:</strong> ", format(round(selected_data()$current$fAOV, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>rAOV:</strong> ", format(round(selected_data()$current$rAOV, 2), nsmall = 2), " $")))
      )
    } else {
      NULL
    }
  })
  
  
  # Orders Outputs
  output$dtc_orders_output <- renderText({
    format(round(sum(selected_data()$current$DTC_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$amazon_orders_output <- renderText({
    format(round(sum(selected_data()$current$Amazon_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$digital_marketplaces_orders_output <- renderText({
    format(round(sum(selected_data()$current$Digital_Marketplaces_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$b2b_orders_output <- renderText({
    format(round(sum(selected_data()$current$B2B_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$app_orders_output <- renderText({
    format(round(sum(selected_data()$current$App_Orders, na.rm = TRUE), 0), big.mark = ",")
  })
  
  output$dtc_orders_details <- renderUI({
    if (dtc_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$DTC_Hardware_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$DTC_Addons_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Merch:</strong> ", format(round(selected_data()$current$DTC_Merch_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Seeds:</strong> ", format(round(selected_data()$current$DTC_Seeds_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Premium Subscriptions:</strong> ", format(round(selected_data()$current$DTC_Subscription_Units, 0), big.mark = ","), " units")))
      )
    } else {
      NULL
    }
  })
  
  output$amazon_orders_details <- renderUI({
    if (amazon_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Hardware:</strong> ", format(round(selected_data()$current$Amazon_Hardware_Units, 0), big.mark = ","), " units"))),
        div(HTML(paste0("<strong>Add-ons:</strong> ", format(round(selected_data()$current$Amazon_Addons_Units, 0), big.mark = ","), " units")))
      )
    } else {
      NULL
    }
  })
  
  output$digital_marketplaces_orders_details <- renderUI({
    if (digital_marketplaces_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Rachio Orders:</strong> ", format(round(selected_data()$current$Rachio_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Weatherflow Orders:</strong> ", format(round(selected_data()$current$Weatherflow_Orders, 0), big.mark = ","))))
      )
    } else {
      NULL
    }
  })
  
  output$b2b_orders_details <- renderUI({
    if (b2b_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Best Buy Orders:</strong> ", format(round(selected_data()$current$BestBuy_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Target Orders:</strong> ", format(round(selected_data()$current$Target_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Walmart Orders:</strong> ", format(round(selected_data()$current$Walmart_Orders, 0), big.mark = ","))))
      )
    } else {
      NULL
    }
  })
  
  output$app_orders_details <- renderUI({
    if (app_orders_visible()) {
      div(
        style = "
        background-color: #d3d3d3;
        padding: 15px;
        border-radius: 10px;
        margin-top: 10px;
        width: 80%;
        margin-left: auto;
        margin-right: auto;
        font-family: 'Montserrat', sans-serif;
        font-size: 14px;
        color: black;
      ",
        div(HTML(paste0("<strong>Google Store Orders:</strong> ", format(round(selected_data()$current$Google_Store_Orders, 0), big.mark = ",")))),
        div(HTML(paste0("<strong>Apple Store Orders:</strong> ", format(round(selected_data()$current$Apple_Store_Orders, 0), big.mark = ","))))
      )
    } else {
      NULL
    }
  })
  

  output$revenue_vs_spend_plot <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_revenue_spend_type)
    req(input$selected_view_mode)
    
    selected_type <- input$selected_revenue_spend_type
    view_mode     <- input$selected_view_mode
    gran <- if (isTRUE(input$viz_by_month)) "Month" else "Day"
    
    
    cols <- switch(
      selected_type,
      "Total"  = c("Total_Revenue", "Total_Spend"),
      "DTC"    = c("DTC_Revenue", "Total_DTC_Spend"),
      "Amazon" = c("Amazon_Revenue", "Amazon_Spend"),
      "App"    = c("App_Revenue", "Total_App_Spend"),
      "Retail"    = c("B2B_Revenue", NA)   # No spend for B2B
    )
    
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (is.na(cols[2])) {
      df <- df %>%
        select(Date, Revenue = all_of(cols[1])) %>%
        mutate(Spend = 0)
    } else {
      df <- df %>%
        select(Date, Revenue = all_of(cols[1]), Spend = all_of(cols[2]))
    }
    
    # ---- NEW: aggregate by Month when requested ----
    if (identical(gran, "Month")) {
      df <- df %>%
        mutate(Date = floor_date(Date, "month")) %>%
        group_by(Date) %>%
        summarise(
          Revenue = sum(Revenue, na.rm = TRUE),
          Spend   = sum(Spend,   na.rm = TRUE),
          .groups = "drop"
        )
    }
    
    # helpful axis formatting based on granularity
    x_breaks  <- if (identical(gran, "Month")) "1 month" else "5 days"
    x_labels  <- if (identical(gran, "Month")) "%b %Y"   else "%b %d"
    date_disp <- if (identical(gran, "Month")) "%Y-%m"   else "%Y-%m-%d"
    
    if (view_mode == "Absolute") {
      df_long <- df %>%
        tidyr::pivot_longer(
          cols = c(Revenue, Spend),
          names_to = "Metric",
          values_to = "Amount"
        ) %>%
        mutate(
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'><b>Date:</b> ", format(Date, date_disp), "<br>",
            "<b>", Metric, ":</b> $", format(round(Amount, 2), big.mark = ",", nsmall = 2),
            "</span>"
          )
        )
      
      p <- ggplot(df_long, aes(x = Date, y = Amount, color = Metric, group = Metric, text = Tooltip)) +
        geom_line(size = 1.2) +
        geom_point(size = 2) +
        scale_color_manual(values = c("Revenue" = "#2ecc71", "Spend" = "#A52A2A")) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = x_breaks, date_labels = x_labels) +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          legend.position = "none",
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 20, b = 60),
          yaxis = list(title = list(text = "")),
          xaxis = list(title = list(text = "")),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff"
        )
      
    } else {
      df_rel <- df %>%
        mutate(
          Total        = Revenue + Spend,
          Revenue_Perc = ifelse(Total == 0, 0, Revenue / Total),
          Spend_Perc   = ifelse(Total == 0, 0, Spend   / Total),
          Revenue_Label = paste0(
            "<b>", format(Date, if (identical(gran, "Month")) "%b %Y" else "%b %d, %Y"), "</b><br>",
            "<span style='color:#2ecc71;'>Revenue: $", format(round(Revenue, 2), big.mark = ","), 
            " (", round(Revenue_Perc * 100, 1), "%)</span>"
          ),
          Spend_Label = paste0(
            "<b>", format(Date, if (identical(gran, "Month")) "%b %Y" else "%b %d, %Y"), "</b><br>",
            "<span style='color:#A52A2A;'>Spend: $", format(round(Spend, 2), big.mark = ","), 
            " (", round(Spend_Perc * 100, 1), "%)</span>"
          )
        )
      
      plot_ly() %>%
        add_trace(
          data = df_rel,
          x = ~Date, y = ~Revenue_Perc,
          type = "scatter", mode = "none",
          name = "Revenue",
          stackgroup = "one",
          fillcolor = "rgba(46, 204, 113, 0.3)",
          line = list(color = "#2ecc71"),
          text = ~Revenue_Label,
          hoverinfo = "text"
        ) %>%
        add_trace(
          data = df_rel,
          x = ~Date, y = ~Spend_Perc,
          type = "scatter", mode = "none",
          name = "Spend",
          stackgroup = "one",
          fillcolor = "rgba(165, 42, 42, 0.3)",
          line = list(color = "#A52A2A"),
          text = ~Spend_Label,
          hoverinfo = "text"
        ) %>%
        layout(
          yaxis = list(title = "", tickformat = ".0%", tickfont = list(family = "Montserrat", size = 16),
                       showline = TRUE, showgrid = TRUE),
          xaxis = list(title = "", tickfont = list(family = "Montserrat", size = 16),
                       showline = TRUE, tickformat = if (identical(gran, "Month")) "%b %Y" else "%b %d"),
          hovermode = "x unified",
          showlegend = FALSE,
          margin = list(l = 40, r = 20, t = 20, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          font = list(family = "Montserrat")
        )
    }
  })
  
  
  
  output$blended_roas_bar_chart <- renderPlotly({
    req(input$selected_date_range, input$selected_roas_type)
    
    # zero/NA-safe division helper
    safe_div <- function(num, den) ifelse(is.na(den) | den == 0, NA, num / den)
    
    # base data with all ROAS pieces
    filtered_data <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::mutate(
        Date         = as.Date(Date),
        Blended_ROAS = ifelse(Total_Spend     == 0, NA, Total_Revenue   / Total_Spend),
        wROAS        = ifelse(Total_DTC_Spend == 0, NA, DTC_Revenue     / Total_DTC_Spend),
        aROAS        = ifelse(Amazon_Spend    == 0, NA, Amazon_Revenue  / Amazon_Spend),
        appROAS      = ifelse(Total_App_Spend == 0, NA, App_Revenue     / Total_App_Spend)
      )
    
    selected_metric <- input$selected_roas_type
    
    # map metric to numerator / denominator for correct monthly rollup
    num_col <- switch(selected_metric,
                      "Blended_ROAS" = "Total_Revenue",
                      "wROAS"        = "DTC_Revenue",
                      "aROAS"        = "Amazon_Revenue",
                      "appROAS"      = "App_Revenue")
    den_col <- switch(selected_metric,
                      "Blended_ROAS" = "Total_Spend",
                      "wROAS"        = "Total_DTC_Spend",
                      "aROAS"        = "Amazon_Spend",
                      "appROAS"      = "Total_App_Spend")
    
    # day-level data first
    plot_data <- filtered_data %>%
      dplyr::select(Date, ROAS = !!rlang::sym(selected_metric))
    
    # monthly aggregation (sum num/den then divide)
    if (isTRUE(input$viz_by_month)) {
      plot_data <- filtered_data %>%
        dplyr::transmute(
          Month = lubridate::floor_date(Date, "month"),
          Num   = !!rlang::sym(num_col),
          Den   = !!rlang::sym(den_col)
        ) %>%
        dplyr::group_by(Month) %>%
        dplyr::summarise(
          Num = sum(Num, na.rm = TRUE),
          Den = sum(Den, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::mutate(
          Date = Month,
          ROAS = safe_div(Num, Den)
        ) %>%
        dplyr::select(Date, ROAS)
    }
    
    # ----- make month view categorical so bars are wide and never overlap -----
    plot_data <- plot_data %>%
      dplyr::mutate(
        X          = if (isTRUE(input$viz_by_month))
          forcats::fct_inorder(format(Date, "%b %Y")) else Date,
        LabelDate  = if (isTRUE(input$viz_by_month))
          format(Date, "%b %Y") else format(Date, "%b %d, %Y"),
        Tooltip    = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", LabelDate, "<br>",
          "<b>", gsub("_", " ", selected_metric), ":</b> ", round(ROAS, 2),
          "</span>"
        )
      )
    
    # build ggplot (use discrete x in month view, continuous for daily)
    p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = X, y = ROAS, text = Tooltip)) +
      ggplot2::geom_col(fill = "#2ecc71", width = if (isTRUE(input$viz_by_month)) 0.85 else 0.6) +
      ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.1))) +
      {
        if (isTRUE(input$viz_by_month)) ggplot2::scale_x_discrete(drop = FALSE)
        else ggplot2::scale_x_date(date_breaks = "5 days", date_labels = "%b %d")
      } +
      ggplot2::labs(x = NULL, y = NULL) +
      ggplot2::theme_minimal(base_family = "Montserrat") +
      ggplot2::theme(
        plot.title       = ggplot2::element_blank(),
        axis.text.x      = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y      = ggplot2::element_text(size = 12),
        panel.border     = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
        panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
      )
    
    plotly::ggplotly(p, tooltip = "text") %>%
      plotly::layout(
        margin        = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  
  output$returning_customer_output <- renderText({
    paste0(format(round(selected_data()$current$Returning_Customer_Rate * 100, 2), nsmall = 2), " %")
  })
  
  

  
  
  output$revenue_share_chart <- renderPlotly({
    req(input$selected_date_range)
    view_mode <- input$selected_revenue_view_mode
    
    # base filtered data
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    # --- Optional monthly aggregation (sum first, then compute % later) ---
    if (isTRUE(input$viz_by_month)) {
      filtered_data <- filtered_data %>%
        mutate(Date = lubridate::floor_date(Date, "month")) %>%
        group_by(Date) %>%
        summarise(
          DTC_Revenue                    = sum(DTC_Revenue, na.rm = TRUE),
          Amazon_Revenue                 = sum(Amazon_Revenue, na.rm = TRUE),
          Digital_Marketplaces_Revenue   = sum(Digital_Marketplaces_Revenue, na.rm = TRUE),
          .groups = "drop"
        )
    }
    
    # helpers for x axis + tooltip date formats
    x_breaks <- if (isTRUE(input$viz_by_month)) "1 month" else "5 days"
    x_labels <- if (isTRUE(input$viz_by_month)) "%b %Y"   else "%b %d"
    tip_fmt  <- if (isTRUE(input$viz_by_month)) "%Y-%m"   else "%Y-%m-%d"
    
    if (view_mode == "Absolute") {
      # ----- ABSOLUTE MODE: LINE CHART -----
      df_long <- filtered_data %>%
        select(Date, DTC_Revenue, Amazon_Revenue, Digital_Marketplaces_Revenue) %>%
        tidyr::pivot_longer(cols = -Date, names_to = "Category", values_to = "Revenue") %>%
        mutate(
          Category = dplyr::recode(Category,
                                   DTC_Revenue = "DTC",
                                   Amazon_Revenue = "Amazon",
                                   Digital_Marketplaces_Revenue = "Digital Marketplaces"
          ),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, tip_fmt), "<br>",
            "<b>", Category, ":</b> $", format(round(Revenue, 2), big.mark = ","),
            "</span>"
          )
        )
      
      p <- ggplot(df_long, aes(x = Date, y = Revenue, color = Category, group = Category, text = Tooltip)) +
        geom_line(size = 1.2) +
        geom_point(size = 2) +
        scale_color_manual(values = c("DTC" = "#2ecc71", "Amazon" = "#3498db", "Digital Marketplaces" = "#f39c12")) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = x_breaks, date_labels = x_labels) +
        labs(x = NULL, y = NULL) +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          legend.title = element_blank(),
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 60, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          legend = list(
            orientation = "h",
            x = 0.5, y = 1.15, xanchor = "center",
            font = list(family = "Montserrat", size = 14),
            title = list(text = NULL)
          ),
          font = list(family = "Montserrat")
        )
      
    } else {
      # ----- RELATIVE MODE: STACKED PERCENT AREA -----
      rel <- filtered_data %>%
        mutate(
          Total = DTC_Revenue + Amazon_Revenue + Digital_Marketplaces_Revenue,
          DTC_Perc = ifelse(Total == 0, 0, DTC_Revenue / Total),
          Amazon_Perc = ifelse(Total == 0, 0, Amazon_Revenue / Total),
          DM_Perc = ifelse(Total == 0, 0, Digital_Marketplaces_Revenue / Total),
          
          DTC_Label = paste0("<b>", format(Date, if (isTRUE(input$viz_by_month)) "%b %Y" else "%b %d, %Y"),
                             "</b><br><span style='color:#2ecc71;'>DTC Revenue: $",
                             format(round(DTC_Revenue, 2), big.mark = ","), " (", round(DTC_Perc * 100, 1), "%)</span>"),
          Amazon_Label = paste0("<b>", format(Date, if (isTRUE(input$viz_by_month)) "%b %Y" else "%b %d, %Y"),
                                "</b><br><span style='color:#3498db;'>Amazon Revenue: $",
                                format(round(Amazon_Revenue, 2), big.mark = ","), " (", round(Amazon_Perc * 100, 1), "%)</span>"),
          DM_Label = paste0("<b>", format(Date, if (isTRUE(input$viz_by_month)) "%b %Y" else "%b %d, %Y"),
                            "</b><br><span style='color:#f39c12;'>Digital Marketplaces Revenue: $",
                            format(round(Digital_Marketplaces_Revenue, 2), big.mark = ","), " (", round(DM_Perc * 100, 1), "%)</span>")
        )
      
      plot_ly() %>%
        add_trace(
          data = rel, x = ~Date, y = ~DTC_Perc,
          type = "scatter", mode = "none", name = "DTC",
          stackgroup = "one",
          fillcolor = "rgba(46, 204, 113, 0.3)",
          line = list(color = "#2ecc71"),
          text = ~DTC_Label, hoverinfo = "text"
        ) %>%
        add_trace(
          data = rel, x = ~Date, y = ~Amazon_Perc,
          type = "scatter", mode = "none", name = "Amazon",
          stackgroup = "one",
          fillcolor = "rgba(52, 152, 219, 0.3)",
          line = list(color = "#3498db"),
          text = ~Amazon_Label, hoverinfo = "text"
        ) %>%
        add_trace(
          data = rel, x = ~Date, y = ~DM_Perc,
          type = "scatter", mode = "none", name = "Digital Marketplaces",
          stackgroup = "one",
          fillcolor = "rgba(243, 156, 18, 0.3)",
          line = list(color = "#f39c12"),
          text = ~DM_Label, hoverinfo = "text"
        ) %>%
        layout(
          yaxis = list(title = list(text = ""), tickformat = ".0%", tickfont = list(family = "Montserrat", size = 16)),
          xaxis = list(
            title = list(text = ""),
            tickfont = list(family = "Montserrat", size = 16),
            tickformat = if (isTRUE(input$viz_by_month)) "%b %Y" else "%b %d"
          ),
          hovermode = "x unified",
          showlegend = TRUE,
          legend = list(orientation = "h", x = 0.5, y = 1.15, xanchor = "center", font = list(family = "Montserrat", size = 14)),
          margin = list(l = 40, r = 20, t = 60, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff",
          font = list(family = "Montserrat")
        )
    }
  })
  
  
  
  output$spend_composition_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_spend_composition)
    req(input$selected_spend_view_mode)
    
    view_mode  <- input$selected_spend_view_mode
    spend_type <- input$selected_spend_composition
    by_month   <- isTRUE(input$viz_by_month)
    
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1], Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    # axis / tooltip formats per granularity
    x_breaks <- if (by_month) "1 month" else "5 days"
    x_labels <- if (by_month) "%b %Y"   else "%b %d"
    tip_fmt  <- if (by_month) "%Y-%m"   else "%Y-%m-%d"
    
    if (view_mode == "Absolute") {
      if (spend_type == "Total") {
        # start from wide table of spend categories
        data_abs <- df %>%
          select(Date,
                 DTC   = Total_DTC_Spend,
                 Amazon = Amazon_Spend,
                 App    = Total_App_Spend,
                 Fees)
        
        # MONTHLY: sum numeric columns after grouping (avoids tidyselect Date error)
        if (by_month) {
          data_abs <- data_abs %>%
            mutate(Date = lubridate::floor_date(Date, "month")) %>%
            group_by(Date) %>%
            summarise(
              dplyr::across(where(is.numeric), ~ sum(.x, na.rm = TRUE)),
              .groups = "drop"
            )
        }
        
        df_long <- data_abs %>%
          tidyr::pivot_longer(-Date, names_to = "Category", values_to = "Spend") %>%
          mutate(
            Tooltip = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", format(Date, tip_fmt), "<br>",
              "<b>", Category, ":</b> $", format(round(Spend, 2), big.mark = ","),
              "</span>"
            )
          )
        
        p <- ggplot(df_long, aes(x = Date, y = Spend, color = Category, group = Category, text = Tooltip)) +
          geom_line(size = 1.2) +
          geom_point(size = 2) +
          scale_color_manual(values = c("DTC" = "#A52A2A", "Amazon" = "#f39c12", "App" = "#9b59b6", "Fees" = "#34495e")) +
          scale_y_continuous(labels = scales::label_dollar()) +
          scale_x_date(date_breaks = x_breaks, date_labels = x_labels) +
          labs(x = NULL, y = NULL) +
          theme_minimal(base_family = "Montserrat") +
          theme(
            axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y = element_text(size = 12),
            legend.title = element_blank(),
            panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = element_rect(fill = "#ffffff", color = NA),
            panel.background = element_rect(fill = "#ffffff", color = NA)
          )
        
        return(
          ggplotly(p, tooltip = "text") %>%
            layout(
              margin = list(l = 40, r = 20, t = 60, b = 60),
              plot_bgcolor = "#ffffff",
              paper_bgcolor = "#ffffff",
              legend = list(
                orientation = "h",
                x = 0.5, y = 1.15, xanchor = "center",
                font = list(family = "Montserrat", size = 14),
                title = list(text = NULL)
              ),
              font = list(family = "Montserrat")
            )
        )
        
      } else if (spend_type == "DTC") {
        data_abs <- df %>%
          select(Date,
                 Meta      = Meta_Spend,
                 Google    = Google_Spend,
                 Bing      = Bing_Spend,
                 TikTok    = TikTok_Spend,
                 Nextdoor  = Nextdoor_Spend,
                 Affiliate = Affiliate_Fees)
        
        if (by_month) {
          data_abs <- data_abs %>%
            mutate(Date = lubridate::floor_date(Date, "month")) %>%
            group_by(Date) %>%
            summarise(
              dplyr::across(where(is.numeric), ~ sum(.x, na.rm = TRUE)),
              .groups = "drop"
            )
        }
        
        df_long <- data_abs %>%
          tidyr::pivot_longer(-Date, names_to = "Channel", values_to = "Spend") %>%
          mutate(
            Tooltip = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", format(Date, tip_fmt), "<br>",
              "<b>", Channel, ":</b> $", format(round(Spend, 2), big.mark = ","),
              "</span>"
            )
          )
        
        p <- ggplot(df_long, aes(x = Date, y = Spend, color = Channel, group = Channel, text = Tooltip)) +
          geom_line(size = 1.2) +
          geom_point(size = 2) +
          scale_color_manual(values = c(
            "Meta" = "#2ecc71", "Google" = "#3498db", "Bing" = "#9b59b6",
            "TikTok" = "#e74c3c", "Nextdoor" = "#f1c40f", "Affiliate" = "#34495e"
          )) +
          scale_y_continuous(labels = scales::label_dollar()) +
          scale_x_date(date_breaks = x_breaks, date_labels = x_labels) +
          labs(x = NULL, y = NULL) +
          theme_minimal(base_family = "Montserrat") +
          theme(
            axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y = element_text(size = 12),
            legend.title = element_blank(),
            panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = element_rect(fill = "#ffffff", color = NA),
            panel.background = element_rect(fill = "#ffffff", color = NA)
          )
        
        return(
          ggplotly(p, tooltip = "text") %>%
            layout(
              margin = list(l = 40, r = 20, t = 60, b = 60),
              plot_bgcolor = "#ffffff",
              paper_bgcolor = "#ffffff",
              legend = list(
                orientation = "h",
                x = 0.5, y = 1.15, xanchor = "center",
                font = list(family = "Montserrat", size = 14),
                title = list(text = NULL)
              ),
              font = list(family = "Montserrat")
            )
        )
      }
      
    } else {
      # ---------------- RELATIVE MODE (now supports By month) ----------------
      by_month <- isTRUE(input$viz_by_month)
      x_breaks <- if (by_month) "1 month" else "5 days"
      x_labels <- if (by_month) "%b %Y"   else "%b %d"
      tip_date_fmt <- if (by_month) "%b %Y" else "%b %d, %Y"
      
      if (spend_type == "Total") {
        data_rel <- df %>%
          dplyr::select(
            Date,
            Total_Spend, Total_DTC_Spend, Amazon_Spend, Total_App_Spend, Fees
          )
        
        if (by_month) {
          data_rel <- data_rel %>%
            dplyr::mutate(Date = lubridate::floor_date(Date, "month")) %>%
            dplyr::group_by(Date) %>%
            dplyr::summarise(
              Total_Spend     = sum(Total_Spend,     na.rm = TRUE),
              Total_DTC_Spend = sum(Total_DTC_Spend, na.rm = TRUE),
              Amazon_Spend    = sum(Amazon_Spend,    na.rm = TRUE),
              Total_App_Spend = sum(Total_App_Spend, na.rm = TRUE),
              Fees            = sum(Fees,            na.rm = TRUE),
              .groups = "drop"
            )
        }
        
        df_rel <- data_rel %>%
          dplyr::filter(!is.na(Total_Spend) & Total_Spend > 0) %>%
          dplyr::mutate(
            DTC_Perc    = Total_DTC_Spend / Total_Spend,
            Amazon_Perc = Amazon_Spend    / Total_Spend,
            App_Perc    = Total_App_Spend / Total_Spend,
            Fees_Perc   = Fees            / Total_Spend
          ) %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            Total_Percent = sum(c_across(ends_with("_Perc")), na.rm = TRUE),
            Scale_Factor  = ifelse(Total_Percent > 1, 1 / Total_Percent, 1),
            DTC_Perc      = DTC_Perc    * Scale_Factor,
            Amazon_Perc   = Amazon_Perc * Scale_Factor,
            App_Perc      = App_Perc    * Scale_Factor,
            Fees_Perc     = Fees_Perc   * Scale_Factor
          ) %>%
          dplyr::ungroup() %>%
          dplyr::mutate(
            DTC_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br>",
                               "<span style='color:#A52A2A;'>DTC Spend:</span> $",
                               format(round(Total_DTC_Spend, 2), big.mark = ","), " (", round(DTC_Perc * 100, 1), "%)"),
            Amazon_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br>",
                                  "<span style='color:#f39c12;'>Amazon Spend:</span> $",
                                  format(round(Amazon_Spend, 2), big.mark = ","), " (", round(Amazon_Perc * 100, 1), "%)"),
            App_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br>",
                               "<span style='color:#9b59b6;'>App Spend:</span> $",
                               format(round(Total_App_Spend, 2), big.mark = ","), " (", round(App_Perc * 100, 1), "%)"),
            Fees_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br>",
                                "<span style='color:#34495e;'>Fees:</span> $",
                                format(round(Fees, 2), big.mark = ","), " (", round(Fees_Perc * 100, 1), "%)")
          )
        
        return(
          plot_ly() %>%
            add_trace(data = df_rel, x = ~Date, y = ~DTC_Perc, type = "scatter", mode = "none", name = "DTC Spend",
                      stackgroup = "one", fillcolor = "rgba(165, 42, 42, 0.3)", line = list(color = "#A52A2A"),
                      text = ~DTC_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~Amazon_Perc, type = "scatter", mode = "none", name = "Amazon Spend",
                      stackgroup = "one", fillcolor = "rgba(243, 156, 18, 0.3)", line = list(color = "#f39c12"),
                      text = ~Amazon_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~App_Perc, type = "scatter", mode = "none", name = "App Spend",
                      stackgroup = "one", fillcolor = "rgba(155, 89, 182, 0.3)", line = list(color = "#9b59b6"),
                      text = ~App_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~Fees_Perc, type = "scatter", mode = "none", name = "Fees",
                      stackgroup = "one", fillcolor = "rgba(52, 73, 94, 0.3)", line = list(color = "#34495e"),
                      text = ~Fees_Label, hoverinfo = "text") %>%
            layout(
              yaxis = list(title = list(text = ""), tickformat = ".0%", tickfont = list(family = "Montserrat", size = 14)),
              xaxis = list(title = list(text = ""), tickfont = list(family = "Montserrat", size = 14),
                           tickformat = if (by_month) "%b %Y" else "%b %d"),
              hovermode = "x unified",
              showlegend = TRUE,
              legend = list(orientation = "h", x = 0.5, y = 1.1, xanchor = "center",
                            font = list(family = "Montserrat", size = 14)),
              margin = list(l = 40, r = 20, t = 60, b = 60),
              plot_bgcolor = "#ffffff",
              paper_bgcolor = "#ffffff",
              font = list(family = "Montserrat")
            )
        )
        
      } else if (spend_type == "DTC") {
        data_rel <- df %>%
          dplyr::select(
            Date, Total_DTC_Spend, Meta_Spend, Google_Spend, Bing_Spend, TikTok_Spend, Nextdoor_Spend, Affiliate_Fees
          )
        
        if (by_month) {
          data_rel <- data_rel %>%
            dplyr::mutate(Date = lubridate::floor_date(Date, "month")) %>%
            dplyr::group_by(Date) %>%
            dplyr::summarise(
              Total_DTC_Spend = sum(Total_DTC_Spend, na.rm = TRUE),
              Meta_Spend      = sum(Meta_Spend,      na.rm = TRUE),
              Google_Spend    = sum(Google_Spend,    na.rm = TRUE),
              Bing_Spend      = sum(Bing_Spend,      na.rm = TRUE),
              TikTok_Spend    = sum(TikTok_Spend,    na.rm = TRUE),
              Nextdoor_Spend  = sum(Nextdoor_Spend,  na.rm = TRUE),
              Affiliate_Fees  = sum(Affiliate_Fees,  na.rm = TRUE),
              .groups = "drop"
            )
        }
        
        df_rel <- data_rel %>%
          dplyr::filter(!is.na(Total_DTC_Spend) & Total_DTC_Spend > 0) %>%
          dplyr::mutate(
            Meta_Perc      = Meta_Spend      / Total_DTC_Spend,
            Google_Perc    = Google_Spend    / Total_DTC_Spend,
            Bing_Perc      = Bing_Spend      / Total_DTC_Spend,
            TikTok_Perc    = TikTok_Spend    / Total_DTC_Spend,
            Nextdoor_Perc  = Nextdoor_Spend  / Total_DTC_Spend,
            Affiliate_Perc = Affiliate_Fees  / Total_DTC_Spend
          ) %>%
          dplyr::rowwise() %>%
          dplyr::mutate(
            Total_Percent = sum(c_across(ends_with("_Perc")), na.rm = TRUE),
            Scale_Factor  = ifelse(Total_Percent > 1, 1 / Total_Percent, 1),
            Meta_Perc      = Meta_Perc      * Scale_Factor,
            Google_Perc    = Google_Perc    * Scale_Factor,
            Bing_Perc      = Bing_Perc      * Scale_Factor,
            TikTok_Perc    = TikTok_Perc    * Scale_Factor,
            Nextdoor_Perc  = Nextdoor_Perc  * Scale_Factor,
            Affiliate_Perc = Affiliate_Perc * Scale_Factor
          ) %>%
          dplyr::ungroup() %>%
          dplyr::mutate(
            Meta_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br><span style='color:#2ecc71;'>Meta Spend:</span> $",
                                format(round(Meta_Spend, 2), big.mark = ","), " (", round(Meta_Perc * 100, 1), "%)"),
            Google_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br><span style='color:#3498db;'>Google Spend:</span> $",
                                  format(round(Google_Spend, 2), big.mark = ","), " (", round(Google_Perc * 100, 1), "%)"),
            Bing_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br><span style='color:#9b59b6;'>Bing Spend:</span> $",
                                format(round(Bing_Spend, 2), big.mark = ","), " (", round(Bing_Perc * 100, 1), "%)"),
            TikTok_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br><span style='color:#e74c3c;'>TikTok Spend:</span> $",
                                  format(round(TikTok_Spend, 2), big.mark = ","), " (", round(TikTok_Perc * 100, 1), "%)"),
            Nextdoor_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br><span style='color:#f1c40f;'>Nextdoor Spend:</span> $",
                                    format(round(Nextdoor_Spend, 2), big.mark = ","), " (", round(Nextdoor_Perc * 100, 1), "%)"),
            Affiliate_Label = paste0("<b>", format(Date, tip_date_fmt), "</b><br><span style='color:#34495e;'>Affiliate Fees:</span> $",
                                     format(round(Affiliate_Fees, 2), big.mark = ","), " (", round(Affiliate_Perc * 100, 1), "%)")
          )
        
        return(
          plot_ly() %>%
            add_trace(data = df_rel, x = ~Date, y = ~Meta_Perc, type = "scatter", mode = "none", name = "Meta Spend",
                      stackgroup = "one", fillcolor = "rgba(46, 204, 113, 0.3)", line = list(color = "#2ecc71"),
                      text = ~Meta_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~Google_Perc, type = "scatter", mode = "none", name = "Google Spend",
                      stackgroup = "one", fillcolor = "rgba(52, 152, 219, 0.3)", line = list(color = "#3498db"),
                      text = ~Google_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~Bing_Perc, type = "scatter", mode = "none", name = "Bing Spend",
                      stackgroup = "one", fillcolor = "rgba(155, 89, 182, 0.3)", line = list(color = "#9b59b6"),
                      text = ~Bing_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~TikTok_Perc, type = "scatter", mode = "none", name = "TikTok Spend",
                      stackgroup = "one", fillcolor = "rgba(231, 76, 60, 0.3)", line = list(color = "#e74c3c"),
                      text = ~TikTok_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~Nextdoor_Perc, type = "scatter", mode = "none", name = "Nextdoor Spend",
                      stackgroup = "one", fillcolor = "rgba(241, 196, 15, 0.3)", line = list(color = "#f1c40f"),
                      text = ~Nextdoor_Label, hoverinfo = "text") %>%
            add_trace(data = df_rel, x = ~Date, y = ~Affiliate_Perc, type = "scatter", mode = "none", name = "Affiliate Fees",
                      stackgroup = "one", fillcolor = "rgba(52, 73, 94, 0.3)", line = list(color = "#34495e"),
                      text = ~Affiliate_Label, hoverinfo = "text") %>%
            layout(
              yaxis = list(title = list(text = ""), tickformat = ".0%", tickfont = list(family = "Montserrat", size = 14)),
              xaxis = list(title = list(text = ""), tickfont = list(family = "Montserrat", size = 14),
                           tickformat = if (by_month) "%b %Y" else "%b %d"),
              hovermode = "x unified",
              showlegend = TRUE,
              legend = list(orientation = "h", x = 0.5, y = 1.1, xanchor = "center",
                            font = list(family = "Montserrat", size = 14)),
              margin = list(l = 40, r = 20, t = 60, b = 60),
              plot_bgcolor = "#ffffff",
              paper_bgcolor = "#ffffff",
              font = list(family = "Montserrat")
            )
        )
      }
    }
    
  })
  
  
  output$blended_SPU_bar_chart <- renderPlotly({
    req(input$selected_date_range, input$selected_SPU_type)
    
    by_month        <- isTRUE(input$viz_by_month)
    selected_metric <- input$selected_SPU_type
    
    # zero/NA-safe division helper
    safe_div <- function(num, den) ifelse(is.na(den) | den == 0, NA_real_, num / den)
    
    # pick the DM hardware-units column if it exists (fallback = none/0)
    dm_hw_col <- intersect(
      c("Digital_Marketplaces_Hardware_Units", "Digital_Hardware_Units", "DM_Hardware_Units"),
      names(revenue_data)
    )[1] %||% NA_character_
    
    filtered_data <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::mutate(
        Date       = as.Date(Date),
        DTC_HW     = dplyr::coalesce(DTC_Hardware_Units, 0),
        Amazon_HW  = dplyr::coalesce(Amazon_Hardware_Units, 0),
        DM_HW      = if (!is.na(dm_hw_col)) dplyr::coalesce(.data[[dm_hw_col]], 0) else 0,
        Blended_HW = DTC_HW + Amazon_HW + DM_HW
      )
    
    # ---------- Build plot_data (daily vs monthly) ----------
    if (!by_month) {
      # Daily SPU (Spend / Units per row)
      plot_data <- filtered_data %>%
        dplyr::mutate(
          Blended_SPU = safe_div(Total_Spend,     Blended_HW),
          wSPU        = safe_div(Total_DTC_Spend, DTC_HW),
          aSPU        = safe_div(Amazon_Spend,    Amazon_HW),
          appSPU      = safe_div(Total_App_Spend, App_Orders)
        ) %>%
        dplyr::select(Date, Blended_SPU, wSPU, aSPU, appSPU) %>%
        dplyr::select(Date, SPU = dplyr::all_of(selected_metric))
      
      tip_fmt  <- "%b %d, %Y"
      x_breaks <- "5 days"
      x_labels <- "%b %d"
      
    } else {
      # Monthly: aggregate numerators & denominators first, then divide
      monthly <- filtered_data %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month) %>%
        dplyr::summarise(
          # numerators
          Total_Spend     = sum(Total_Spend,     na.rm = TRUE),
          Total_DTC_Spend = sum(Total_DTC_Spend, na.rm = TRUE),
          Amazon_Spend    = sum(Amazon_Spend,    na.rm = TRUE),
          Total_App_Spend = sum(Total_App_Spend, na.rm = TRUE),
          # denominators
          Blended_HW      = sum(Blended_HW,      na.rm = TRUE),
          DTC_HW          = sum(DTC_HW,          na.rm = TRUE),
          Amazon_HW       = sum(Amazon_HW,       na.rm = TRUE),
          App_Orders      = sum(App_Orders,      na.rm = TRUE),
          .groups = "drop"
        ) %>%
        dplyr::mutate(
          Date        = Month,
          Blended_SPU = safe_div(Total_Spend,     Blended_HW),
          wSPU        = safe_div(Total_DTC_Spend, DTC_HW),
          aSPU        = safe_div(Amazon_Spend,    Amazon_HW),
          appSPU      = safe_div(Total_App_Spend, App_Orders)
        ) %>%
        dplyr::select(Date, Blended_SPU, wSPU, aSPU, appSPU)
      
      plot_data <- monthly %>%
        dplyr::select(Date, SPU = dplyr::all_of(selected_metric))
      
      tip_fmt  <- "%b %Y"
      # (we’ll switch to a categorical x for month view; no date breaks needed)
    }
    
    # ----- make month view categorical so bars are wide and never overlap -----
    plot_data <- plot_data %>%
      dplyr::mutate(
        X         = if (by_month) forcats::fct_inorder(format(Date, "%b %Y")) else Date,
        LabelDate = if (by_month) format(Date, "%b %Y") else format(Date, "%b %d, %Y"),
        Tooltip   = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", LabelDate, "<br>",
          "<b>", gsub("_", " ", selected_metric), ":</b> $", sprintf("%.2f", SPU),
          "</span>"
        )
      )
    
    p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = X, y = SPU, text = Tooltip)) +
      ggplot2::geom_col(fill = "#A52A2A", width = if (by_month) 0.85 else 0.6) +
      ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.1))) +
      {
        if (by_month) ggplot2::scale_x_discrete(drop = FALSE)
        else ggplot2::scale_x_date(date_breaks = x_breaks, date_labels = x_labels)
      } +
      ggplot2::labs(x = NULL, y = NULL) +
      ggplot2::theme_minimal(base_family = "Montserrat") +
      ggplot2::theme(
        plot.title       = ggplot2::element_blank(),
        axis.text.x      = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y      = ggplot2::element_text(size = 12),
        panel.border     = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
        panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
      )
    
    plotly::ggplotly(p, tooltip = "text") %>%
      plotly::layout(
        margin        = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  
  
  
  output$cr_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    
    by_month   <- isTRUE(input$viz_by_month)
    has_orders <- "DTC_Orders" %in% names(revenue_data)
    
    # safe weighted mean (returns NA if total weight is 0 or NA)
    wmean_safe <- function(x, w) {
      w <- ifelse(is.na(w), 0, w)
      num <- sum(x * w, na.rm = TRUE)
      den <- sum(w, na.rm = TRUE)
      if (den == 0) NA_real_ else num / den
    }
    
    filtered_data <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::mutate(Date = as.Date(Date))
    
    if (!by_month) {
      # ---- Daily view ----
      plot_data <- filtered_data %>%
        dplyr::select(Date, Web_CR) %>%
        dplyr::mutate(CR_Percent = Web_CR * 100)
      
      x_breaks <- "5 days"
      x_labels <- "%b %d"
      
    } else {
      # ---- Monthly view (weighted by DTC_Orders when available) ----
      if (has_orders) {
        plot_data <- filtered_data %>%
          dplyr::mutate(Month = lubridate::floor_date(Date, "month"),
                        Orders = dplyr::coalesce(DTC_Orders, 0)) %>%
          dplyr::group_by(Month) %>%
          dplyr::summarise(CR = wmean_safe(Web_CR, Orders), .groups = "drop") %>%
          dplyr::mutate(Date = Month,
                        CR_Percent = CR * 100) %>%
          dplyr::select(Date, CR_Percent)
      } else {
        plot_data <- filtered_data %>%
          dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
          dplyr::group_by(Month) %>%
          dplyr::summarise(CR = mean(Web_CR, na.rm = TRUE), .groups = "drop") %>%
          dplyr::mutate(Date = Month,
                        CR_Percent = CR * 100) %>%
          dplyr::select(Date, CR_Percent)
      }
      # (we’ll use a categorical x for month view; no date breaks needed)
    }
    
    # ----- Make month view categorical so bars are wide and never thin -----
    plot_data <- plot_data %>%
      dplyr::mutate(
        X         = if (by_month) forcats::fct_inorder(format(Date, "%b %Y")) else Date,
        LabelDate = if (by_month) format(Date, "%b %Y") else format(Date, "%b %d, %Y"),
        Tooltip   = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", LabelDate, "<br>",
          "<b>Conversion Rate:</b> ", round(CR_Percent, 2), " %",
          "</span>"
        )
      )
    
    p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = X, y = CR_Percent, text = Tooltip)) +
      ggplot2::geom_col(fill = "#7b868c", width = if (by_month) 0.85 else 0.6) +
      ggplot2::scale_y_continuous(
        labels = function(x) paste0(x, "%"),
        expand = ggplot2::expansion(mult = c(0, 0.1))
      ) +
      {
        if (by_month) ggplot2::scale_x_discrete(drop = FALSE)
        else ggplot2::scale_x_date(date_breaks = x_breaks, date_labels = x_labels)
      } +
      ggplot2::labs(x = NULL, y = NULL) +
      ggplot2::theme_minimal(base_family = "Montserrat") +
      ggplot2::theme(
        axis.text.x      = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y      = ggplot2::element_text(size = 12),
        panel.border     = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
        panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
      )
    
    plotly::ggplotly(p, tooltip = "text") %>%
      plotly::layout(
        margin        = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff",
        yaxis         = list(title = list(text = "")),
        xaxis         = list(title = list(text = ""))
      )
  })
  
  
  
  # make sure you have: library(forcats)
  
  output$aov_bar_chart <- renderPlotly({
    req(input$selected_date_range, input$selected_aov_type)
    
    by_month <- isTRUE(input$viz_by_month)
    
    # safe weighted mean (NA if total weight == 0)
    wmean_safe <- function(x, w) {
      w <- ifelse(is.na(w), 0, w)
      num <- sum(x * w, na.rm = TRUE)
      den <- sum(w, na.rm = TRUE)
      if (den == 0) NA_real_ else num / den
    }
    
    filtered_data <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::mutate(Date = as.Date(Date))
    
    # axis + tooltip formats
    x_breaks <- if (by_month) "1 month" else "5 days"
    x_labels <- if (by_month) "%b %Y"   else "%b %d"
    tip_fmt  <- if (by_month) "%b %Y"   else "%b %d, %Y"
    
    if (input$selected_aov_type == "Segmented_AOV") {
      # try to use per-segment order counts if available, else fallback to DTC_Orders
      has_first_orders     <- "First_Orders"     %in% names(filtered_data)
      has_returning_orders <- "Returning_Orders" %in% names(filtered_data)
      has_total_orders     <- "DTC_Orders"       %in% names(filtered_data)
      
      if (!by_month) {
        plot_data <- filtered_data %>%
          dplyr::select(Date, fAOV, rAOV) %>%
          tidyr::pivot_longer(c(fAOV, rAOV), names_to = "Segment", values_to = "AOV") %>%
          dplyr::mutate(
            Segment   = dplyr::recode(Segment, fAOV = "First-Time", rAOV = "Returning"),
            LabelDate = format(Date, tip_fmt),
            Tooltip   = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", LabelDate, "<br>",
              "<b>", Segment, " AOV:</b> $", round(AOV, 2),
              "</span>"
            ),
            X = Date # continuous for daily
          )
      } else {
        monthly <- filtered_data %>%
          dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
          dplyr::group_by(Month) %>%
          dplyr::summarise(
            fAOV = wmean_safe(
              fAOV,
              if (has_first_orders) dplyr::coalesce(First_Orders, 0)
              else if (has_total_orders) dplyr::coalesce(DTC_Orders, 0)
              else 1
            ),
            rAOV = wmean_safe(
              rAOV,
              if (has_returning_orders) dplyr::coalesce(Returning_Orders, 0)
              else if (has_total_orders) dplyr::coalesce(DTC_Orders, 0)
              else 1
            ),
            .groups = "drop"
          ) %>%
          dplyr::rename(Date = Month)
        
        plot_data <- monthly %>%
          tidyr::pivot_longer(c(fAOV, rAOV), names_to = "Segment", values_to = "AOV") %>%
          dplyr::mutate(
            Segment   = dplyr::recode(Segment, fAOV = "First-Time", rAOV = "Returning"),
            LabelDate = format(Date, tip_fmt),
            Tooltip   = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", LabelDate, "<br>",
              "<b>", Segment, " AOV:</b> $", round(AOV, 2),
              "</span>"
            ),
            # >>> categorical month axis for wide bars <<<
            X = forcats::fct_inorder(format(Date, "%b %Y"))
          )
      }
      
      # use X aesthetic (Date for daily, factor for month)
      p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = X, y = AOV, fill = Segment, text = Tooltip)) +
        ggplot2::geom_bar(stat = "identity",
                          position = ggplot2::position_dodge2(width = 0.9, preserve = "single"),
                          width = if (by_month) 0.85 else 0.6) +
        ggplot2::scale_y_continuous(labels = scales::label_dollar()) +
        {
          if (by_month) ggplot2::scale_x_discrete(drop = FALSE)
          else ggplot2::scale_x_date(date_breaks = x_breaks, date_labels = x_labels)
        } +
        ggplot2::scale_fill_manual(values = c("First-Time" = "#3498db", "Returning" = "#2ecc71")) +
        ggplot2::labs(x = NULL, y = NULL) +
        ggplot2::theme_minimal(base_family = "Montserrat") +
        ggplot2::theme(
          axis.text.x      = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y      = ggplot2::element_text(size = 12),
          legend.title     = ggplot2::element_blank(),
          panel.border     = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
          panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
        )
      
      plotly::ggplotly(p, tooltip = "text") %>%
        plotly::layout(
          margin        = list(l = 40, r = 20, t = 60, b = 60),
          plot_bgcolor  = "#ffffff",
          paper_bgcolor = "#ffffff",
          legend        = list(
            orientation = "h",
            x = 0.5, y = 1.15, xanchor = "center",
            font = list(family = "Montserrat", size = 14),
            title = list(text = NULL)
          ),
          font          = list(family = "Montserrat")
        )
      
    } else {
      # Single AOV metric (e.g., Web_AOV)
      selected_metric <- input$selected_aov_type
      
      if (!by_month) {
        plot_data <- filtered_data %>%
          dplyr::select(Date, AOV = !!rlang::sym(selected_metric)) %>%
          dplyr::mutate(
            LabelDate = format(Date, tip_fmt),
            Tooltip   = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", LabelDate, "<br>",
              "<b>", gsub("_", " ", selected_metric), ":</b> $", round(AOV, 2),
              "</span>"
            ),
            X = Date
          )
      } else {
        has_total_orders <- "DTC_Orders" %in% names(filtered_data)
        monthly <- filtered_data %>%
          dplyr::mutate(
            Month  = lubridate::floor_date(Date, "month"),
            Orders = if (has_total_orders) dplyr::coalesce(DTC_Orders, 0) else 1
          ) %>%
          dplyr::group_by(Month) %>%
          dplyr::summarise(
            AOV = wmean_safe(!!rlang::sym(selected_metric), Orders),
            .groups = "drop"
          ) %>%
          dplyr::rename(Date = Month)
        
        plot_data <- monthly %>%
          dplyr::mutate(
            LabelDate = format(Date, tip_fmt),
            Tooltip   = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", LabelDate, "<br>",
              "<b>", gsub("_", " ", selected_metric), ":</b> $", round(AOV, 2),
              "</span>"
            ),
            # >>> categorical month axis for wide bars <<<
            X = forcats::fct_inorder(format(Date, "%b %Y"))
          )
      }
      
      p <- ggplot2::ggplot(plot_data, ggplot2::aes(x = X, y = AOV, text = Tooltip)) +
        ggplot2::geom_col(fill = "#3498db", width = if (by_month) 0.85 else 0.6) +
        ggplot2::scale_y_continuous(labels = scales::label_dollar(),
                                    expand  = ggplot2::expansion(mult = c(0, 0.1))) +
        {
          if (by_month) ggplot2::scale_x_discrete(drop = FALSE)
          else ggplot2::scale_x_date(date_breaks = x_breaks, date_labels = x_labels)
        } +
        ggplot2::labs(x = NULL, y = NULL) +
        ggplot2::theme_minimal(base_family = "Montserrat") +
        ggplot2::theme(
          axis.text.x      = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y      = ggplot2::element_text(size = 12),
          panel.border     = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
          panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
        )
      
      plotly::ggplotly(p, tooltip = "text") %>%
        plotly::layout(
          margin        = list(l = 40, r = 20, t = 20, b = 60),
          plot_bgcolor  = "#ffffff",
          paper_bgcolor = "#ffffff"
        )
    }
  })
  
  
  
  output$customer_split_chart <- renderPlotly({
    req(input$selected_date_range)
    
    # toggle daily/monthly from checkbox in UI
    by_month <- isTRUE(input$viz_by_month)
    
    filtered <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (!by_month) {
      plot_data <- filtered %>%
        mutate(
          Returning_Percent = Returning_Customers * 100,
          FirstTime_Percent = First_Time_Customers * 100
        )
      tip_fmt <- "%b %d, %Y"
    } else {
      # monthly weighted average using DTC_Orders as weight
      plot_data <- filtered %>%
        mutate(Month = lubridate::floor_date(Date, "month")) %>%
        group_by(Month) %>%
        summarise(
          Returning_Percent = if (sum(DTC_Orders, na.rm = TRUE) == 0) NA_real_ else
            weighted.mean(Returning_Customers * 100, w = DTC_Orders, na.rm = TRUE),
          FirstTime_Percent = if (sum(DTC_Orders, na.rm = TRUE) == 0) NA_real_ else
            weighted.mean(First_Time_Customers * 100, w = DTC_Orders, na.rm = TRUE),
          .groups = "drop"
        ) %>%
        rename(Date = Month)
      tip_fmt <- "%b %Y"
    }
    
    plot_ly(plot_data, x = ~Date) %>%
      add_trace(y = ~FirstTime_Percent, type = 'bar', name = 'First-Time',
                marker = list(color = 'rgba(52, 152, 219, 0.7)'),
                hoverinfo = 'text',
                text = ~paste0(format(Date, tip_fmt), "<br>First-Time: ", round(FirstTime_Percent, 1), "%"),
                textposition = "none") %>%
      add_trace(y = ~Returning_Percent, type = 'bar', name = 'Returning',
                marker = list(color = 'rgba(46, 204, 113, 0.7)'),
                hoverinfo = 'text',
                text = ~paste0(format(Date, tip_fmt), "<br>Returning: ", round(Returning_Percent, 1), "%"),
                textposition = "none") %>%
      layout(
        barmode = 'stack',
        yaxis = list(
          title = "",
          tickvals = seq(0, 100, by = 20),
          ticktext = paste0(seq(0, 100, by = 20), "%"),
          range = c(0, 100),
          tickfont = list(family = "Montserrat", size = 14)
        ),
        xaxis = list(
          title = "",
          tickfont = list(family = "Montserrat", size = 14)
        ),
        hovermode = "x unified",
        showlegend = TRUE,
        legend = list(
          orientation = "h", x = 0.5, y = 1.15, xanchor = "center",
          font = list(family = "Montserrat", size = 14)
        ),
        margin = list(l = 40, r = 20, t = 60, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff",
        font = list(family = "Montserrat")
      )
  })
  
  
  output$blue_sku_count <- renderText({
    selected_data()$current$Blue_SKU_Count
  })
  
  output$yellow_sku_count <- renderText({
    selected_data()$current$Yellow_SKU_Count
  })
  

  output$blue_sku_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/HxSDJXfX/382-x245-1.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$yellow_sku_image <- renderUI({
    tags$img(
      src = "https://mybirdbuddy.com/wp-content/uploads/2023/04/382-x245-1.webp",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$blue_roof_sku_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/K8ZYgrWs/blueroof.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$yellow_roof_sku_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/VvqYJdW8/yellowroof.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$blue_roof_sku_count <- renderText({
    selected_data()$current$Blue_Roof_SKU_Count
  })
  
  output$yellow_roof_sku_count <- renderText({
    selected_data()$current$Yellow_Roof_SKU_Count
  })
  
  output$sku_total_units <- renderText({
    total <- selected_data()$current$Blue_SKU_Count +
      selected_data()$current$Yellow_SKU_Count +
      selected_data()$current$Blue_Roof_SKU_Count +
      selected_data()$current$Yellow_Roof_SKU_Count +
      selected_data()$current$HBF_Count +
      selected_data()$current$HBF_Solar_Count
    
    format(total, big.mark = ",")
  })
  
  output$hbf_count <- renderText({
    selected_data()$current$HBF_Count
  })
  
  output$hbf_solar_count <- renderText({
    selected_data()$current$HBF_Solar_Count
  })
  
  output$hbf_image <- renderUI({
    tags$img(
      src = "https://mybirdbuddy.com/wp-content/uploads/2024/11/HBF.webp",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$hbf_solar_image <- renderUI({
    tags$img(
      src = "https://mybirdbuddy.com/wp-content/uploads/2024/11/HBF-solar.webp",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$addon_wall_mount_count <- renderText({
    selected_data()$current$Wall_Mount_Units
  })
  
  output$addon_suet_ball_count <- renderText({
    selected_data()$current$Suet_Ball_Units
  })
  
  output$addon_blue_nutrition_count <- renderText({
    selected_data()$current$Blue_Nutrition_Units
  })
  
  output$addon_yellow_nutrition_count <- renderText({
    selected_data()$current$Yellow_Nutrition_Units
  })
  output$addon_solar_roof_blue_count <- renderText({
    selected_data()$current$Solar_Roof_Blue_Units
  })
  output$addon_solar_roof_yellow_count <- renderText({
    selected_data()$current$Solar_Roof_Yellow_Units
  })
  output$addon_perch_extender_blue_count <- renderText({
    selected_data()$current$Perch_Extender_Blue_Units
  })
  output$addon_perch_extender_yellow_count <- renderText({
    selected_data()$current$Perch_Extender_Yellow_Units
  })
  output$addon_hbf_solar_roof_count <- renderText({
    selected_data()$current$HBF_Solar_Roof_Units
  })
  
  output$addon_hbf_housing_count <- renderText({
    selected_data()$current$HBF_Housing_Units
  })
  
  

  
  output$seed_seasonal_8lb <- renderText({ selected_data()$current$Seasonal_Curation_8lb })
  output$seed_seasonal_20lb <- renderText({ selected_data()$current$Seasonal_Curation_20lb })
  output$seed_buddy_8lb <- renderText({ selected_data()$current$Buddy_Bites_8lb })
  output$seed_buddy_20lb <- renderText({ selected_data()$current$Buddy_Bites_20lb })
  output$seed_snack_8lb <- renderText({ selected_data()$current$Snack_Soar_8lb })
  output$seed_snack_20lb <- renderText({ selected_data()$current$Snack_Soar_20lb })
  output$seed_avian_8lb <- renderText({ selected_data()$current$Avian_Choice_8lb })
  output$seed_avian_20lb <- renderText({ selected_data()$current$Avian_Choice_20lb })
  
  output$seed_total_units <- renderText({
    total <- sum(
      selected_data()$current$Seasonal_Curation_8lb,
      selected_data()$current$Seasonal_Curation_20lb,
      selected_data()$current$Buddy_Bites_8lb,
      selected_data()$current$Buddy_Bites_20lb,
      selected_data()$current$Snack_Soar_8lb,
      selected_data()$current$Snack_Soar_20lb,
      selected_data()$current$Avian_Choice_8lb,
      selected_data()$current$Avian_Choice_20lb,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # Amazon units for each SKU
  output$blue_sku_amazon_count <- renderText({
    selected_data()$current$Blue_SKU_AZ_Count
  })
  
  output$yellow_sku_amazon_count <- renderText({
    selected_data()$current$Yellow_SKU_AZ_Count
  })
  
  output$blue_roof_sku_amazon_count <- renderText({
    selected_data()$current$Blue_Roof_SKU_AZ_Count
  })
  
  output$yellow_roof_sku_amazon_count <- renderText({
    selected_data()$current$Yellow_Roof_SKU_AZ_Count
  })
  
  # Total Amazon units across the four SKUs
  output$sku_total_amazon_units <- renderText({
    total_amz <- 
      selected_data()$current$Blue_SKU_AZ_Count +
      selected_data()$current$Yellow_SKU_AZ_Count +
      selected_data()$current$Blue_Roof_SKU_AZ_Count +
      selected_data()$current$Yellow_Roof_SKU_AZ_Count
    format(total_amz, big.mark = ",")
  })
  
  
  # — NEW: Amazon counts for each add-on —
  output$addon_wall_mount_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_Wall Mount`,
      big.mark = ","
    )
  })
  
  output$addon_suet_ball_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_Suet Ball Holder`,
      big.mark = ","
    )
  })
  
  output$addon_3in1_blue_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Blue`,
      big.mark = ","
    )
  })
  
  output$addon_3in1_yellow_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Yellow`,
      big.mark = ","
    )
  })
  
  output$addon_solar_roof_blue_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_Solar Roof Single - Blue`,
      big.mark = ","
    )
  })
  
  output$addon_solar_roof_yellow_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_Solar Roof Single - Yellow`,
      big.mark = ","
    )
  })
  
  output$addon_perch_extender_blue_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_Perch Extender - Blue`,
      big.mark = ","
    )
  })
  
  output$addon_perch_extender_yellow_amz_count <- renderText({
    format(
      selected_data()$current$`amazon_Perch Extender - Yellow`,
      big.mark = ","
    )
  })
  
  
  # in server()
  # — DTC add-ons total units —
  output$addon_total_units <- renderText({
    total <- sum(
      selected_data()$current$Wall_Mount_Units,
      selected_data()$current$Suet_Ball_Units,
      selected_data()$current$Blue_Nutrition_Units,
      selected_data()$current$Yellow_Nutrition_Units,
      selected_data()$current$Solar_Roof_Blue_Units,
      selected_data()$current$Solar_Roof_Yellow_Units,
      selected_data()$current$Perch_Extender_Blue_Units,
      selected_data()$current$Perch_Extender_Yellow_Units,
      selected_data()$current$HBF_Solar_Roof_Units,
      selected_data()$current$HBF_Housing_Units,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # — AMAZON add-ons total units —
  output$addon_4_total_amz_units <- renderText({
    total_amz <- sum(
      selected_data()$current$`amazon_Wall Mount`,
      selected_data()$current$`amazon_Suet Ball Holder`,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Blue`,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Yellow`,
      selected_data()$current$`amazon_Solar Roof Single - Blue`,
      selected_data()$current$`amazon_Solar Roof Single - Yellow`,
      selected_data()$current$`amazon_Perch Extender - Blue`,
      selected_data()$current$`amazon_Perch Extender - Yellow`,
      na.rm = TRUE
    )
    format(total_amz, big.mark = ",")
  })
  
  
  
  output$blue_sku_rachio_count <- renderText({
    selected_data()$current$Rachio_Blue_SKU_Count
  })
  output$yellow_sku_rachio_count <- renderText({
    selected_data()$current$Rachio_Yellow_SKU_Count
  })
  output$blue_roof_sku_rachio_count <- renderText({
    selected_data()$current$Rachio_Blue_Roof_SKU_Count
  })
  output$yellow_roof_sku_rachio_count <- renderText({
    selected_data()$current$Rachio_Yellow_Roof_SKU_Count
  })
  
  # — RACHIO total units —
  output$sku_total_rachio_units <- renderText({
    total_rachio <- sum(
      selected_data()$current$`rachio_SKU 1 - Blue`,
      selected_data()$current$`rachio_SKU 2 - Yellow`,
      selected_data()$current$`rachio_SKU 3 - Blue w/ Solar`,
      selected_data()$current$`rachio_SKU 4 - Yellow w/ Solar`,
      na.rm = TRUE
    )
    format(total_rachio, big.mark = ",")
  })
  
  # — WEATHERFLOW counts for each SKU —
  output$blue_sku_weatherflow_count <- renderText({
    selected_data()$current$Weatherflow_Blue_SKU_Count
  })
  output$yellow_sku_weatherflow_count <- renderText({
    selected_data()$current$Weatherflow_Yellow_SKU_Count
  })
  output$blue_roof_sku_weatherflow_count <- renderText({
    selected_data()$current$Weatherflow_Blue_Roof_SKU_Count
  })
  output$yellow_roof_sku_weatherflow_count <- renderText({
    selected_data()$current$Weatherflow_Yellow_Roof_SKU_Count
  })
  
  # — WEATHERFLOW total units —
  output$sku_total_weatherflow_units <- renderText({
    total_wf <- sum(
      selected_data()$current$Weatherflow_Blue_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_SKU_Count,
      selected_data()$current$Weatherflow_Blue_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_Roof_SKU_Count,
      na.rm = TRUE
    )
    format(total_wf, big.mark = ",")
  })
  
  output$premium_subscription_image <- renderUI({
    tags$img(src = "https://i.postimg.cc/44mF30wd/premium.png",
             style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$premium_monthly_subscription_image <- renderUI({
    tags$img(src = "https://i.postimg.cc/7PFxqd0z/premium2.png",
             style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$addon_wall_mount_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/Z9rsBZkY/wall-mount.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$addon_suet_ball_image <- renderUI({ 
    tags$img(
      src = "https://i.postimg.cc/PrMBjMST/suet-ball.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
    })
  output$addon_blue_nutrition_image <- renderUI({ 
    tags$img(
      src = "https://i.postimg.cc/TK54xgCD/nutrition-blue.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
    })
  output$addon_yellow_nutrition_image <- renderUI({ 
    tags$img(
      src = "https://i.postimg.cc/23cqRZqm/nutrition-yellow.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
    })
  
  output$addon_solar_roof_blue_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/m26t8772/solar-roof-blue.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$addon_solar_roof_yellow_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/9RC8ySVd/solar-roof-yellow.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$addon_perch_extender_blue_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/PLxNNfvY/perch-blue.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$addon_perch_extender_yellow_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/xXgc0N89/perch-yellow.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$addon_hbf_solar_roof_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/McFHBk14/hbf-roof.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$addon_hbf_housing_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/5XfXdSxP/hbf-housing.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$seasonal_8lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/4yvL5JYp/seasonal-8.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$seasonal_20lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/4yvL5JYp/seasonal-8.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$buddy_bites_8lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/JzBLNX1X/buddy-8.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$buddy_bites_20lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/VdmM9CSc/buddy20.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$snack_8lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/jDj7mYQg/snack.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$snack_20lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/XrDC01sV/snack20.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  output$avian_8lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/9rb9LQTw/avian.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$avian_20lb_image <- renderUI({
    tags$img(
      src = "https://i.postimg.cc/JtbZBqzq/avian20.png",
      style = "height: 80px; object-fit: contain; margin-right: 20px; border-radius: 10px;"
    )
  })
  
  output$dtc_subs_count <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    format(sum(df$DTC_Subscription_Units, na.rm = TRUE), big.mark = ",")
  })
  output$apple_subs_count <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    format(sum(df$apple_yearly_sub, na.rm = TRUE), big.mark = ",")
  })
  
  output$google_subs_count <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    format(sum(df$google_yearly_sub, na.rm = TRUE), big.mark = ",")
  })
  
  output$total_subs_all_channels <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    total <- sum(df$DTC_Subscription_Units,
                 df$apple_yearly_sub,
                 df$google_yearly_sub,
                 na.rm = TRUE)
    format(total, big.mark = ",")
  })
  
  
  output$apple_monthly_subs_count <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    format(sum(df$apple_monthly_sub, na.rm = TRUE), big.mark = ",")
  })
  
  output$google_monthly_subs_count <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    format(sum(df$google_monthly_sub, na.rm = TRUE), big.mark = ",")
  })
  
  output$total_subs_monthly_all_channels <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2])
    total <- sum(
                 df$apple_monthly_sub,
                 df$google_monthly_sub,
                 na.rm = TRUE)
    format(total, big.mark = ",")
  })
  
  # helpers
  has_col  <- function(df, nm) nm %in% names(df)
  safe_sum <- function(x) if (is.null(x)) 0 else sum(x, na.rm = TRUE)
  
  # DTC total subscriptions (yearly + monthly if present)
  output$subs_total_dtc <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    dtc_monthly <- if (has_col(df, "DTC_Monthly_Subscription_Units"))
      df$DTC_Monthly_Subscription_Units else NULL
    
    total <- safe_sum(df$DTC_Subscription_Units)
    format(total, big.mark = ",")
  })
  
  # Apple total subscriptions (yearly + monthly)
  output$subs_total_apple <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    total <- safe_sum(df$apple_yearly_sub) + safe_sum(df$apple_monthly_sub)
    format(total, big.mark = ",")
  })
  
  # Google total subscriptions (yearly + monthly)
  output$subs_total_google <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    total <- safe_sum(df$google_yearly_sub) + safe_sum(df$google_monthly_sub)
    format(total, big.mark = ",")
  })
  
  # --- ALL CHANNELS: total subscriptions (DTC + Apple + Google) ---
  output$subs_total_all_channels <- renderText({
    req(input$selected_date_range)
    df <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    total <- sum(
      df$DTC_Subscription_Units,
      df$apple_yearly_sub,
      df$apple_monthly_sub,
      df$google_yearly_sub,
      df$google_monthly_sub,
      na.rm = TRUE
    )
    
    format(total, big.mark = ",")
  })
  
  
  output$blue_sku_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Blue_SKU_Count,
      selected_data()$current$Blue_SKU_AZ_Count,
      selected_data()$current$Rachio_Blue_SKU_Count,
      selected_data()$current$Weatherflow_Blue_SKU_Count,
      selected_data()$current$Walmart_Blue_SKU_Count,   # NEW
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$yellow_sku_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Yellow_SKU_Count,
      selected_data()$current$Yellow_SKU_AZ_Count,
      selected_data()$current$Rachio_Yellow_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_SKU_Count,
      selected_data()$current$Walmart_Yellow_SKU_Count, 
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # Blue w/ Solar
  output$blue_roof_sku_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Blue_Roof_SKU_Count,
      selected_data()$current$Blue_Roof_SKU_AZ_Count,
      selected_data()$current$Rachio_Blue_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Blue_Roof_SKU_Count,
      selected_data()$current$Walmart_Blue_Roof_SKU_Count,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # Yellow w/ Solar
  output$yellow_roof_sku_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Yellow_Roof_SKU_Count,
      selected_data()$current$Yellow_Roof_SKU_AZ_Count,
      selected_data()$current$Rachio_Yellow_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_Roof_SKU_Count,
      selected_data()$current$Walmart_Yellow_Roof_SKU_Count,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # HBF
  output$hbf_all_channels <- renderText({
    total <- sum(
      selected_data()$current$HBF_Count,
      # (no AZ/Rachio/WF columns exist for HBF, so just DTC)
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # HBF w/ Solar
  output$hbf_solar_all_channels <- renderText({
    total <- sum(
      selected_data()$current$HBF_Solar_Count,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  output$grand_total_all_channels <- renderText({
    # for each SKU, sum DTC + Amazon + Rachio + Weatherflow,
    # then sum those per-SKU totals:
    
    # Blue
    blue_all <- sum(
      selected_data()$current$Blue_SKU_Count,
      selected_data()$current$Blue_SKU_AZ_Count,
      selected_data()$current$Rachio_Blue_SKU_Count,
      selected_data()$current$Weatherflow_Blue_SKU_Count,
      selected_data()$current$Walmart_Blue_SKU_Count,   
      na.rm = TRUE
    )
    # Yellow
    yellow_all <- sum(
      selected_data()$current$Yellow_SKU_Count,
      selected_data()$current$Yellow_SKU_AZ_Count,
      selected_data()$current$Rachio_Yellow_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_SKU_Count,
      selected_data()$current$Walmart_Yellow_SKU_Count,
      na.rm = TRUE
    )
    # Blue w/ Solar
    blue_roof_all <- sum(
      selected_data()$current$Blue_Roof_SKU_Count,
      selected_data()$current$Blue_Roof_SKU_AZ_Count,
      selected_data()$current$Rachio_Blue_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Blue_Roof_SKU_Count,
      selected_data()$current$Walmart_Blue_Roof_SKU_Count,
      na.rm = TRUE
    )
    # Yellow w/ Solar
    yellow_roof_all <- sum(
      selected_data()$current$Yellow_Roof_SKU_Count,
      selected_data()$current$Yellow_Roof_SKU_AZ_Count,
      selected_data()$current$Rachio_Yellow_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_Roof_SKU_Count,
      selected_data()$current$Walmart_Yellow_Roof_SKU_Count,
      na.rm = TRUE
    )
    # HBF (DTC only)
    hbf_all <- selected_data()$current$HBF_Count
    # HBF w/ Solar (DTC only)
    hbf_solar_all <- selected_data()$current$HBF_Solar_Count
    
    grand_total <- sum(
      blue_all,
      yellow_all,
      blue_roof_all,
      yellow_roof_all,
      hbf_all,
      hbf_solar_all,
      na.rm = TRUE
    )
    
    format(grand_total, big.mark = ",")
  })
  
  # DTC + Amazon + (other channels if applicable) per add-on
  output$addon_wall_mount_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Wall_Mount_Units,
      selected_data()$current$`amazon_Wall Mount`,
      selected_data()$current$Walmart_Wall_Mount_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_suet_ball_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Suet_Ball_Units,
      selected_data()$current$`amazon_Suet Ball Holder`,
      selected_data()$current$Walmart_Suet_Ball_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_blue_nutrition_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Blue_Nutrition_Units,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Blue`,
      selected_data()$current$Walmart_3in1_Blue_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_yellow_nutrition_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Yellow_Nutrition_Units,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Yellow`,
      selected_data()$current$Walmart_3in1_Yellow_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_solar_roof_blue_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Solar_Roof_Blue_Units,
      selected_data()$current$`amazon_Solar Roof Single - Blue`,
      selected_data()$current$Walmart_Solar_Roof_Blue_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_solar_roof_yellow_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Solar_Roof_Yellow_Units,
      selected_data()$current$`amazon_Solar Roof Single - Yellow`,
      selected_data()$current$Walmart_Solar_Roof_Yellow_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_perch_extender_blue_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Perch_Extender_Blue_Units,
      selected_data()$current$`amazon_Perch Extender - Blue`,
      selected_data()$current$Walmart_Perch_Extender_Blue_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_perch_extender_yellow_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Perch_Extender_Yellow_Units,
      selected_data()$current$`amazon_Perch Extender - Yellow`,
      selected_data()$current$Walmart_Perch_Extender_Yellow_Units,   
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # HBF Solar Roof
  output$addon_hbf_solar_roof_all_channels <- renderText({
    total <- sum(
      selected_data()$current$HBF_Solar_Roof_Units,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # HBF Housing
  output$addon_hbf_housing_all_channels <- renderText({
    total <- sum(
      selected_data()$current$HBF_Housing_Units,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  # Grand total across all add-ons and channels
  output$addon_grand_total_all_channels <- renderText({
    grand <- sum(
      # DTC add-ons
      selected_data()$current$Wall_Mount_Units,
      selected_data()$current$Suet_Ball_Units,
      selected_data()$current$Blue_Nutrition_Units,
      selected_data()$current$Yellow_Nutrition_Units,
      selected_data()$current$Solar_Roof_Blue_Units,
      selected_data()$current$Solar_Roof_Yellow_Units,
      selected_data()$current$Perch_Extender_Blue_Units,
      selected_data()$current$Perch_Extender_Yellow_Units,
      selected_data()$current$HBF_Solar_Roof_Units,
      selected_data()$current$HBF_Housing_Units,
      # Amazon add-ons
      selected_data()$current$`amazon_Wall Mount`,
      selected_data()$current$`amazon_Suet Ball Holder`,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Blue`,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Yellow`,
      selected_data()$current$`amazon_Solar Roof Single - Blue`,
      selected_data()$current$`amazon_Solar Roof Single - Yellow`,
      selected_data()$current$`amazon_Perch Extender - Blue`,
      selected_data()$current$`amazon_Perch Extender - Yellow`,
      
      selected_data()$current$Walmart_Wall_Mount_Units, 
      selected_data()$current$Walmart_Suet_Ball_Units,   
      selected_data()$current$Walmart_3in1_Blue_Units,   
      selected_data()$current$Walmart_3in1_Yellow_Units,   
      selected_data()$current$Walmart_Solar_Roof_Blue_Units,   
      selected_data()$current$Walmart_Solar_Roof_Yellow_Units,   
      selected_data()$current$Walmart_Perch_Extender_Blue_Units,   
      selected_data()$current$Walmart_Perch_Extender_Yellow_Units,   
      
      na.rm = TRUE
    )
    format(grand, big.mark = ",")
  })
  
  # Walmart SKU counts
  output$blue_sku_walmart_count <- renderText({
    selected_data()$current$Walmart_Blue_SKU_Count
  })
  output$yellow_sku_walmart_count <- renderText({
    selected_data()$current$Walmart_Yellow_SKU_Count
  })
  output$blue_roof_sku_walmart_count <- renderText({
    selected_data()$current$Walmart_Blue_Roof_SKU_Count
  })
  output$yellow_roof_sku_walmart_count <- renderText({
    selected_data()$current$Walmart_Yellow_Roof_SKU_Count
  })
  
  # Optional: total Walmart units across the four SKUs (if you want a widget)
  output$sku_total_walmart_units <- renderText({
    total_wm <- sum(
      selected_data()$current$Walmart_Blue_SKU_Count,
      selected_data()$current$Walmart_Yellow_SKU_Count,
      selected_data()$current$Walmart_Blue_Roof_SKU_Count,
      selected_data()$current$Walmart_Yellow_Roof_SKU_Count,
      na.rm = TRUE
    )
    format(total_wm, big.mark = ",")
  })
  
  
  # at top of server.R if not already:
  # library(forcats)
  
  output$units_ua_plot <- renderPlotly({
    req(input$selected_date_range, input$units_ua_channel, input$units_ua_view)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    legend_layout <- list(
      orientation = "h",
      x           = 0.5,
      y           = 1.15,
      xanchor     = "center",
      font        = list(family = "Montserrat", size = 14),
      title       = list(text = NULL)
    )
    
    # ---- helper: sum across columns that actually exist ----
    sum_existing <- function(df, cols) {
      keep <- intersect(cols, names(df))
      if (length(keep) == 0) rep(0, nrow(df)) else rowSums(df[keep], na.rm = TRUE)
    }
    
    # ---- SKU name buckets ----
    dtc_units_cols <- c(
      "dtc_SKU 1 - Blue","dtc_SKU 2 - Yellow",
      "dtc_SKU 3 - Blue w/ Solar","dtc_SKU 4 - Yellow w/ Solar",
      "dtc_SKU 5 - HBF","dtc_SKU 6 - HBF w/ Solar"
    )
    amazon_units_cols <- c(
      "amazon_SKU 1 - Blue","amazon_SKU 2 - Yellow",
      "amazon_SKU 3 - Blue w/ Solar","amazon_SKU 4 - Yellow w/ Solar"
    )
    digital_units_cols <- c(
      "rachio_SKU 1 - Blue","rachio_SKU 2 - Yellow",
      "rachio_SKU 3 - Blue w/ Solar","rachio_SKU 4 - Yellow w/ Solar",
      "weatherflow_SKU 1 - Blue","weatherflow_SKU 2 - Yellow",
      "weatherflow_SKU 3 - Blue w/ Solar","weatherflow_SKU 4 - Yellow w/ Solar"
    )
    
    dtc_addons_cols <- c(
      "dtc_Wall Mount","dtc_Suet Ball Holder",
      "dtc_3-in-1 Nutrition Set - Blue","dtc_3-in-1 Nutrition Set - Yellow",
      "dtc_Solar Roof Single - Blue","dtc_Solar Roof Single - Yellow",
      "dtc_Perch Extender - Blue","dtc_Perch Extender - Yellow",
      "dtc_Solar Roof (HBF)","dtc_Housing - only (HBF)"
    )
    amazon_addons_cols <- c(
      "amazon_Wall Mount","amazon_Suet Ball Holder",
      "amazon_3-in-1 Nutrition Set - Blue","amazon_3-in-1 Nutrition Set - Yellow",
      "amazon_Solar Roof Single - Blue","amazon_Solar Roof Single - Yellow",
      "amazon_Perch Extender - Blue","amazon_Perch Extender - Yellow"
    )
    dtc_seeds_cols <- c(
      "dtc_Seasonal Curation - 8lb","dtc_Seasonal Curation - 20lb",
      "dtc_Buddy Bites - 8lb","dtc_Buddy Bites - 20lb",
      "dtc_Snack n' Soar - 8lb","dtc_Snack n' Soar - 20lb",
      "dtc_Avian Choice - 8lb","dtc_Avian Choice - 20lb"
    )
    
    # 1) filter date
    df0 <- revenue_data %>%
      dplyr::filter(
        Date >= input$selected_date_range[1],
        Date <= input$selected_date_range[2]
      ) %>%
      dplyr::mutate(Date = as.Date(Date))
    
    # 2) daily buckets, then group by day
    df_daily <- df0 %>%
      dplyr::mutate(
        Units_DTC     = sum_existing(., dtc_units_cols),
        Units_Amazon  = sum_existing(., amazon_units_cols),
        Units_Digital = sum_existing(., digital_units_cols),
        
        Addons_DTC    = sum_existing(., dtc_addons_cols),
        Addons_Amazon = sum_existing(., amazon_addons_cols),
        Addons_Digital= 0,
        
        Seeds_DTC     = sum_existing(., dtc_seeds_cols),
        Seeds_Amazon  = 0,
        Seeds_Digital = 0
      ) %>%
      dplyr::mutate(
        Units_All  = Units_DTC  + Units_Amazon  + Units_Digital,
        Addons_All = Addons_DTC + Addons_Amazon + Addons_Digital,
        Seeds_All  = Seeds_DTC  + Seeds_Amazon  + Seeds_Digital
      ) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(where(is.numeric), ~ sum(.x, na.rm = TRUE)),
                       .groups = "drop")
    
    # 2.5) optional monthly roll-up
    df_sum <- if (by_month) {
      df_daily %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month) %>%
        dplyr::summarise(dplyr::across(where(is.numeric), ~ sum(.x, na.rm = TRUE)),
                         .groups = "drop") %>%
        dplyr::rename(Date = Month)
    } else df_daily
    
    # 3) pick channel & long
    df_ch <- df_sum %>%
      dplyr::transmute(
        Date,
        Units  = dplyr::case_when(
          input$units_ua_channel == "All"     ~ Units_All,
          input$units_ua_channel == "DTC"     ~ Units_DTC,
          input$units_ua_channel == "Amazon"  ~ Units_Amazon,
          input$units_ua_channel == "Digital" ~ Units_Digital
        ),
        Addons = dplyr::case_when(
          input$units_ua_channel == "All"     ~ Addons_All,
          input$units_ua_channel == "DTC"     ~ Addons_DTC,
          input$units_ua_channel == "Amazon"  ~ Addons_Amazon,
          input$units_ua_channel == "Digital" ~ Addons_Digital
        ),
        Seeds  = dplyr::case_when(
          input$units_ua_channel == "All"     ~ Seeds_All,
          input$units_ua_channel == "DTC"     ~ Seeds_DTC,
          input$units_ua_channel == "Amazon"  ~ Seeds_Amazon,
          input$units_ua_channel == "Digital" ~ Seeds_Digital
        )
      ) %>%
      tidyr::pivot_longer(c(Units, Addons, Seeds),
                          names_to = "Category", values_to = "Count") %>%
      dplyr::mutate(
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>", format(Date, tip_fmt), "</b><br>",
          "<b>", Category, ": </b>", Count,
          "</span>"
        )
      ) %>%
      { if (!isTRUE(input$units_include_seeds)) dplyr::filter(., Category != "Seeds") else . } %>%
      dplyr::filter(
        !(Category == "Seeds" & input$units_ua_channel == "Amazon"),
        !(Category %in% c("Seeds","Addons") & input$units_ua_channel == "Digital")
      ) %>%
      # >>> build categorical month X to avoid bar overlap in month view <<<
      dplyr::mutate(
        X = if (by_month) forcats::fct_inorder(format(Date, "%b %Y")) else Date
      )
    
    if (input$units_ua_view == "Absolute") {
      
      if (isTRUE(input$units_line_view)) {
        p <- ggplot2::ggplot(
          df_ch,
          ggplot2::aes(x = Date, y = Count, color = Category, group = Category, text = Tooltip)
        ) +
          ggplot2::geom_line(size = 1) +
          ggplot2::geom_point(size = 2) +
          ggplot2::scale_color_manual(values = c("Units"="#2ecc71","Addons"="#3498db","Seeds"="#f39c12")) +
          ggplot2::scale_x_date(date_breaks = if (by_month) "1 month" else "5 days",
                                date_labels = if (by_month) "%b %Y" else "%b %d") +
          ggplot2::theme_minimal(base_family = "Montserrat") +
          ggplot2::theme(
            axis.text.x  = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y  = ggplot2::element_text(size = 12),
            panel.border = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
            panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
          )
        
        plotly::ggplotly(p, tooltip = "text") %>%
          plotly::layout(
            margin        = list(l = 40, r = 20, t = 20, b = 60),
            plot_bgcolor  = "#ffffff",
            paper_bgcolor = "#ffffff",
            showlegend    = TRUE,
            legend        = legend_layout,
            font          = list(family = "Montserrat")
          )
        
      } else {
        # ✅ Use categorical X in month view so dodged bars don't overlap
        p <- ggplot2::ggplot(
          df_ch,
          ggplot2::aes(x = X, y = Count, fill = Category, text = Tooltip)
        ) +
          ggplot2::geom_col(
            position = ggplot2::position_dodge2(width = 0.9, preserve = "single"),
            width    = if (by_month) 0.85 else 0.7
          ) +
          ggplot2::scale_fill_manual(values = c("Units"="#2ecc71","Addons"="#3498db","Seeds"="#f39c12")) +
          (if (by_month)
            ggplot2::scale_x_discrete(drop = FALSE)
           else
             ggplot2::scale_x_date(date_breaks = "5 days", date_labels = "%b %d")
          ) +
          ggplot2::theme_minimal(base_family = "Montserrat") +
          ggplot2::theme(
            axis.text.x     = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y     = ggplot2::element_text(size = 12),
            legend.position = "none",
            panel.border    = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = ggplot2::element_rect(fill = "#ffffff", color = NA),
            panel.background= ggplot2::element_rect(fill = "#ffffff", color = NA)
          )
        
        plotly::ggplotly(p, tooltip = "text") %>%
          plotly::layout(
            barmode       = "group",
            margin        = list(l = 40, r = 20, t = 20, b = 60),
            plot_bgcolor  = "#ffffff",
            paper_bgcolor = "#ffffff",
            showlegend    = TRUE,
            legend        = legend_layout,
            font          = list(family = "Montserrat")
          )
      }
      
    } else {
      # RELATIVE (works for day or month)
      totals <- df_ch %>%
        dplyr::group_by(Date) %>%
        dplyr::summarise(DayTotal = sum(Count), .groups = "drop")
      
      df_rel <- dplyr::left_join(df_ch, totals, by = "Date") %>%
        dplyr::mutate(
          Share = dplyr::if_else(DayTotal == 0, 0, Count / DayTotal),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>", format(Date, tip_fmt), "</b><br>",
            "<span style='color:",
            dplyr::case_when(
              Category=="Units"  ~ "#2ecc71",
              Category=="Addons" ~ "#3498db",
              Category=="Seeds"  ~ "#f39c12"
            ), ";'>",
            Category, ": ", round(Share*100,1), "% (", Count, " units)</span></span>"
          )
        )
      
      legend_df <- df_rel %>%
        dplyr::group_by(Category) %>%
        dplyr::summarise(Total = sum(Count), .groups="drop") %>%
        dplyr::mutate(
          CumPct = round(Total / sum(Total) * 100, 1),
          Legend = paste0(Category, " (", CumPct, "%)")
        )
      
      p <- plotly::plot_ly()
      for (i in seq_len(nrow(legend_df))) {
        cat_name    <- legend_df$Category[i]
        legend_name <- legend_df$Legend[i]
        line_col    <- switch(cat_name,
                              "Units"  = '#2ecc71',
                              "Addons" = '#3498db',
                              "Seeds"  = '#f39c12')
        
        p <- p %>%
          plotly::add_trace(
            data        = df_rel %>% dplyr::filter(Category == cat_name),
            x           = ~Date,
            y           = ~Share,
            type        = 'bar',
            name        = legend_name,
            marker      = list(color = line_col),
            hovertext   = ~Tooltip,
            hoverinfo   = 'text',
            textposition= 'none'
          )
      }
      
      p %>% plotly::layout(
        barmode       = "stack",
        hovermode     = "x unified",
        legend        = legend_layout,
        margin        = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor  = "#ffffff",
        paper_bgcolor = "#ffffff",
        font          = list(family = "Montserrat"),
        xaxis         = list(
          title     = "",
          tickfont  = list(family = "Montserrat", size = 14),
          showline  = TRUE,
          ticks     = "outside",
          tickformat= if (by_month) "%b %Y" else "%b %d"
        ),
        yaxis         = list(
          title     = "",
          tickformat= ".0%",
          tickfont  = list(family = "Montserrat", size = 14),
          showline  = TRUE,
          ticks     = "outside"
        )
      )
    }
  })
  
  
 
  observeEvent(input$by_type,        if (input$by_type)        updateCheckboxInput(session, "by_type_colour", value = FALSE))
  observeEvent(input$by_type_colour, if (input$by_type_colour) updateCheckboxInput(session, "by_type",        value = FALSE))
  
  current_view <- reactive({
    if      (isTRUE(input$by_type_colour)) "type_colour"
    else if (isTRUE(input$by_type))        "type"
    else                                   "brand"
  })
  
  ## ────────────────────────────────────────────────────────────────
  ## 2.  Global “Line chart view” toggle (only for Absolute views)
  ## ────────────────────────────────────────────────────────────────
  want_lines <- reactive({
    isTRUE(input$line_view) && (
      (current_view() == "brand"       && input$sbf_hbf_view      == "Absolute") ||
        (current_view() == "type"        && input$grouped_skus_view == "Absolute") ||
        (current_view() == "type_colour" && input$sku_view          == "Absolute")
    )
  })
  
  ## ────────────────────────────────────────────────────────────────
  ## 3.  Compact (top‑bar) filters
  ## ────────────────────────────────────────────────────────────────
  output$compact_filters <- renderUI({
    switch(current_view(),
           "brand" = tagList(
             selectInput("sbf_hbf_channel", NULL,
                         c(All="All", DTC="DTC", Amazon="Amazon", `Digital Mkt.`="Digital"),
                         selected = "All", width = "150px"),
             selectInput("sbf_hbf_view", NULL,
                         c(Absolute="Absolute", Relative="Relative"),
                         selected = "Absolute", width = "120px")
           ),
           "type" = tagList(
             selectInput("grouped_skus_channel", NULL,
                         c(All="All", DTC="DTC", Amazon="Amazon", `Digital Mkt.`="Digital"),
                         selected = "All", width = "150px"),
             selectInput("grouped_skus_view", NULL,
                         c(Absolute="Absolute", Relative="Relative"),
                         selected = "Absolute", width = "120px")
           ),
           "type_colour" = tagList(
             selectInput("sku_channel", NULL,
                         c(All="All", DTC="DTC", Amazon="Amazon", `Digital Mkt.`="Digital"),
                         selected = "All", width = "150px"),
             selectInput("sku_view", NULL,
                         c(Absolute="Absolute", Relative="Relative"),
                         selected = "Absolute", width = "120px")
           )
    )
  })
  
  ## 2nd‑row (long) selectors
  output$long_filters <- renderUI({
    switch(current_view(),
           "brand" = NULL,
           "type"  = selectizeInput("grouped_skus_groups", NULL,
                                    c("SBF","SBF Solar","HBF","HBF Solar"),
                                    selected = c("SBF","SBF Solar","HBF","HBF Solar"),
                                    multiple = TRUE,
                                    options  = list(plugins = list("remove_button")),
                                    width    = "800px"),
           "type_colour" = selectizeInput("selected_skus", NULL,
                                          c("SBF Blue","SBF Yellow","SBF Solar Blue","SBF Solar Yellow",
                                            "HBF","HBF Solar"),
                                          selected = c("SBF Blue","SBF Yellow","SBF Solar Blue",
                                                       "SBF Solar Yellow","HBF","HBF Solar"),
                                          multiple = TRUE,
                                          options  = list(plugins = list("remove_button")),
                                          width    = "800px")
    )
  })
  # Missing-safe row sums: only sum columns that exist
  sum_existing_rows <- function(data, cols) {
    keep <- intersect(cols, names(data))
    if (length(keep) == 0) rep(0, nrow(data)) else rowSums(data[keep], na.rm = TRUE)
  }
  
  ## ────────────────────────────────────────────────────────────────
  ## 4.  Single plot output
  ## ────────────────────────────────────────────────────────────────
  output$sku_plot <- renderPlotly({
    switch(current_view(),
           "brand"       = sbf_hbf_plot(),
           "type"        = sku_group_plot(),
           "type_colour" = sku_channel_plot()
    )
  })
  
  ## ────────────────────────────────────────────────────────────────
  ## 5.  Plot functions
  ##     * Absolute   → grouped bars | lines
  ##     * Relative   → stacked bars (legend shows cumulative %)
  ## ────────────────────────────────────────────────────────────────
  
  ## ---------------- 5.1  SBF  vs  HBF ----------------------------------------
  sbf_hbf_plot <- function() {
    req(input$selected_date_range, input$sbf_hbf_channel, input$sbf_hbf_view)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    df <- revenue_data |>
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) |>
      dplyr::mutate(Date = as.Date(Date))
    
    # Column buckets
    cols_SBF_all <- c(
      "dtc_SKU 1 - Blue","dtc_SKU 2 - Yellow",
      "dtc_SKU 3 - Blue w/ Solar","dtc_SKU 4 - Yellow w/ Solar",
      "amazon_SKU 1 - Blue","amazon_SKU 2 - Yellow",
      "amazon_SKU 3 - Blue w/ Solar","amazon_SKU 4 - Yellow w/ Solar",
      "rachio_SKU 1 - Blue","rachio_SKU 2 - Yellow",
      "rachio_SKU 3 - Blue w/ Solar","rachio_SKU 4 - Yellow w/ Solar",
      "weatherflow_SKU 1 - Blue","weatherflow_SKU 2 - Yellow",
      "weatherflow_SKU 3 - Blue w/ Solar","weatherflow_SKU 4 - Yellow w/ Solar"
    )
    cols_SBF_dtc     <- c("dtc_SKU 1 - Blue","dtc_SKU 2 - Yellow",
                          "dtc_SKU 3 - Blue w/ Solar","dtc_SKU 4 - Yellow w/ Solar")
    cols_SBF_amazon  <- c("amazon_SKU 1 - Blue","amazon_SKU 2 - Yellow",
                          "amazon_SKU 3 - Blue w/ Solar","amazon_SKU 4 - Yellow w/ Solar")
    cols_SBF_digital <- c("rachio_SKU 1 - Blue","rachio_SKU 2 - Yellow",
                          "rachio_SKU 3 - Blue w/ Solar","rachio_SKU 4 - Yellow w/ Solar",
                          "weatherflow_SKU 1 - Blue","weatherflow_SKU 2 - Yellow",
                          "weatherflow_SKU 3 - Blue w/ Solar","weatherflow_SKU 4 - Yellow w/ Solar")
    cols_HBF_dtc     <- c("dtc_SKU 5 - HBF","dtc_SKU 6 - HBF w/ Solar")
    
    cols_SBF <- switch(input$sbf_hbf_channel,
                       "All"     = cols_SBF_all,
                       "DTC"     = cols_SBF_dtc,
                       "Amazon"  = cols_SBF_amazon,
                       "Digital" = cols_SBF_digital
    )
    
    # Compute row-sum vectors missing-safe (outside mutate)
    SBF_vec <- sum_existing_rows(df, cols_SBF)
    HBF_vec <- if (input$sbf_hbf_channel %in% c("All","DTC"))
      sum_existing_rows(df, cols_HBF_dtc) else rep(0, nrow(df))
    
    df_daily <- df |>
      dplyr::mutate(SBF = SBF_vec, HBF = HBF_vec) |>
      dplyr::group_by(Date) |>
      dplyr::summarise(SBF = sum(SBF, na.rm = TRUE),
                       HBF = sum(HBF, na.rm = TRUE),
                       .groups = "drop") |>
      tidyr::pivot_longer(c(SBF, HBF), names_to = "Group", values_to = "Count")
    
    df_sum <- if (by_month) {
      df_daily |>
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) |>
        dplyr::group_by(Month, Group) |>
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") |>
        dplyr::rename(Date = Month)
    } else df_daily
    
    if (input$sbf_hbf_view == "Absolute") {
      df_abs <- df_sum |>
        dplyr::mutate(Tooltip = paste0("<b>", format(Date, tip_fmt),
                                       "</b><br>", Group, ": ", Count, " units"))
      
      if (want_lines()) {
        p <- plotly::plot_ly(df_abs, x = ~Date, y = ~Count, color = ~Group,
                             colors = c(SBF="#2980b9", HBF="#b12625"),
                             type = "scatter", mode = "lines+markers",
                             hovertext = ~Tooltip, hoverinfo = "text", textposition = "none")
      } else {
        p <- plotly::plot_ly()
        for (g in c("SBF","HBF")) {
          p <- p |>
            plotly::add_bars(data = dplyr::filter(df_abs, Group == g),
                             x = ~Date, y = ~Count, name = g,
                             marker = list(color = if (g=="SBF") "#2980b9" else "#b12625"),
                             hovertext = ~Tooltip, hoverinfo = "text", textposition = "none")
        }
        p <- p |> plotly::layout(barmode = "group")
      }
      
    } else {
      totals <- df_sum |>
        dplyr::group_by(Date) |>
        dplyr::summarise(DayTotal = sum(Count), .groups = "drop")
      
      df_rel <- dplyr::left_join(df_sum, totals, by = "Date") |>
        dplyr::mutate(
          Share = ifelse(DayTotal == 0, 0, Count / DayTotal),
          Tooltip = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                           Group, ": ", round(Share*100,1), "% (", Count," units)")
        )
      
      overall <- df_rel |>
        dplyr::group_by(Group) |>
        dplyr::summarise(Total = sum(Count), .groups = "drop") |>
        dplyr::mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum * 100, 1), overall$Group)
      
      p <- plotly::plot_ly()
      for (g in c("SBF","HBF")) {
        p <- p |>
          plotly::add_bars(data = dplyr::filter(df_rel, Group == g),
                           x = ~Date, y = ~Share,
                           name = paste0(g," (", pct[g], "%)"),
                           marker = list(color = if (g=="SBF") "#2980b9" else "#b12625"),
                           hovertext = ~Tooltip, hoverinfo = "text", textposition = "none")
      }
      p <- p |> plotly::layout(barmode = "stack", yaxis = list(tickformat = ".0%"))
    }
    
    p |>
      plotly::layout(
        legend = list(orientation = "h", x = 0.5, y = 1.15, xanchor = "center"),
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff", paper_bgcolor = "#ffffff",
        font = list(family = "Montserrat")
      )
  }
  
  ## ---------------- 5.3  SKU + colour ----------------------------------------
  ## ---------------- 5.3  SKU + colour ----------------------------------------
  sku_channel_plot <- function() {
    req(input$selected_date_range, input$sku_channel, input$sku_view, input$selected_skus)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # Legend layout (same style you use elsewhere)
    legend_layout <- list(
      orientation = "h",
      x = 0.5, y = 1.15, xanchor = "center",
      font = list(family = "Montserrat", size = 14),
      title = list(text = NULL)
    )
    
    # 1) Filter range
    df <- revenue_data |>
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) |>
      dplyr::mutate(Date = as.Date(Date))
    
    # 2) Choose columns by channel (robust via grep)
    sel_cols <- switch(
      input$sku_channel,
      "All"     = grep("^(dtc|amazon|rachio|weatherflow)_SKU", names(df), value = TRUE),
      "DTC"     = grep("^dtc_SKU",       names(df), value = TRUE),
      "Amazon"  = grep("^amazon_SKU",    names(df), value = TRUE),
      "Digital" = c(grep("^rachio_SKU",      names(df), value = TRUE),
                    grep("^weatherflow_SKU", names(df), value = TRUE))
    )
    
    # If nothing matches (all missing), return an empty chart with a friendly note
    if (length(sel_cols) == 0) {
      return(
        plotly::plot_ly() |>
          plotly::layout(
            annotations = list(list(
              text = "No SKU columns found for this channel.",
              xref = "paper", yref = "paper", x = 0.5, y = 0.5,
              showarrow = FALSE, font = list(family = "Montserrat", size = 14)
            )),
            margin = list(l = 40, r = 20, t = 20, b = 60),
            paper_bgcolor = "#ffffff", plot_bgcolor = "#ffffff",
            font = list(family = "Montserrat")
          )
      )
    }
    
    # 3) Long format → friendly SKU labels → daily sums
    df_long <- df |>
      tidyr::pivot_longer(all_of(sel_cols), names_to = "col", values_to = "Count") |>
      dplyr::mutate(SKU = dplyr::case_when(
        grepl("SKU 1", col) ~ "SBF Blue",
        grepl("SKU 2", col) ~ "SBF Yellow",
        grepl("SKU 3", col) ~ "SBF Solar Blue",
        grepl("SKU 4", col) ~ "SBF Solar Yellow",
        grepl("SKU 5", col) ~ "HBF",
        grepl("SKU 6", col) ~ "HBF Solar",
        TRUE ~ NA_character_
      )) |>
      dplyr::filter(!is.na(SKU), SKU %in% input$selected_skus) |>
      dplyr::group_by(Date, SKU) |>
      dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") |>
      dplyr::mutate(SKU = factor(SKU, levels = c(
        "SBF Blue","SBF Yellow","SBF Solar Blue","SBF Solar Yellow","HBF","HBF Solar"
      )))
    
    # 4) Monthly roll-up if needed
    if (by_month) {
      df_long <- df_long |>
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) |>
        dplyr::group_by(Month, SKU) |>
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") |>
        dplyr::rename(Date = Month)
    }
    
    # Colors (same palette you’ve used)
    cols6 <- c("SBF Blue"="#005AB5","SBF Yellow"="#FDAF17",
               "SBF Solar Blue"="#3498db","SBF Solar Yellow"="#f1c40f",
               "HBF"="#7b868c","HBF Solar"="#e74c3c")
    
    ## ---------------- Absolute ----------------
    if (input$sku_view == "Absolute") {
      df_abs <- df_long |>
        dplyr::mutate(Tooltip = paste0(
          "<b>", format(Date, tip_fmt), "</b><br>", SKU, ": ", Count, " units"
        ))
      
      if (want_lines()) {
        p <- plotly::plot_ly(
          df_abs, x = ~Date, y = ~Count, color = ~SKU, colors = cols6,
          type = "scatter", mode = "lines+markers",
          hovertext = ~Tooltip, hoverinfo = "text", textposition = "none"
        )
      } else {
        p <- plotly::plot_ly()
        for (s in levels(df_abs$SKU)) {
          p <- p |>
            plotly::add_bars(
              data = dplyr::filter(df_abs, SKU == s),
              x = ~Date, y = ~Count, name = s,
              marker = list(color = cols6[s]),
              hovertext = ~Tooltip, hoverinfo = "text", textposition = "none"
            )
        }
        p <- p |> plotly::layout(barmode = "group")
      }
      
      ## ---------------- Relative ----------------
    } else {
      totals <- df_long |>
        dplyr::group_by(Date) |>
        dplyr::summarise(DayTotal = sum(Count), .groups = "drop")
      
      df_rel <- dplyr::left_join(df_long, totals, by = "Date") |>
        dplyr::mutate(
          Share = dplyr::if_else(DayTotal == 0, 0, Count / DayTotal),
          Tooltip = paste0(
            "<b>", format(Date, tip_fmt), "</b><br>",
            SKU, ": ", round(Share * 100, 1), " % (", Count, " units)"
          )
        )
      
      # cumulative % for legend
      overall <- df_rel |>
        dplyr::group_by(SKU) |>
        dplyr::summarise(Total = sum(Count), .groups = "drop") |>
        dplyr::mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum * 100, 1), overall$SKU)
      
      p <- plotly::plot_ly()
      for (s in levels(df_rel$SKU)) {
        p <- p |>
          plotly::add_bars(
            data = dplyr::filter(df_rel, SKU == s),
            x = ~Date, y = ~Share,
            name = paste0(s, " (", pct[s], "%)"),
            marker = list(color = cols6[s]),
            hovertext = ~Tooltip, hoverinfo = "text", textposition = "none"
          )
      }
      p <- p |> plotly::layout(barmode = "stack", yaxis = list(tickformat = ".0%"))
    }
    
    # 5) Shared layout
    p |>
      plotly::layout(
        legend = legend_layout,
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff",
        font = list(family = "Montserrat"),
        xaxis = list(
          title = "",
          tickfont = list(family = "Montserrat", size = 14),
          tickformat = if (by_month) "%b %Y" else "%b %d"
        ),
        yaxis = list(
          title = "",
          tickfont = list(family = "Montserrat", size = 14)
        )
      )
  }
  
  
  ## ---------------- 5.2  SKU groups ------------------------------------------
  sku_group_plot <- function() {
    req(input$selected_date_range, input$grouped_skus_channel, input$grouped_skus_groups, input$grouped_skus_view)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    df <- revenue_data |>
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) |>
      dplyr::mutate(Date = as.Date(Date))
    
    cols_SBF <- switch(input$grouped_skus_channel,
                       "All"     = c("dtc_SKU 1 - Blue","dtc_SKU 2 - Yellow",
                                     "amazon_SKU 1 - Blue","amazon_SKU 2 - Yellow",
                                     "rachio_SKU 1 - Blue","rachio_SKU 2 - Yellow",
                                     "weatherflow_SKU 1 - Blue","weatherflow_SKU 2 - Yellow"),
                       "DTC"     = c("dtc_SKU 1 - Blue","dtc_SKU 2 - Yellow"),
                       "Amazon"  = c("amazon_SKU 1 - Blue","amazon_SKU 2 - Yellow"),
                       "Digital" = c("rachio_SKU 1 - Blue","rachio_SKU 2 - Yellow",
                                     "weatherflow_SKU 1 - Blue","weatherflow_SKU 2 - Yellow")
    )
    cols_SBFs <- switch(input$grouped_skus_channel,
                        "All"     = c("dtc_SKU 3 - Blue w/ Solar","dtc_SKU 4 - Yellow w/ Solar",
                                      "amazon_SKU 3 - Blue w/ Solar","amazon_SKU 4 - Yellow w/ Solar",
                                      "rachio_SKU 3 - Blue w/ Solar","rachio_SKU 4 - Yellow w/ Solar",
                                      "weatherflow_SKU 3 - Blue w/ Solar","weatherflow_SKU 4 - Yellow w/ Solar"),
                        "DTC"     = c("dtc_SKU 3 - Blue w/ Solar","dtc_SKU 4 - Yellow w/ Solar"),
                        "Amazon"  = c("amazon_SKU 3 - Blue w/ Solar","amazon_SKU 4 - Yellow w/ Solar"),
                        "Digital" = c("rachio_SKU 3 - Blue w/ Solar","rachio_SKU 4 - Yellow w/ Solar",
                                      "weatherflow_SKU 3 - Blue w/ Solar","weatherflow_SKU 4 - Yellow w/ Solar")
    )
    cols_HBF  <- if (input$grouped_skus_channel %in% c("All","DTC")) "dtc_SKU 5 - HBF" else character(0)
    cols_HBFs <- if (input$grouped_skus_channel %in% c("All","DTC")) "dtc_SKU 6 - HBF w/ Solar" else character(0)
    
    # row-sum vectors (missing-safe)
    SBF_vec   <- sum_existing_rows(df, cols_SBF)
    SBFs_vec  <- sum_existing_rows(df, cols_SBFs)
    HBF_vec   <- sum_existing_rows(df, cols_HBF)
    HBFs_vec  <- sum_existing_rows(df, cols_HBFs)
    
    df_daily <- df |>
      dplyr::mutate(
        SBF         = SBF_vec,
        `SBF Solar` = SBFs_vec,
        HBF         = HBF_vec,
        `HBF Solar` = HBFs_vec
      ) |>
      dplyr::group_by(Date) |>
      dplyr::summarise(
        dplyr::across(c(SBF, `SBF Solar`, HBF, `HBF Solar`), ~ sum(.x, na.rm = TRUE)),
        .groups = "drop"
      ) |>
      tidyr::pivot_longer(c(SBF, `SBF Solar`, HBF, `HBF Solar`),
                          names_to = "Group", values_to = "Count")
    
    df_sum <- if (by_month) {
      df_daily |>
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) |>
        dplyr::group_by(Month, Group) |>
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") |>
        dplyr::rename(Date = Month)
    } else df_daily
    
    # Fix factor levels AFTER roll-up; then filter by selection
    df_sum <- df_sum |>
      dplyr::mutate(Group = factor(Group, levels = c("SBF","SBF Solar","HBF","HBF Solar"))) |>
      dplyr::filter(Group %in% input$grouped_skus_groups)
    
    cols4 <- c("SBF"="#2ecc71","SBF Solar"="#3498db","HBF"="#7b868c","HBF Solar"="#e74c3c")
    
    if (input$grouped_skus_view == "Absolute") {
      df_abs <- df_sum |>
        dplyr::mutate(Tooltip = paste0("<b>", format(Date, tip_fmt),
                                       "</b><br>", Group, ": ", Count, " units"))
      
      if (want_lines()) {
        p <- plotly::plot_ly(df_abs, x=~Date, y=~Count, color=~Group,
                             colors=cols4, type="scatter", mode="lines+markers",
                             hovertext=~Tooltip, hoverinfo="text", textposition="none")
      } else {
        p <- plotly::plot_ly()
        for (g in unique(df_abs$Group)) {
          g_chr <- as.character(g)
          p <- p |>
            plotly::add_bars(data=dplyr::filter(df_abs, Group==g),
                             x=~Date, y=~Count, name=g_chr,
                             marker=list(color=cols4[g_chr]),
                             hovertext=~Tooltip, hoverinfo="text", textposition="none")
        }
        p <- p |> plotly::layout(barmode="group")
      }
      
    } else {
      totals <- df_sum |>
        dplyr::group_by(Date) |>
        dplyr::summarise(DayTotal = sum(Count), .groups="drop")
      
      df_rel <- dplyr::left_join(df_sum, totals, by="Date") |>
        dplyr::mutate(
          Share = dplyr::if_else(DayTotal==0, 0, Count/DayTotal),
          Tooltip = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                           Group, ": ", round(Share*100,1), " % (", Count, " units)")
        )
      
      overall <- df_rel |>
        dplyr::group_by(Group) |>
        dplyr::summarise(Total=sum(Count), .groups="drop") |>
        dplyr::mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), as.character(overall$Group))
      
      p <- plotly::plot_ly()
      for (g in unique(df_rel$Group)) {
        g_chr <- as.character(g)
        p <- p |>
          plotly::add_bars(data=dplyr::filter(df_rel, Group==g),
                           x=~Date, y=~Share,
                           name=paste0(g_chr," (",pct[g_chr],"%)"),
                           marker=list(color=cols4[g_chr]),
                           hovertext=~Tooltip, hoverinfo="text", textposition="none")
      }
      p <- p |> plotly::layout(barmode="stack", yaxis=list(tickformat=".0%"))
    }
    
    p |>
      plotly::layout(
        legend=list(orientation="h", x=0.5, y=1.15, xanchor="center"),
        margin=list(l=40,r=20,t=20,b=60),
        plot_bgcolor="#ffffff", paper_bgcolor="#ffffff",
        font=list(family="Montserrat"),
        xaxis=list(
          title="",
          tickfont=list(family="Montserrat", size=14),
          tickformat=if (by_month) "%b %Y" else "%b %d"
        ),
        yaxis=list(
          title="",
          tickfont=list(family="Montserrat", size=14)
        )
      )
  }
  
  
  ## ---------- 1.  Which add‑on view is active?  -------------------
  current_addon_view <- reactive({
    if (isTRUE(input$by_colour_addon)) "colour" else "group"
  })
  
  ## ---------- 2.  Global “line chart” toggle for add‑ons ----------
  want_lines_addon <- reactive({
    isTRUE(input$line_view) && (
      (current_addon_view() == "group"  && input$grouped_addons_view == "Absolute") ||
        (current_addon_view() == "colour" && input$addon_view          == "Absolute")
    )
  })
  
  ## ---------- 3.  Compact (top bar) selectors ---------------------
  output$compact_addon_filters <- renderUI({
    switch(current_addon_view(),
           "group" = tagList(
             selectInput("grouped_addons_channel", NULL,
                         c(All="All", DTC="DTC", Amazon="Amazon"),
                         selected="All", width="120px"),
             selectInput("grouped_addons_view", NULL,
                         c(Absolute="Absolute", Relative="Relative"),
                         selected="Absolute", width="110px")
           ),
           "colour" = tagList(
             selectInput("addon_channel", NULL,
                         c(All="All", DTC="DTC", Amazon="Amazon"),
                         selected="All", width="120px"),
             selectInput("addon_view", NULL,
                         c(Absolute="Absolute", Relative="Relative"),
                         selected="Absolute", width="110px")
           )
    )
  })
  
  ## ---------- 4.  2nd‑row long selectors --------------------------
  output$long_addon_filters <- renderUI({
    switch(current_addon_view(),
           "group" = selectizeInput("grouped_addons_groups", NULL,
                                    c("Wall Mount","Suet Ball Holder","3-in-1 Nutrition Set",
                                      "Solar Roof Single","Perch Extender",
                                      "Solar Roof (HBF)","Housing – only (HBF)"),
                                    selected = c("Wall Mount","Suet Ball Holder","3-in-1 Nutrition Set",
                                                 "Solar Roof Single","Perch Extender",
                                                 "Solar Roof (HBF)","Housing – only (HBF)"),
                                    multiple = TRUE, width = "800px",
                                    options  = list(plugins=list("remove_button"))),
           "colour" = selectizeInput("selected_addons", NULL,
                                     c("Wall Mount","Suet Ball Holder",
                                       "3-in-1 Nutrition Set – Blue","3-in-1 Nutrition Set – Yellow",
                                       "Solar Roof Single – Blue","Solar Roof Single – Yellow",
                                       "Perch Extender – Blue","Perch Extender – Yellow",
                                       "Solar Roof (HBF)","Housing – only (HBF)"),
                                     selected = c("Wall Mount","Suet Ball Holder",
                                                  "3-in-1 Nutrition Set – Blue","3-in-1 Nutrition Set – Yellow",
                                                  "Solar Roof Single – Blue","Solar Roof Single – Yellow",
                                                  "Perch Extender – Blue","Perch Extender – Yellow",
                                                  "Solar Roof (HBF)","Housing – only (HBF)"),
                                     multiple = TRUE, width = "800px",
                                     options  = list(plugins=list("remove_button")))
    )
  })
  
  # Missing-safe row sums for a set of columns
  sum_existing_rows <- function(data, cols) {
    keep <- intersect(cols, names(data))
    if (length(keep) == 0) rep(0, nrow(data)) else rowSums(data[keep], na.rm = TRUE)
  }
  
  ## ---------- 5.  Unified plot output -----------------------------
  output$addon_plot <- renderPlotly({
    switch(current_addon_view(),
           "group"  = addon_group_plot(),
           "colour" = addon_colour_plot()
    )
  })
  
  ## =================================================================
  ## 5.1  Add‑on GROUP view  (no colour split)
  ## =================================================================
  addon_group_plot <- function() {
    req(input$selected_date_range, input$grouped_addons_channel,
        input$grouped_addons_groups, input$grouped_addons_view)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    df <- revenue_data |>
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) |>
      dplyr::mutate(Date = as.Date(Date))
    
    # Channel-specific column sets (robust to missing cols)
    pick <- function(dtc, amz) {
      switch(input$grouped_addons_channel,
             "All"    = c(dtc, amz),
             "DTC"    = dtc,
             "Amazon" = amz
      )
    }
    
    cols_WM   <- pick("dtc_Wall Mount",                          "amazon_Wall Mount")
    cols_SBH  <- pick("dtc_Suet Ball Holder",                    "amazon_Suet Ball Holder")
    cols_NS   <- pick(c("dtc_3-in-1 Nutrition Set - Blue",  "dtc_3-in-1 Nutrition Set - Yellow"),
                      c("amazon_3-in-1 Nutrition Set - Blue","amazon_3-in-1 Nutrition Set - Yellow"))
    cols_SRS  <- pick(c("dtc_Solar Roof Single - Blue",     "dtc_Solar Roof Single - Yellow"),
                      c("amazon_Solar Roof Single - Blue",  "amazon_Solar Roof Single - Yellow"))
    cols_PE   <- pick(c("dtc_Perch Extender - Blue",        "dtc_Perch Extender - Yellow"),
                      c("amazon_Perch Extender - Blue",     "amazon_Perch Extender - Yellow"))
    cols_HBFs <- if (input$grouped_addons_channel %in% c("All","DTC")) "dtc_Solar Roof (HBF)"        else character(0)
    cols_HHBF <- if (input$grouped_addons_channel %in% c("All","DTC")) "dtc_Housing - only (HBF)"   else character(0)
    
    # Daily counts (missing-safe)
    df_daily <- df |>
      dplyr::mutate(
        `Wall Mount`             = sum_existing_rows(df, cols_WM),
        `Suet Ball Holder`       = sum_existing_rows(df, cols_SBH),
        `3-in-1 Nutrition Set`   = sum_existing_rows(df, cols_NS),
        `Solar Roof Single`      = sum_existing_rows(df, cols_SRS),
        `Perch Extender`         = sum_existing_rows(df, cols_PE),
        `Solar Roof (HBF)`       = sum_existing_rows(df, cols_HBFs),
        `Housing – only (HBF)`   = sum_existing_rows(df, cols_HHBF)
      ) |>
      dplyr::group_by(Date) |>
      dplyr::summarise(dplyr::across(where(is.numeric), ~ sum(.x, na.rm = TRUE)), .groups = "drop") |>
      tidyr::pivot_longer(-Date, names_to = "Addon", values_to = "Count") |>
      dplyr::filter(Addon %in% input$grouped_addons_groups)
    
    
    df_sum <- if (by_month) {
      df_daily |>
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) |>
        dplyr::group_by(Month, Addon) |>
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") |>
        dplyr::rename(Date = Month)
    } else df_daily
    
    # Stable palette (subset automatically)
    cols_addon <- c(
      "Wall Mount"            = "#2ecc71",
      "Suet Ball Holder"      = "#3498db",
      "3-in-1 Nutrition Set"  = "#9b59b6",
      "Solar Roof Single"     = "#f1c40f",
      "Perch Extender"        = "#e74c3c",
      "Solar Roof (HBF)"      = "#7b868c",
      "Housing – only (HBF)"  = "#34495e"
    )
    pal <- cols_addon[names(cols_addon) %in% unique(df_sum$Addon)]
    
    if (input$grouped_addons_view == "Absolute") {
      df_abs <- df_sum |>
        dplyr::mutate(Tooltip = paste0("<b>", format(Date, tip_fmt),
                                       "</b><br>", Addon, ": ", Count, " add-ons"))
      if (want_lines_addon()) {
        p <- plotly::plot_ly(df_abs, x=~Date, y=~Count, color=~Addon,
                             colors=pal, type="scatter", mode="lines+markers",
                             hovertext=~Tooltip, hoverinfo="text", textposition="none")
      } else {
        p <- plotly::plot_ly()
        for (g in names(pal)) {
          p <- p |>
            plotly::add_bars(data=dplyr::filter(df_abs, Addon==g),
                             x=~Date, y=~Count, name=g,
                             marker=list(color=pal[g]),
                             hovertext=~Tooltip, hoverinfo="text", textposition="none")
        }
        p <- p |> plotly::layout(barmode="group")
      }
    } else {
      totals <- df_sum |>
        dplyr::group_by(Date) |>
        dplyr::summarise(DayTotal = sum(Count), .groups="drop")
      df_rel <- dplyr::left_join(df_sum, totals, by="Date") |>
        dplyr::mutate(
          Share = ifelse(DayTotal==0, 0, Count/DayTotal),
          Tooltip = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                           Addon, ": ", round(Share*100,1), "% (", Count, " add-ons)")
        )
      overall <- df_rel |>
        dplyr::group_by(Addon) |>
        dplyr::summarise(Total = sum(Count), .groups="drop") |>
        dplyr::mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$Addon)
      
      p <- plotly::plot_ly()
      for (g in names(pal)) {
        p <- p |>
          plotly::add_bars(data=dplyr::filter(df_rel, Addon==g),
                           x=~Date, y=~Share,
                           name=paste0(g," (",pct[g],"%)"),
                           marker=list(color=pal[g]),
                           hovertext=~Tooltip, hoverinfo="text", textposition="none")
      }
      p <- p |> plotly::layout(barmode="stack", yaxis=list(tickformat=".0%"))
    }
    
    p |>
      plotly::layout(
        legend=list(orientation="h", x=0.5, y=1.15, xanchor="center"),
        margin=list(l=40,r=20,t=20,b=60),
        plot_bgcolor="#ffffff", paper_bgcolor="#ffffff",
        font=list(family="Montserrat"),
        xaxis=list(title="", tickfont=list(family="Montserrat", size=14),
                   tickformat=if (by_month) "%b %Y" else "%b %d"),
        yaxis=list(title="", tickfont=list(family="Montserrat", size=14))
      )
  }
  
  
  ## =================================================================
  ## 5.2  Add‑on COLOUR view  (Blue / Yellow variants kept separate)
  ## =================================================================
  addon_colour_plot <- function() {
    req(input$selected_date_range, input$addon_channel, input$addon_view, input$selected_addons)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    df <- revenue_data |>
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) |>
      dplyr::mutate(Date = as.Date(Date))
    
    sel_cols <- switch(input$addon_channel,
                       "All" = grep("^(dtc|amazon)_(Wall Mount|Suet Ball Holder|3-in-1 Nutrition Set - Blue|3-in-1 Nutrition Set - Yellow|Solar Roof Single - Blue|Solar Roof Single - Yellow|Perch Extender - Blue|Perch Extender - Yellow|Solar Roof \\(HBF\\)|Housing - only \\(HBF\\))",
                                    names(df), value = TRUE),
                       "DTC"    = grep("^dtc_(Wall Mount|Suet Ball Holder|3-in-1 Nutrition Set - Blue|3-in-1 Nutrition Set - Yellow|Solar Roof Single - Blue|Solar Roof Single - Yellow|Perch Extender - Blue|Perch Extender - Yellow|Solar Roof \\(HBF\\)|Housing - only \\(HBF\\))",
                                       names(df), value = TRUE),
                       "Amazon" = grep("^amazon_(Wall Mount|Suet Ball Holder|3-in-1 Nutrition Set - Blue|3-in-1 Nutrition Set - Yellow|Solar Roof Single - Blue|Solar Roof Single - Yellow|Perch Extender - Blue|Perch Extender - Yellow|Solar Roof \\(HBF\\)|Housing - only \\(HBF\\))",
                                       names(df), value = TRUE)
    )
    
    if (length(sel_cols) == 0) {
      return(plotly::plot_ly() |>
               plotly::layout(
                 annotations = list(list(
                   text = "No add-on columns found for this channel.",
                   xref = "paper", yref = "paper", x = 0.5, y = 0.5,
                   showarrow = FALSE, font = list(family = "Montserrat", size = 14)
                 )),
                 margin = list(l = 40, r = 20, t = 20, b = 60),
                 paper_bgcolor = "#ffffff", plot_bgcolor = "#ffffff",
                 font = list(family = "Montserrat")
               ))
    }
    
    df_long <- df |>
      tidyr::pivot_longer(all_of(sel_cols), names_to = "col", values_to = "Count") |>
      dplyr::mutate(AddOn = dplyr::case_when(
        grepl("Wall Mount", col)                    ~ "Wall Mount",
        grepl("Suet Ball Holder", col)              ~ "Suet Ball Holder",
        grepl("3-in-1 Nutrition Set - Blue", col)   ~ "3-in-1 Nutrition Set – Blue",
        grepl("3-in-1 Nutrition Set - Yellow", col) ~ "3-in-1 Nutrition Set – Yellow",
        grepl("Solar Roof Single - Blue", col)      ~ "Solar Roof Single – Blue",
        grepl("Solar Roof Single - Yellow", col)    ~ "Solar Roof Single – Yellow",
        grepl("Perch Extender - Blue", col)         ~ "Perch Extender – Blue",
        grepl("Perch Extender - Yellow", col)       ~ "Perch Extender – Yellow",
        grepl("Solar Roof \\(HBF\\)", col)          ~ "Solar Roof (HBF)",
        grepl("Housing - only \\(HBF\\)", col)      ~ "Housing – only (HBF)",
        TRUE                                        ~ NA_character_
      )) |>
      dplyr::filter(!is.na(AddOn), AddOn %in% input$selected_addons) |>
      dplyr::group_by(Date, AddOn) |>
      dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop")
    
    if (by_month) {
      df_long <- df_long |>
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) |>
        dplyr::group_by(Month, AddOn) |>
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") |>
        dplyr::rename(Date = Month)
    }
    
    # Stable colours per exact label
    cols_addon_col <- c(
      "Wall Mount"                      = "#2ecc71",
      "Suet Ball Holder"                = "#3498db",
      "3-in-1 Nutrition Set – Blue"     = "#8e44ad",
      "3-in-1 Nutrition Set – Yellow"   = "#9b59b6",
      "Solar Roof Single – Blue"        = "#2980b9",
      "Solar Roof Single – Yellow"      = "#f1c40f",
      "Perch Extender – Blue"           = "#16a085",
      "Perch Extender – Yellow"         = "#27ae60",
      "Solar Roof (HBF)"                = "#7b868c",
      "Housing – only (HBF)"            = "#34495e"
    )
    pal <- cols_addon_col[names(cols_addon_col) %in% unique(df_long$AddOn)]
    
    if (input$addon_view == "Absolute") {
      df_abs <- df_long |>
        dplyr::mutate(Tooltip = paste0("<b>", format(Date, tip_fmt),
                                       "</b><br>", AddOn, ": ", Count, " add-ons"))
      if (want_lines_addon()) {
        p <- plotly::plot_ly(df_abs, x=~Date, y=~Count, color=~AddOn,
                             colors=pal, type="scatter", mode="lines+markers",
                             hovertext=~Tooltip, hoverinfo="text", textposition="none")
      } else {
        p <- plotly::plot_ly()
        for (g in names(pal)) {
          p <- p |>
            plotly::add_bars(data=dplyr::filter(df_abs, AddOn==g),
                             x=~Date, y=~Count, name=g,
                             marker=list(color=pal[g]),
                             hovertext=~Tooltip, hoverinfo="text", textposition="none")
        }
        p <- p |> plotly::layout(barmode="group")
      }
    } else {
      totals <- df_long |>
        dplyr::group_by(Date) |>
        dplyr::summarise(DayTotal = sum(Count), .groups="drop")
      df_rel <- dplyr::left_join(df_long, totals, by="Date") |>
        dplyr::mutate(
          Share = dplyr::if_else(DayTotal==0, 0, Count/DayTotal),
          Tooltip = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                           AddOn, ": ", round(Share*100,1), " % (", Count, " add-ons)")
        )
      overall <- df_rel |>
        dplyr::group_by(AddOn) |>
        dplyr::summarise(Total = sum(Count), .groups="drop") |>
        dplyr::mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$AddOn)
      
      p <- plotly::plot_ly()
      for (g in names(pal)) {
        p <- p |>
          plotly::add_bars(data=dplyr::filter(df_rel, AddOn==g),
                           x=~Date, y=~Share,
                           name=paste0(g," (",pct[g],"%)"),
                           marker=list(color=pal[g]),
                           hovertext=~Tooltip, hoverinfo="text", textposition="none")
      }
      p <- p |> plotly::layout(barmode="stack", yaxis=list(tickformat=".0%"))
    }
    
    p |>
      plotly::layout(
        legend=list(orientation="h", x=0.5, y=1.15, xanchor="center"),
        margin=list(l=40,r=20,t=20,b=60),
        plot_bgcolor="#ffffff", paper_bgcolor="#ffffff",
        font=list(family="Montserrat"),
        xaxis=list(title="", tickfont=list(family="Montserrat", size=14),
                   tickformat=if (by_month) "%b %Y" else "%b %d"),
        yaxis=list(title="", tickfont=list(family="Montserrat", size=14))
      )
  }
  
  
  output$seed_selector_ui <- renderUI({
    if (isTRUE(input$seed_by_weight)) {
      choices <- c("Seasonal Curation - 8lb",  "Seasonal Curation - 20lb",
                   "Buddy Bites - 8lb",        "Buddy Bites - 20lb",
                   "Snack n' Soar - 8lb",      "Snack n' Soar - 20lb",
                   "Avian Choice - 8lb",       "Avian Choice - 20lb")
      
    } else {
      choices <- c("Seasonal Curation", "Buddy Bites",
                   "Snack n' Soar", "Avian Choice")
      
    }
    
    selectizeInput(
      "selected_seeds", NULL,
      choices  = choices,
      selected = choices,
      multiple = TRUE,
      width = "650px",
      options = list(plugins = list("remove_button"))
    )
  })
  
  want_lines_seed <- reactive({
    isTRUE(input$seed_line_view) && input$seed_view_mode == "Absolute"
  })
  
  output$seed_plot <- renderPlotly({
    req(input$selected_date_range,
        input$seed_view_mode,
        input$selected_seeds)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # --- 1) base data ----------------------------------------------------------
    df <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::mutate(Date = as.Date(Date))
    
    # Long: only DTC seed columns
    long <- df %>%
      dplyr::select(Date, dplyr::matches("^dtc_")) %>%
      tidyr::pivot_longer(-Date, names_to = "Seed", values_to = "Count") %>%
      dplyr::mutate(Seed = sub("^dtc_", "", Seed))
    
    # Grouping logic: by weight vs by brand
    if (isTRUE(input$seed_by_weight)) {
      long <- long %>%
        dplyr::filter(Seed %in% input$selected_seeds)
    } else {
      long <- long %>%
        dplyr::mutate(Brand = gsub(" - (8lb|20lb)", "", Seed)) %>%
        dplyr::filter(Brand %in% input$selected_seeds) %>%
        dplyr::group_by(Date, Seed = Brand) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop")
    }
    
    # --- 2) ordering + palette -------------------------------------------------
    ordered_levels <- if (isTRUE(input$seed_by_weight)) {
      c("Seasonal Curation - 8lb", "Seasonal Curation - 20lb",
        "Buddy Bites - 8lb",       "Buddy Bites - 20lb",
        "Snack n' Soar - 8lb",     "Snack n' Soar - 20lb",
        "Avian Choice - 8lb",      "Avian Choice - 20lb")
    } else {
      c("Seasonal Curation", "Buddy Bites", "Snack n' Soar", "Avian Choice")
    }
    
    long$Seed <- factor(long$Seed, levels = ordered_levels)
    
    seed_levels <- intersect(ordered_levels, unique(as.character(long$Seed)))
    pal <- setNames(scales::hue_pal()(length(seed_levels)), seed_levels)
    
    # If no data after filtering, show a friendly message
    if (nrow(long) == 0 || length(seed_levels) == 0) {
      return(
        plotly::plot_ly() %>%
          plotly::layout(
            annotations = list(list(
              text = "No seed data for the current filters.",
              xref = "paper", yref = "paper", x = 0.5, y = 0.5,
              showarrow = FALSE, font = list(family = "Montserrat", size = 14)
            )),
            margin = list(l = 40, r = 20, t = 20, b = 60),
            paper_bgcolor = "#ffffff", plot_bgcolor = "#ffffff",
            font = list(family = "Montserrat")
          )
      )
    }
    
    # --- 3) optional monthly roll-up ------------------------------------------
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Seed) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    # --- 4) Absolute / Relative -----------------------------------------------
    if (input$seed_view_mode == "Absolute") {
      
      long <- long %>%
        dplyr::mutate(TT = paste0(
          "<b>", format(Date, tip_fmt), "</b><br>",
          Seed, ": ", Count, " bags"
        ))
      
      if (want_lines_seed()) {
        p <- plotly::plot_ly(
          long, x = ~Date, y = ~Count,
          color = ~Seed, colors = pal,
          type = "scatter", mode = "lines+markers",
          hoverinfo = "text", hovertext = ~TT
        )
      } else {
        p <- plotly::plot_ly(type = "bar")
        for (s in names(pal)) {
          p <- p %>%
            plotly::add_bars(
              data = dplyr::filter(long, Seed == s),
              x = ~Date, y = ~Count, name = s,
              marker = list(color = pal[s]),
              hoverinfo = "text", hovertext = ~TT
            )
        }
        p <- p %>% plotly::layout(barmode = "group")
      }
      
    } else {
      rel <- long %>%
        dplyr::group_by(Date) %>%
        dplyr::mutate(
          Total = sum(Count),
          Share = dplyr::if_else(Total == 0, 0, Count / Total),
          TT = paste0(
            "<b>", format(Date, tip_fmt), "</b><br>",
            Seed, ": ", round(Share * 100, 1), "% (", Count, " bags)"
          )
        ) %>%
        dplyr::ungroup()
      
      # legend percentages (overall)
      leg <- rel %>%
        dplyr::group_by(Seed) %>%
        dplyr::summarise(Total = sum(Count), .groups = "drop") %>%
        dplyr::mutate(Pct = round(Total / sum(Total) * 100, 1))
      
      p <- plotly::plot_ly(type = "bar")
      for (s in names(pal)) {
        pct_lbl <- leg$Pct[leg$Seed == s]
        nm <- if (length(pct_lbl) == 1) paste0(s, " (", pct_lbl, "%)") else s
        p <- p %>%
          plotly::add_bars(
            data = dplyr::filter(rel, Seed == s),
            x = ~Date, y = ~Share,
            name = nm,
            marker = list(color = pal[s]),
            hoverinfo = "text", hovertext = ~TT
          )
      }
      p <- p %>% plotly::layout(barmode = "stack",
                                yaxis = list(tickformat = ".0%"))
    }
    
    # --- 5) common layout ------------------------------------------------------
    p %>% plotly::layout(
      legend = list(
        orientation = "h", x = 0.5, y = 1.15, xanchor = "center",
        font = list(family = "Montserrat")
      ),
      margin = list(l = 40, r = 20, t = 20, b = 60),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff",
      font = list(family = "Montserrat"),
      xaxis = list(
        title = "",
        tickfont = list(family = "Montserrat", size = 14),
        tickformat = if (by_month) "%b %Y" else "%b %d"
      ),
      yaxis = list(
        title = "",
        tickfont = list(family = "Montserrat", size = 14)
      )
    )
  })
  
  ## --- helper: first date where segmented (Nq*/Oq*) data actually appears ---
  seg_start_date <- reactive({
    seg_cols <- names(survey_data)[grepl("^(Nq[123]_|Oq[123]_)", names(survey_data))]
    if (length(seg_cols) == 0) return(NA_Date_)
    
    tmp <- survey_data %>%
      dplyr::mutate(SegSum = rowSums(dplyr::across(dplyr::all_of(seg_cols)), na.rm = TRUE)) %>%
      dplyr::filter(SegSum > 0)
    
    if (nrow(tmp) == 0) NA_Date_ else min(as.Date(tmp$Date))
  })
  
  ## show dropdown only if selected range includes any day >= seg_start_date
  seg_picker_visible <- reactive({
    req(input$selected_date_range)
    sd <- seg_start_date()
    !is.na(sd) && (input$selected_date_range[2] >= sd)
  })
  
  ## right-aligned dropdown in header
  output$seg_picker <- renderUI({
    if (!seg_picker_visible()) return(NULL)
    div(
      selectInput(
        inputId = "survey_segment",
        label   = NULL,
        choices = c("All Customers" = "all",
                    "New Customers" = "new",
                    "Returning Customers" = "ret"),
        selected = "all",
        width = "240px"
      ),
      style = "min-width:240px;"
    )
  })
  
  ## right-aligned dropdown in header stays the same …
  
  ## convenience: current segment (defaults to "all" if picker not shown)
  current_segment <- reactive({
    if (!seg_picker_visible()) return("all")
    seg <- input$survey_segment
    if (is.null(seg)) "all" else seg
  })
  
  ## helpers to pick columns and strip prefixes for Q1–Q3 based on segment
  cols_for <- function(q) {
    seg <- current_segment()  # <-- NO isolate()
    pat <- switch(seg,
                  "all" = paste0("^", q, "_"),
                  "new" = paste0("^N", q, "_"),
                  "ret" = paste0("^O", q, "_"))
    grep(pat, names(survey_data), value = TRUE)
  }
  
  strip_label <- function(q, x) {
    seg <- current_segment()  # <-- NO isolate()
    pat <- switch(seg,
                  "all" = paste0("^", q, "_"),
                  "new" = paste0("^N", q, "_"),
                  "ret" = paste0("^O", q, "_"))
    sub(pat, "", x)
  }
  
  
  
  overall_engagement_rate <- reactive({
    req(input$selected_date_range)
    
    # Q1 columns
    q1_cols <- grep("^q1_", names(survey_data), value = TRUE)
    
    # Participants total in range
    total_participants <- survey_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      summarise(Total = sum(across(all_of(q1_cols), ~ sum(.x, na.rm = TRUE)), na.rm = TRUE)) %>%
      pull(Total)
    
    # Orders total in range
    total_orders <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      summarise(Total = sum(DTC_Orders, na.rm = TRUE)) %>%
      pull(Total)
    
    # Engagement rate
    if (total_orders > 0) {
      round(total_participants / total_orders * 100, 1) # percentage
    } else {
      0
    }
  })
  output$overview_title <- renderText({
    rate <- overall_engagement_rate()
    paste0("Overview (Engagement Rate: ", rate, "%)")
  })
  
  ## ────────────────────────────────────────────────────────────────────
  ## Layout: 3-up grid vs single wide view (no duplicate output IDs)
  ## ────────────────────────────────────────────────────────────────────
  ## ────────────────────────────────────────────────────────────────────
  ## Layout: grid vs single wide (no duplicate output IDs)
  ## ────────────────────────────────────────────────────────────────────
  output$survey_layout <- renderUI({
    req(input$survey_view)
    view <- input$survey_view
    
    if (view == "All") {
      # ===== 3-column grid; 6 cards (Q1–Q6) =====
      div(style = "display:grid; grid-template-columns: repeat(3, 1fr); gap:20px;",
          
          # Q1
          div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q1: Where did you hear about Bird Buddy?",
                     style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
                  actionButton("expand_q1", "⤢ Wide", title="Expand",
                               style="border:none; background:none; font-size:14px;")
              ),
              plotlyOutput("q1_pie_chart")
          ),
          
          # Q2
          div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q2: Where on FB/IG have you heard about Bird Buddy?",
                     style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
                  actionButton("expand_q2", "⤢ Wide", title="Expand",
                               style="border:none; background:none; font-size:14px;")
              ),
              plotlyOutput("q2_pie_chart")
          ),
          
          # Q3
          div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q3: Who is this for?",
                     style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
                  actionButton("expand_q3", "⤢ Wide", title="Expand",
                               style="border:none; background:none; font-size:14px;")
              ),
              plotlyOutput("q3_pie_chart")
          ),
          
          # Q4
          div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q4: Are you a new or existing customer?",
                     style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
                  actionButton("expand_q4", "⤢ Wide", title="Expand",
                               style="border:none; background:none; font-size:14px;")
              ),
              plotlyOutput("q4_pie_chart")
          ),
          
          # Q5
          div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q5: Did you buy this for your household?",
                     style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
                  actionButton("expand_q5", "⤢ Wide", title="Expand",
                               style="border:none; background:none; font-size:14px;")
              ),
              plotlyOutput("q5_pie_chart")
          ),
          
          # Q6
          div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
              div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
                  h4("Q6: Did you buy this as a gift?",
                     style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
                  actionButton("expand_q6", "⤢ Wide", title="Expand",
                               style="border:none; background:none; font-size:14px;")
              ),
              plotlyOutput("q6_pie_chart")
          )
      )
      
    } else {
      # ===== Single wide =====
      title <- switch(view,
                      "Q1" = "Q1: Where did you hear about Bird Buddy?",
                      "Q2" = "Q2: Where on FB/IG have you heard about Bird Buddy?",
                      "Q3" = "Q3: Who is this for?",
                      "Q4" = "Q4: Are you a new or existing customer?",
                      "Q5" = "Q5: Did you buy this for your household?",
                      "Q6" = "Q6: Did you buy this as a gift?"
      )
      out <- switch(view,
                    "Q1" = plotlyOutput("q1_pie_chart"),
                    "Q2" = plotlyOutput("q2_pie_chart"),
                    "Q3" = plotlyOutput("q3_pie_chart"),
                    "Q4" = plotlyOutput("q4_pie_chart"),
                    "Q5" = plotlyOutput("q5_pie_chart"),
                    "Q6" = plotlyOutput("q6_pie_chart")
      )
      
      div(style="background:#fff; border-radius:20px; padding:20px; box-shadow:0 0 10px rgba(0,0,0,.05);",
          div(style="display:flex; justify-content:space-between; align-items:center; margin-bottom:8px;",
              h4(title, style="font-family: Montserrat; font-weight:bold; color:#7b868c; margin:0;"),
              actionButton("back_all", "⤺ Back", title="Back",
                           style="border:none; background:none; font-size:14px;")
          ),
          out
      )
    }
  })
  
  ## Buttons to flip the controller input
  observeEvent(input$expand_q1, { updateSelectInput(session, "survey_view", selected = "Q1") }, ignoreInit = TRUE)
  observeEvent(input$expand_q2, { updateSelectInput(session, "survey_view", selected = "Q2") }, ignoreInit = TRUE)
  observeEvent(input$expand_q3, { updateSelectInput(session, "survey_view", selected = "Q3") }, ignoreInit = TRUE)
  observeEvent(input$expand_q4, { updateSelectInput(session, "survey_view", selected = "Q4") }, ignoreInit = TRUE)
  observeEvent(input$expand_q5, { updateSelectInput(session, "survey_view", selected = "Q5") }, ignoreInit = TRUE)
  observeEvent(input$expand_q6, { updateSelectInput(session, "survey_view", selected = "Q6") }, ignoreInit = TRUE)
  observeEvent(input$back_all,  { updateSelectInput(session, "survey_view", selected = "All") }, ignoreInit = TRUE)
  
  ## helper: whether we're in wide mode (unchanged)
  is_wide <- reactive({ req(input$survey_view); input$survey_view != "All" })
  
  
  # Q1 pie (segmented)
  output$q1_pie_chart <- renderPlotly({
    req(input$selected_date_range, input$survey_view)
    req(current_segment())
    
    q_cols <- cols_for("q1")
    if (length(q_cols) == 0) q_cols <- grep("^q1_", names(survey_data), value = TRUE) # safe fallback
    
    df <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(dplyr::all_of(q_cols)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE))) %>%
      tidyr::pivot_longer(dplyr::everything(), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(
        Channel    = strip_label("q1", Channel),
        Percentage = Count / sum(Count),
        LabelShown = ifelse(Percentage >= 0.05,
                            paste0(Channel, "<br>", scales::percent(Percentage, accuracy = 0.1)),
                            ""),
        HoverLabel = paste0(Channel, ": ", Count)
      )
    
    plot_ly(
      df, labels = ~Channel, values = ~Count, type = "pie",
      domain = list(x = c(0.15, 0.85), y = c(0.10, 0.90)),
      textinfo = "text", textposition = "auto", text = ~LabelShown,
      hovertext = ~HoverLabel, hoverinfo = "text",
      insidetextfont  = list(family = "Montserrat", size = 14),
      outsidetextfont = list(family = "Montserrat", size = 11),
      marker = list(
        colors = RColorBrewer::brewer.pal(min(8, nrow(df)), "Set2"),
        line   = list(color = "#FFFFFF", width = 2)
      ),
      height = 400
    ) %>%
      layout(showlegend = FALSE,
             margin = list(t = 20, b = 20, l = 80, r = 80),
             font = list(family = "Montserrat"))
  })
  
  # Q2 pie (segmented)
  output$q2_pie_chart <- renderPlotly({
    req(input$selected_date_range, input$survey_view)
    req(current_segment())
    
    q_cols <- cols_for("q2")
    if (length(q_cols) == 0) q_cols <- grep("^q2_", names(survey_data), value = TRUE)
    
    df <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(dplyr::all_of(q_cols)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE))) %>%
      tidyr::pivot_longer(dplyr::everything(), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(
        Channel    = strip_label("q2", Channel),
        Percentage = Count / sum(Count),
        LabelShown = ifelse(Percentage >= 0.05,
                            paste0(Channel, "<br>", scales::percent(Percentage, accuracy = 0.1)),
                            ""),
        HoverLabel = paste0(Channel, ": ", Count)
      )
    
    plot_ly(
      df, labels = ~Channel, values = ~Count, type = "pie",
      domain = list(x = c(0.15, 0.85), y = c(0.10, 0.90)),
      textinfo = "text", textposition = "auto", text = ~LabelShown,
      hovertext = ~HoverLabel, hoverinfo = "text",
      insidetextfont  = list(family = "Montserrat", size = 14),
      outsidetextfont = list(family = "Montserrat", size = 11),
      marker = list(
        colors = RColorBrewer::brewer.pal(min(8, nrow(df)), "Set2"),
        line   = list(color = "#FFFFFF", width = 2)
      ),
      height = 400
    ) %>%
      layout(showlegend = FALSE,
             margin = list(t = 20, b = 20, l = 80, r = 80),
             font = list(family = "Montserrat"))
  })
  
  # Q3 pie (segmented)
  output$q3_pie_chart <- renderPlotly({
    req(input$selected_date_range, input$survey_view)
    req(current_segment())
    
    q_cols <- cols_for("q3")
    if (length(q_cols) == 0) q_cols <- grep("^q3_", names(survey_data), value = TRUE)
    
    df <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(dplyr::all_of(q_cols)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE))) %>%
      tidyr::pivot_longer(dplyr::everything(), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(
        Channel    = strip_label("q3", Channel),
        Percentage = Count / sum(Count),
        LabelShown = ifelse(Percentage >= 0.05,
                            paste0(Channel, "<br>", scales::percent(Percentage, accuracy = 0.1)),
                            ""),
        HoverLabel = paste0(Channel, ": ", Count)
      )
    
    plot_ly(
      df, labels = ~Channel, values = ~Count, type = "pie",
      domain = list(x = c(0.15, 0.85), y = c(0.10, 0.90)),
      textinfo = "text", textposition = "auto", text = ~LabelShown,
      hovertext = ~HoverLabel, hoverinfo = "text",
      insidetextfont  = list(family = "Montserrat", size = 14),
      outsidetextfont = list(family = "Montserrat", size = 11),
      marker = list(
        colors = RColorBrewer::brewer.pal(min(8, nrow(df)), "Set2"),
        line   = list(color = "#FFFFFF", width = 2)
      ),
      height = 400
    ) %>%
      layout(showlegend = FALSE,
             margin = list(t = 20, b = 20, l = 80, r = 80),
             font = list(family = "Montserrat"))
  })
  
  
  # Q4
  output$q4_pie_chart <- renderPlotly({
    req(input$selected_date_range, input$survey_view)
    
    # Pick up all q4_* columns
    q4_cols <- grep("^q4_", names(survey_data), value = TRUE)
    
    # Filter by date range
    filtered <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    # Aggregate & reshape
    df <- filtered %>%
      dplyr::select(dplyr::all_of(q4_cols)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE))) %>%
      tidyr::pivot_longer(dplyr::everything(), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(
        Channel    = gsub("^q4_", "", Channel),
        Percentage = Count / sum(Count),
        LabelShown = ifelse(
          Percentage >= 0.05,
          paste0(Channel, "<br>", scales::percent(Percentage, accuracy = 0.1)),
          ""
        ),
        HoverLabel = paste0(Channel, ": ", Count)
      )
    
    h <- if (!is.null(input$survey_view) && input$survey_view != "All") 400 else 400
    
    plot_ly(
      df,
      labels = ~Channel,
      values = ~Count,
      type   = "pie",
      domain = list(x = c(0.15, 0.85), y = c(0.10, 0.90)),
      textinfo        = "text",
      textposition    = "auto",
      text            = ~LabelShown,
      hovertext       = ~HoverLabel,
      hoverinfo       = "text",
      insidetextfont  = list(family = "Montserrat", size = 14),
      outsidetextfont = list(family = "Montserrat", size = 11),
      marker = list(
        colors = RColorBrewer::brewer.pal(min(8, nrow(df)), "Set2"),
        line   = list(color = "#FFFFFF", width = 2)
      ),
      height = h
    ) %>%
      layout(
        showlegend = FALSE,
        margin = list(t = 20, b = 20, l = 80, r = 80),
        font   = list(family = "Montserrat")
      )
  })
  
  # Q5
  output$q5_pie_chart <- renderPlotly({
    req(input$selected_date_range, input$survey_view)
    
    # Pick up all q5_* columns
    q5_cols <- grep("^q5_", names(survey_data), value = TRUE)
    
    # Filter by date range
    filtered <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    # Aggregate & reshape
    df <- filtered %>%
      dplyr::select(dplyr::all_of(q5_cols)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE))) %>%
      tidyr::pivot_longer(dplyr::everything(), names_to = "Response", values_to = "Count") %>%
      dplyr::mutate(
        Response   = gsub("^q5_", "", Response),
        Percentage = Count / sum(Count),
        LabelShown = ifelse(
          Percentage >= 0.05,
          paste0(Response, "<br>", scales::percent(Percentage, accuracy = 0.1)),
          ""
        ),
        HoverLabel = paste0(Response, ": ", Count)
      )
    
    h <- if (!is.null(input$survey_view) && input$survey_view != "All") 400 else 400
    
    plot_ly(
      df,
      labels = ~Response,
      values = ~Count,
      type   = "pie",
      domain = list(x = c(0.15, 0.85), y = c(0.10, 0.90)),
      textinfo        = "text",
      textposition    = "auto",
      text            = ~LabelShown,
      hovertext       = ~HoverLabel,
      hoverinfo       = "text",
      insidetextfont  = list(family = "Montserrat", size = 14),
      outsidetextfont = list(family = "Montserrat", size = 11),
      marker = list(
        colors = RColorBrewer::brewer.pal(min(8, nrow(df)), "Set2"),
        line   = list(color = "#FFFFFF", width = 2)
      ),
      height = h
    ) %>%
      layout(
        showlegend = FALSE,
        margin = list(t = 20, b = 20, l = 80, r = 80),
        font   = list(family = "Montserrat")
      )
  })
  
  # Q6
  output$q6_pie_chart <- renderPlotly({
    req(input$selected_date_range, input$survey_view)
    
    # Pick up all q6_* columns
    q6_cols <- grep("^q6_", names(survey_data), value = TRUE)
    
    # Filter by date range
    filtered <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2])
    
    # Aggregate & reshape
    df <- filtered %>%
      dplyr::select(dplyr::all_of(q6_cols)) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE))) %>%
      tidyr::pivot_longer(dplyr::everything(), names_to = "Response", values_to = "Count") %>%
      dplyr::mutate(
        Response   = gsub("^q6_", "", Response),
        Percentage = Count / sum(Count),
        LabelShown = ifelse(
          Percentage >= 0.05,
          paste0(Response, "<br>", scales::percent(Percentage, accuracy = 0.1)),
          ""
        ),
        HoverLabel = paste0(Response, ": ", Count)
      )
    
    h <- if (!is.null(input$survey_view) && input$survey_view != "All") 400 else 400
    
    plot_ly(
      df,
      labels = ~Response,
      values = ~Count,
      type   = "pie",
      domain = list(x = c(0.15, 0.85), y = c(0.10, 0.90)),
      textinfo        = "text",
      textposition    = "auto",
      text            = ~LabelShown,
      hovertext       = ~HoverLabel,
      hoverinfo       = "text",
      insidetextfont  = list(family = "Montserrat", size = 14),
      outsidetextfont = list(family = "Montserrat", size = 11),
      marker = list(
        colors = RColorBrewer::brewer.pal(min(8, nrow(df)), "Set2"),
        line   = list(color = "#FFFFFF", width = 2)
      ),
      height = h
    ) %>%
      layout(
        showlegend = FALSE,
        margin = list(t = 20, b = 20, l = 80, r = 80),
        font   = list(family = "Montserrat")
      )
  })
  
  
  output$q1_engagement_bar <- renderPlotly({
    req(input$selected_date_range)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # Columns for Q1 answers
    q1_cols <- grep("^q0_", names(survey_data), value = TRUE)
    
    # Aggregate survey participants by day
    daily_participants <- survey_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      group_by(Date) %>%
      summarise(
        Participants = sum(across(all_of(q1_cols), ~ sum(.x, na.rm = TRUE))),
        .groups = "drop"
      )
    
    # Get DTC orders for the same dates
    daily_orders <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      select(Date, DTC_Orders)
    
    # Merge and calculate engagement rate
    daily_data <- daily_participants %>%
      left_join(daily_orders, by = "Date") %>%
      mutate(EngagementRate = if_else(DTC_Orders > 0, Participants / DTC_Orders, 0))
    
    # Optional monthly roll-up
    if (by_month) {
      daily_data <- daily_data %>%
        mutate(Month = lubridate::floor_date(Date, "month")) %>%
        group_by(Month) %>%
        summarise(
          Participants = sum(Participants, na.rm = TRUE),
          DTC_Orders   = sum(DTC_Orders, na.rm = TRUE),
          EngagementRate = if_else(DTC_Orders > 0, Participants / DTC_Orders, 0),
          .groups = "drop"
        ) %>%
        rename(Date = Month)
    }
    
    # Plotly bar chart
    plot_ly(
      data = daily_data,
      x = ~Date,
      y = ~EngagementRate,
      type = "bar",
      marker = list(color = "#d3d3d3"),
      hoverinfo = "text",
      hovertext = ~paste0(
        "<b>", format(Date, tip_fmt), "</b><br>",
        "Engagement Rate: ", round(EngagementRate * 100, 1), "%<br>",
        "Participants: ", Participants, "<br>",
        "DTC Orders: ", DTC_Orders
      )
    ) %>%
      layout(
        yaxis = list(tickformat = ".0%", title = "Engagement Rate"),
        xaxis = list(
          title = "",
          tickformat = if (by_month) "%b %Y" else "%b %d",
          automargin = TRUE
        ),
        showlegend = FALSE,
        margin = list(t = 40, b = 40, l = 60, r = 30),
        font = list(family = "Montserrat"),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  
  

  # Q1 stacked % (segmented)
  output$q1_daily_stack <- renderPlotly({
    req(input$selected_date_range)
    req(current_segment())
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    cols <- cols_for("q1")
    if (length(cols) == 0) cols <- grep("^q1_", names(survey_data), value = TRUE)
    
    long <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(Date, dplyr::all_of(cols)) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::all_of(cols), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(Channel = strip_label("q1", Channel))
    
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Channel) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    rel <- long %>%
      dplyr::group_by(Date) %>%
      dplyr::mutate(
        Total = sum(Count, na.rm = TRUE),
        Share = dplyr::if_else(Total == 0, 0, Count / Total),
        TT = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                    Channel, ": ", round(Share*100,1), "% (", Count, " responses)")
      ) %>% dplyr::ungroup()
    
    leg <- rel %>%
      dplyr::group_by(Channel) %>%
      dplyr::summarise(TT = sum(Count, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(Pct = round(TT / sum(TT) * 100, 1))
    
    cats <- sort(unique(rel$Channel))
    base <- RColorBrewer::brewer.pal(8, "Set2")
    pal  <- if (length(cats) <= 8) base[seq_len(length(cats))] else grDevices::colorRampPalette(base)(length(cats))
    names(pal) <- cats
    
    p <- plot_ly(type = "bar", height = 700)
    for (s in names(pal)) {
      p <- p %>% add_bars(
        data = dplyr::filter(rel, Channel == s),
        x = ~Date, y = ~Share,
        name = paste0(s, " (", leg$Pct[leg$Channel==s], "%)"),
        marker = list(color = pal[s]),
        hoverinfo = "text", hovertext = ~TT
      )
    }
    
    p %>% layout(
      barmode = "stack",
      yaxis = list(tickformat = ".0%", range = c(0,1), title = "Share of responses"),
      xaxis = list(title = "", tickformat = if (by_month) "%b %Y" else "%b %d", automargin = TRUE),
      legend = list(orientation = "h", y = 1.12, x = 0.5, xanchor = "center"),
      margin = list(t = 40, b = 40, l = 60, r = 30),
      font = list(family = "Montserrat"),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff"
    )
  })
  
  # Q2 stacked % (segmented)
  output$q2_daily_stack <- renderPlotly({
    req(input$selected_date_range)
    req(current_segment())
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    cols <- cols_for("q2")
    if (length(cols) == 0) cols <- grep("^q2_", names(survey_data), value = TRUE)
    
    long <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(Date, dplyr::all_of(cols)) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::all_of(cols), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(Channel = strip_label("q2", Channel))
    
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Channel) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    rel <- long %>%
      dplyr::group_by(Date) %>%
      dplyr::mutate(
        Total = sum(Count, na.rm = TRUE),
        Share = dplyr::if_else(Total == 0, 0, Count / Total),
        TT = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                    Channel, ": ", round(Share*100,1), "% (", Count, " responses)")
      ) %>% dplyr::ungroup()
    
    leg <- rel %>%
      dplyr::group_by(Channel) %>%
      dplyr::summarise(TT = sum(Count, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(Pct = round(TT / sum(TT) * 100, 1))
    
    cats <- sort(unique(rel$Channel))
    base <- RColorBrewer::brewer.pal(8, "Set2")
    pal  <- if (length(cats) <= 8) base[seq_len(length(cats))] else grDevices::colorRampPalette(base)(length(cats))
    names(pal) <- cats
    
    p <- plot_ly(type = "bar", height = 700)
    for (s in names(pal)) {
      p <- p %>% add_bars(
        data = dplyr::filter(rel, Channel == s),
        x = ~Date, y = ~Share,
        name = paste0(s, " (", leg$Pct[leg$Channel==s], "%)"),
        marker = list(color = pal[s]),
        hoverinfo = "text", hovertext = ~TT
      )
    }
    
    p %>% layout(
      barmode = "stack",
      yaxis = list(tickformat = ".0%", range = c(0,1), title = "Share of responses"),
      xaxis = list(title = "", tickformat = if (by_month) "%b %Y" else "%b %d", automargin = TRUE),
      legend = list(orientation = "h", y = 1.12, x = 0.5, xanchor = "center"),
      margin = list(t = 40, b = 40, l = 60, r = 30),
      font = list(family = "Montserrat"),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff"
    )
  })
  
  # Q3 stacked % (segmented)
  output$q3_daily_stack <- renderPlotly({
    req(input$selected_date_range)
    req(current_segment())
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    cols <- cols_for("q3")
    if (length(cols) == 0) cols <- grep("^q3_", names(survey_data), value = TRUE)
    
    long <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(Date, dplyr::all_of(cols)) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE)), .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::all_of(cols), names_to = "Channel", values_to = "Count") %>%
      dplyr::mutate(Channel = strip_label("q3", Channel))
    
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Channel) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    rel <- long %>%
      dplyr::group_by(Date) %>%
      dplyr::mutate(
        Total = sum(Count, na.rm = TRUE),
        Share = dplyr::if_else(Total == 0, 0, Count / Total),
        TT = paste0("<b>", format(Date, tip_fmt), "</b><br>",
                    Channel, ": ", round(Share*100,1), "% (", Count, " responses)")
      ) %>% dplyr::ungroup()
    
    leg <- rel %>%
      dplyr::group_by(Channel) %>%
      dplyr::summarise(TT = sum(Count, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(Pct = round(TT / sum(TT) * 100, 1))
    
    cats <- sort(unique(rel$Channel))
    base <- RColorBrewer::brewer.pal(8, "Set2")
    pal  <- if (length(cats) <= 8) base[seq_len(length(cats))] else grDevices::colorRampPalette(base)(length(cats))
    names(pal) <- cats
    
    p <- plot_ly(type = "bar", height = 700)
    for (s in names(pal)) {
      p <- p %>% add_bars(
        data = dplyr::filter(rel, Channel == s),
        x = ~Date, y = ~Share,
        name = paste0(s, " (", leg$Pct[leg$Channel==s], "%)"),
        marker = list(color = pal[s]),
        hoverinfo = "text", hovertext = ~TT
      )
    }
    
    p %>% layout(
      barmode = "stack",
      yaxis = list(tickformat = ".0%", range = c(0,1), title = "Share of responses"),
      xaxis = list(title = "", tickformat = if (by_month) "%b %Y" else "%b %d", automargin = TRUE),
      legend = list(orientation = "h", y = 1.12, x = 0.5, xanchor = "center"),
      margin = list(t = 40, b = 40, l = 60, r = 30),
      font = list(family = "Montserrat"),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff"
    )
  })
  
  
  output$q4_daily_stack <- renderPlotly({
    req(input$selected_date_range)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # 1) Q4 columns
    cols <- grep("^q4_", names(survey_data), value = TRUE)
    
    # 2) Prep daily long data
    long <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(Date, dplyr::all_of(cols)) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE)),
                       .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::all_of(cols),
                          names_to = "Category", values_to = "Count") %>%
      dplyr::mutate(Category = gsub("^q4_", "", Category))
    
    # 3) Optional monthly roll-up
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Category) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    # 4) Relative (100% stacked)
    rel <- long %>%
      dplyr::group_by(Date) %>%
      dplyr::mutate(
        Total = sum(Count, na.rm = TRUE),
        Share = dplyr::if_else(Total == 0, 0, Count / Total),
        TT = paste0(
          "<b>", format(Date, tip_fmt), "</b><br>",
          Category, ": ", round(Share * 100, 1), "% (", Count, " responses)"
        )
      ) %>%
      dplyr::ungroup()
    
    # 5) Legend percentages over selected window
    leg <- rel %>%
      dplyr::group_by(Category) %>%
      dplyr::summarise(TT = sum(Count, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(Pct = round(TT / sum(TT) * 100, 1))
    
    # 6) Palette
    cats <- sort(unique(rel$Category))
    base <- RColorBrewer::brewer.pal(8, "Set2")
    pal  <- if (length(cats) <= 8) base[seq_len(length(cats))]
    else grDevices::colorRampPalette(base)(length(cats))
    names(pal) <- cats
    
    # 7) Build stacked % bars
    p <- plot_ly(type = "bar", height = 700)
    for (s in names(pal)) {
      p <- p %>% add_bars(
        data = dplyr::filter(rel, Category == s),
        x = ~Date,
        y = ~Share,
        name = paste0(s, " (", leg$Pct[leg$Category == s], "%)"),
        marker = list(color = pal[s]),
        hoverinfo = "text",
        hovertext = ~TT
      )
    }
    
    p %>% layout(
      barmode = "stack",
      yaxis = list(tickformat = ".0%", range = c(0, 1), title = "Share of responses"),
      xaxis = list(
        title = "",
        tickformat = if (by_month) "%b %Y" else "%b %d",
        automargin = TRUE
      ),
      legend = list(orientation = "h", y = 1.12, x = 0.5, xanchor = "center"),
      margin = list(t = 40, b = 40, l = 60, r = 30),
      font = list(family = "Montserrat"),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff"
    )
  })
  
  output$q5_daily_stack <- renderPlotly({
    req(input$selected_date_range)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # 1) Q5 columns
    cols <- grep("^q5_", names(survey_data), value = TRUE)
    
    # 2) Prep daily long data
    long <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(Date, dplyr::all_of(cols)) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE)),
                       .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::all_of(cols),
                          names_to = "Category", values_to = "Count") %>%
      dplyr::mutate(Category = gsub("^q5_", "", Category))
    
    # 3) Optional monthly roll-up
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Category) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    # 4) Relative (100% stacked)
    rel <- long %>%
      dplyr::group_by(Date) %>%
      dplyr::mutate(
        Total = sum(Count, na.rm = TRUE),
        Share = dplyr::if_else(Total == 0, 0, Count / Total),
        TT = paste0(
          "<b>", format(Date, tip_fmt), "</b><br>",
          Category, ": ", round(Share * 100, 1), "% (", Count, " responses)"
        )
      ) %>%
      dplyr::ungroup()
    
    # 5) Legend percentages over selected window
    leg <- rel %>%
      dplyr::group_by(Category) %>%
      dplyr::summarise(TT = sum(Count, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(Pct = round(TT / sum(TT) * 100, 1))
    
    # 6) Palette
    cats <- sort(unique(rel$Category))
    base <- RColorBrewer::brewer.pal(8, "Set2")
    pal  <- if (length(cats) <= 8) base[seq_len(length(cats))]
    else grDevices::colorRampPalette(base)(length(cats))
    names(pal) <- cats
    
    # 7) Build stacked % bars
    p <- plot_ly(type = "bar", height = 700)
    for (s in names(pal)) {
      p <- p %>% add_bars(
        data = dplyr::filter(rel, Category == s),
        x = ~Date,
        y = ~Share,
        name = paste0(s, " (", leg$Pct[leg$Category == s], "%)"),
        marker = list(color = pal[s]),
        hoverinfo = "text",
        hovertext = ~TT
      )
    }
    
    p %>% layout(
      barmode = "stack",
      yaxis = list(tickformat = ".0%", range = c(0, 1), title = "Share of responses"),
      xaxis = list(
        title = "",
        tickformat = if (by_month) "%b %Y" else "%b %d",
        automargin = TRUE
      ),
      legend = list(orientation = "h", y = 1.12, x = 0.5, xanchor = "center"),
      margin = list(t = 40, b = 40, l = 60, r = 30),
      font = list(family = "Montserrat"),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff"
    )
  })
  
  output$q6_daily_stack <- renderPlotly({
    req(input$selected_date_range)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # 1) Q6 columns
    cols <- grep("^q6_", names(survey_data), value = TRUE)
    
    # 2) Prep daily long data
    long <- survey_data %>%
      dplyr::filter(Date >= input$selected_date_range[1],
                    Date <= input$selected_date_range[2]) %>%
      dplyr::select(Date, dplyr::all_of(cols)) %>%
      dplyr::group_by(Date) %>%
      dplyr::summarise(dplyr::across(dplyr::everything(), ~ sum(.x, na.rm = TRUE)),
                       .groups = "drop") %>%
      tidyr::pivot_longer(cols = dplyr::all_of(cols),
                          names_to = "Category", values_to = "Count") %>%
      dplyr::mutate(Category = gsub("^q6_", "", Category))
    
    # 3) Optional monthly roll-up
    if (by_month) {
      long <- long %>%
        dplyr::mutate(Month = lubridate::floor_date(Date, "month")) %>%
        dplyr::group_by(Month, Category) %>%
        dplyr::summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop") %>%
        dplyr::rename(Date = Month)
    }
    
    # 4) Relative (100% stacked)
    rel <- long %>%
      dplyr::group_by(Date) %>%
      dplyr::mutate(
        Total = sum(Count, na.rm = TRUE),
        Share = dplyr::if_else(Total == 0, 0, Count / Total),
        TT = paste0(
          "<b>", format(Date, tip_fmt), "</b><br>",
          Category, ": ", round(Share * 100, 1), "% (", Count, " responses)"
        )
      ) %>%
      dplyr::ungroup()
    
    # 5) Legend percentages over selected window
    leg <- rel %>%
      dplyr::group_by(Category) %>%
      dplyr::summarise(TT = sum(Count, na.rm = TRUE), .groups = "drop") %>%
      dplyr::mutate(Pct = round(TT / sum(TT) * 100, 1))
    
    # 6) Palette
    cats <- sort(unique(rel$Category))
    base <- RColorBrewer::brewer.pal(8, "Set2")
    pal  <- if (length(cats) <= 8) base[seq_len(length(cats))]
    else grDevices::colorRampPalette(base)(length(cats))
    names(pal) <- cats
    
    # 7) Build stacked % bars
    p <- plot_ly(type = "bar", height = 700)
    for (s in names(pal)) {
      p <- p %>% add_bars(
        data = dplyr::filter(rel, Category == s),
        x = ~Date,
        y = ~Share,
        name = paste0(s, " (", leg$Pct[leg$Category == s], "%)"),
        marker = list(color = pal[s]),
        hoverinfo = "text",
        hovertext = ~TT
      )
    }
    
    p %>% layout(
      barmode = "stack",
      yaxis = list(tickformat = ".0%", range = c(0, 1), title = "Share of responses"),
      xaxis = list(
        title = "",
        tickformat = if (by_month) "%b %Y" else "%b %d",
        automargin = TRUE
      ),
      legend = list(orientation = "h", y = 1.12, x = 0.5, xanchor = "center"),
      margin = list(t = 40, b = 40, l = 60, r = 30),
      font = list(family = "Montserrat"),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff"
    )
  })
  
  output$app_subs_by_channel_plot <- renderPlotly({
    req(input$selected_date_range, input$appsubs_channel, input$appsubs_view)
    
    by_month <- isTRUE(input$viz_by_month)
    tip_fmt  <- if (by_month) "%b %Y" else "%b %d, %Y"
    
    # Colors: Monthly (lilac), Yearly (yellow)
    pal <- c("Monthly" = "#C8A2C8", "Yearly" = "#F1C40F")
    
    legend_layout <- list(
      orientation = "h",
      x = 0.5, y = 1.15, xanchor = "center",
      font = list(family = "Montserrat", size = 14),
      title = list(text = NULL)
    )
    
    # Filter by date
    df0 <- revenue_data %>%
      dplyr::filter(Date >= input$selected_date_range[1], Date <= input$selected_date_range[2]) %>%
      dplyr::mutate(Date = as.Date(Date))
    
    # Pull columns; if missing, treat as zeros
    get_col <- function(nm) if (nm %in% names(df0)) df0[[nm]] else rep(0, nrow(df0))
    
    dtc_y  <- get_col("DTC_Subscription_Units")
    a_m    <- get_col("apple_monthly_sub")
    a_y    <- get_col("apple_yearly_sub")
    g_m    <- get_col("google_monthly_sub")
    g_y    <- get_col("google_yearly_sub")
    
    # Build per-selection Monthly/Yearly
    sel <- switch(
      input$appsubs_channel,
      "All" = list(Monthly = a_m + g_m, Yearly = dtc_y + a_y + g_y),
      "DTC" = list(Monthly = rep(0, nrow(df0)), Yearly = dtc_y),
      "Apple" = list(Monthly = a_m, Yearly = a_y),
      "Google" = list(Monthly = g_m, Yearly = g_y)
    )
    
    # Optionally aggregate by month (same switch as your other viz)
    if (by_month) {
      tmp <- tibble::tibble(
        Date = as.Date(cut(df0$Date, "month")),
        Monthly = sel$Monthly,
        Yearly  = sel$Yearly
      ) |>
        dplyr::group_by(Date) |>
        dplyr::summarise(Monthly = sum(Monthly, na.rm = TRUE),
                         Yearly  = sum(Yearly,  na.rm = TRUE), .groups = "drop")
    } else {
      tmp <- tibble::tibble(Date = df0$Date, Monthly = sel$Monthly, Yearly = sel$Yearly)
    }
    
    # Long form
    df_long <- tmp |>
      tidyr::pivot_longer(cols = c("Monthly", "Yearly"), names_to = "Category", values_to = "Count") |>
      dplyr::mutate(
        Category = factor(Category, levels = c("Monthly", "Yearly")),
        X = if (by_month) forcats::fct_inorder(format(Date, "%b %Y")) else Date
      )
    
    # Relative or Absolute
    if (input$appsubs_view == "Relative") {
      df_long <- df_long |>
        dplyr::group_by(Date) |>
        dplyr::mutate(Total = sum(Count, na.rm = TRUE),
                      Perc  = dplyr::if_else(Total > 0, Count / Total, 0)) |>
        dplyr::ungroup()
    }
    
    # Tooltips
    df_long <- df_long |>
      dplyr::mutate(
        Tooltip = if (input$appsubs_view == "Relative") {
          paste0("<b>", format(Date, tip_fmt), "</b><br>",
                 Category, "<br>Share: ", round(Perc * 100, 1), "%")
        } else {
          paste0("<b>", format(Date, tip_fmt), "</b><br>",
                 Category, "<br>Subs: ", format(round(Count, 0), big.mark = ","))
        }
      )
    
    # Plot
    if (input$appsubs_view == "Absolute") {
      if (isTRUE(input$appsubs_line_view)) {
        # Lines (hide zero series so DTC doesn't show a flat monthly line)
        df_nz <- dplyr::filter(df_long, Count > 0)
        p <- ggplot2::ggplot(df_nz,
                             ggplot2::aes(x = Date, y = Count, color = Category, group = Category, text = Tooltip)
        ) +
          ggplot2::geom_line(size = 1) +
          ggplot2::geom_point(size = 2) +
          ggplot2::scale_color_manual(values = pal, drop = FALSE) +
          ggplot2::scale_x_date(
            date_breaks = if (by_month) "1 month" else "5 days",
            date_labels = if (by_month) "%b %Y" else "%b %d"
          ) +
          ggplot2::theme_minimal(base_family = "Montserrat") +
          ggplot2::theme(
            axis.text.x  = ggplot2::element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y  = ggplot2::element_text(size = 12),
            panel.border = ggplot2::element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background  = ggplot2::element_rect(fill = "#ffffff", color = NA),
            panel.background = ggplot2::element_rect(fill = "#ffffff", color = NA)
          )
        
        plotly::ggplotly(p, tooltip = "text") %>%
          plotly::layout(
            barmode = "group",  # side-by-side bars
            bargap = 0.25,      # small gap between groups
            hovermode = "x unified",
            legend = legend_layout,
            margin = list(l = 40, r = 20, t = 20, b = 60),
            plot_bgcolor  = "#ffffff",
            paper_bgcolor = "#ffffff",
            xaxis = list(title = NULL),
            yaxis = list(title = "Subscriptions")
          )
        
      } else {
        plotly::plot_ly() %>%
          plotly::add_bars(
            data = df_long %>% dplyr::filter(Category == "Monthly"),
            x = ~X, y = ~Count, name = "Monthly",
            marker = list(color = pal[["Monthly"]]),
            hovertext = ~Tooltip, hoverinfo = "text"
          ) %>%
          plotly::add_bars(
            data = df_long %>% dplyr::filter(Category == "Yearly"),
            x = ~X, y = ~Count, name = "Yearly",
            marker = list(color = pal[["Yearly"]]),
            hovertext = ~Tooltip, hoverinfo = "text"
          ) %>%
          plotly::layout(
            barmode = "group",  # side-by-side bars
            bargap = 0.25,      # small gap between groups
            hovermode = "x unified",
            legend = legend_layout,
            margin = list(l = 40, r = 20, t = 20, b = 60),
            plot_bgcolor  = "#ffffff",
            paper_bgcolor = "#ffffff",
            xaxis = list(title = NULL),
            yaxis = list(title = "Subscriptions")
          )
        
      }
    } else {
      plotly::plot_ly() %>%
        plotly::add_bars(
          data = df_long %>% dplyr::filter(Category == "Monthly"),
          x = ~X, y = ~Perc, name = "Monthly",
          marker = list(color = pal[["Monthly"]]),
          hovertext = ~Tooltip, hoverinfo = "text"
        ) %>%
        plotly::add_bars(
          data = df_long %>% dplyr::filter(Category == "Yearly"),
          x = ~X, y = ~Perc, name = "Yearly",
          marker = list(color = pal[["Yearly"]]),
          hovertext = ~Tooltip, hoverinfo = "text"
        ) %>%
        plotly::layout(
          barmode = "stack",
          hovermode = "x unified",
          legend = legend_layout,
          margin = list(l = 40, r = 20, t = 20, b = 60),
          plot_bgcolor  = "#ffffff",
          paper_bgcolor = "#ffffff",
          xaxis = list(title = NULL),
          yaxis = list(title = "Share", tickformat = ".0%")
        )
    }
  })
  
  
  
}


# ---- Run App ----
# Run the application
shinyApp(ui = ui, server = server)

