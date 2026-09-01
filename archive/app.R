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


# ---- Authentication and Google Sheets Setup ----
# Include this so rsconnect picks it up


revenue_data <- readRDS("revenue_data.rds")
campaign_notes_df <- readRDS("campaign_notes_df.rds")
survey_data <- readRDS("survey_data.rds")
revenue_data[is.na(revenue_data)] <- 0



# ---- UI Definition ----
# UI Definition

ui <- dashboardPage(
  dashboardHeader(disable = TRUE),
  dashboardSidebar(
    width = 200, # Sidebar width
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
      menuItem("P&L Visualizations", tabName = "pnl_viz", icon = icon("chart-pie"))
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
    
    # Global Date Range Input (persistent across tabs)
    div(
      class = "date-select-container",
      style = "display: flex; justify-content: flex-end; padding: 15px;",
      dateRangeInput(
        inputId = "selected_date_range",
        label = "Select Date Range:",
        start = min(revenue_data$Date, na.rm = TRUE),
        end = max(revenue_data$Date, na.rm = TRUE),
        min = min(revenue_data$Date, na.rm = TRUE),
        max = max(revenue_data$Date, na.rm = TRUE),
        format = "yyyy-mm-dd",
        weekstart = 1
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
                    div("B2B Revenue", class = "green-title"),
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
                        strong("Blended CAC:"),
                        div(
                          span(
                            textOutput("blended_cac_output"),
                            style = "font-size: 24px; font-weight: bold;",
                            onclick = "Shiny.onInputChange('toggle_blended_cac', Math.random())"
                          )
                        )
                      ),
                      uiOutput("blended_cac_details")  # ← The new expandable content
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
                    div(style = "font-size: 14px; font-weight: bold; color: #7b868c;", "B2B Orders"),
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
                  choices = c("Total" = "Total", "DTC" = "DTC", "Amazon" = "Amazon", "App" = "App", "B2B" = "B2B"),
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
      <span style='color:#A52A2A;'>CAC</span> per Day
    </h2>"),
            
            # Dropdown on the right
            selectInput(
              inputId = "selected_cac_type",
              label = NULL,
              choices = c("Blended CAC" = "Blended_CAC",
                          "DTC CAC (wCAC)" = "wCAC",
                          "Amazon CAC (aCAC)" = "aCAC",
                          "App CAC (appCAC)" = "appCAC"),
              selected = "Blended_CAC",
              width = "250px"
            )
          ),
          
          # ---- Chart Container ----
          div(
            style = "background-color: white; border-radius: 20px; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.05);",
            plotlyOutput("blended_cac_bar_chart", height = "500px")
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
                    style = "display: flex; width: 650px; justify-content: space-between;",
                    div("DTC",    style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Amazon", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Rachio", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
                    div("Weatherflow", style = "font-size: 16px; font-weight: bold; text-align: center; width: 100px;"),
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
                          style = "display: flex; width: 650px; justify-content: space-between;",
                          
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
                          style = "display: flex; width: 650px; justify-content: space-between;",
                          
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
                          style = "display: flex; width: 650px; justify-content: space-between;",
                          
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
                          style = "display: flex; width: 650px; justify-content: space-between;",
                          
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
                          style = "display: flex; width: 650px; justify-content: space-between;",
                          
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
                          style = "display: flex; width: 650px; justify-content: space-between;",
                          
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
             width: 650px;
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
    
    
    
    # ROAS values
    blended_roas <- ifelse(total_spend == 0, NA, total_revenue / total_spend)
    wroas <- ifelse(dtc_spend == 0, NA, dtc_revenue / dtc_spend)
    aroas <- ifelse(amazon_spend == 0, NA, amazon_revenue / amazon_spend)
    approas <- ifelse(app_spend == 0, NA, app_revenue / app_spend)
    
    # CAC values based on your updated logic
    blended_cac <- ifelse(sum(filtered_data$Total_Orders, na.rm = TRUE) == 0, NA,
                          sum(filtered_data$Total_Spend, na.rm = TRUE) / sum(filtered_data$Total_Orders, na.rm = TRUE))
    wcac <- ifelse(sum(filtered_data$DTC_Orders, na.rm = TRUE) == 0, NA,
                   sum(filtered_data$Total_DTC_Spend, na.rm = TRUE) / sum(filtered_data$DTC_Orders, na.rm = TRUE))
    acac <- ifelse(sum(filtered_data$Amazon_Orders, na.rm = TRUE) == 0, NA,
                   sum(filtered_data$Amazon_Spend, na.rm = TRUE) / sum(filtered_data$Amazon_Orders, na.rm = TRUE))
    appcac <- ifelse(sum(filtered_data$App_Orders, na.rm = TRUE) == 0, NA,
                     sum(filtered_data$Total_App_Spend, na.rm = TRUE) / sum(filtered_data$App_Orders, na.rm = TRUE))
    
    
    # Weighted averages
    # New CR + AOV logic (based on orders)
    web_cr <- weighted.mean(filtered_data$Web_CR, w = filtered_data$DTC_Orders, na.rm = TRUE)
    web_aov <- mean(filtered_data$Web_AOV, na.rm = TRUE)
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
    
    
    current_summary$Blended_CAC <- blended_cac
    current_summary$wCAC <- wcac
    current_summary$aCAC <- acac
    current_summary$appCAC <- appcac
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
                        format(round(selected_data()$current$Target_Revenue, 2), nsmall = 2, big.mark = ","), " $")))
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
  
  # Blended CAC
  output$blended_cac_output <- renderText({
    paste0(format(round(selected_data()$current$Blended_CAC, 2), nsmall = 2, big.mark = ","), " $")
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
  # ---- Reactive Value for Blended CAC Visibility ----
  # Reactive toggle for CAC details
  blended_cac_visible <- reactiveVal(FALSE)
  
  observeEvent(input$toggle_blended_cac, {
    blended_cac_visible(!blended_cac_visible())
  })
  output$blended_cac_details <- renderUI({
    if (blended_cac_visible()) {
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
        div(HTML(paste0("<strong>wCAC:</strong> ", format(round(selected_data()$current$wCAC, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>aCAC:</strong> ", format(round(selected_data()$current$aCAC, 2), nsmall = 2), " $"))),
        div(HTML(paste0("<strong>appCAC:</strong> ", format(round(selected_data()$current$appCAC, 2), nsmall = 2), " $")))
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
        div(HTML(paste0("<strong>Seeds:</strong> ", format(round(selected_data()$current$DTC_Seeds_Units, 0), big.mark = ","), " units")))
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
        div(HTML(paste0("<strong>Target Orders:</strong> ", format(round(selected_data()$current$Target_Orders, 0), big.mark = ","))))
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
    view_mode <- input$selected_view_mode
    
    cols <- switch(selected_type,
                   "Total" = c("Total_Revenue", "Total_Spend"),
                   "DTC" = c("DTC_Revenue", "Total_DTC_Spend"),
                   "Amazon" = c("Amazon_Revenue", "Amazon_Spend"),
                   "App" = c("App_Revenue", "Total_App_Spend"),
                   "B2B" = c("B2B_Revenue", NA)  # No spend data for B2B
    )
    
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (is.na(cols[2])) {
      df <- df %>%
        select(Date, Revenue = all_of(cols[1])) %>%
        mutate(Spend = 0)  # Fill spend with 0s
    } else {
      df <- df %>%
        select(Date, Revenue = all_of(cols[1]), Spend = all_of(cols[2]))
    }
    
    
    if (view_mode == "Absolute") {
      df_long <- df %>%
        pivot_longer(cols = c(Revenue, Spend), names_to = "Metric", values_to = "Amount") %>%
        mutate(
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'><b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", Metric, ":</b> $", format(round(Amount, 2), big.mark = ",", nsmall = 2),
            "</span>"
          )
        )
      
      p <- ggplot(df_long, aes(x = Date, y = Amount, color = Metric, group = Metric, text = Tooltip)) +
        geom_line(size = 1.2) +
        geom_point(size = 2) +
        scale_color_manual(values = c("Revenue" = "#2ecc71", "Spend" = "#A52A2A")) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
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
      df <- df %>%
        mutate(
          Total = Revenue + Spend,
          Revenue_Perc = ifelse(Total == 0, 0, Revenue / Total),
          Spend_Perc = ifelse(Total == 0, 0, Spend / Total),
          Revenue_Label = paste0(
            "<b>", format(Date, "%b %d, %Y"), "</b><br>",
            "<span style='color:#2ecc71;'>Revenue: $", format(round(Revenue, 2), big.mark = ","), 
            " (", round(Revenue_Perc * 100, 1), "%)</span>"
          ),
          Spend_Label = paste0(
            "<b>", format(Date, "%b %d, %Y"), "</b><br>",
            "<span style='color:#A52A2A;'>Spend: $", format(round(Spend, 2), big.mark = ","), 
            " (", round(Spend_Perc * 100, 1), "%)</span>"
          )
        )
      
      plot_ly() %>%
        add_trace(
          data = df,
          x = ~Date, y = ~Revenue_Perc,
          type = 'scatter', mode = 'none',
          name = 'Revenue',
          stackgroup = 'one',
          fillcolor = 'rgba(46, 204, 113, 0.3)',
          line = list(color = '#2ecc71'),
          text = ~Revenue_Label,
          hoverinfo = 'text'
        ) %>%
        add_trace(
          data = df,
          x = ~Date, y = ~Spend_Perc,
          type = 'scatter', mode = 'none',
          name = 'Spend',
          stackgroup = 'one',
          fillcolor = 'rgba(165, 42, 42, 0.3)',
          line = list(color = '#A52A2A'),
          text = ~Spend_Label,
          hoverinfo = 'text'
        ) %>%
        layout(
          yaxis = list(
            title = "", tickformat = ".0%", tickfont = list(family = "Montserrat", size = 16),
            showline = TRUE, showgrid = TRUE
          ),
          xaxis = list(
            title = "", tickfont = list(family = "Montserrat", size = 16),
            showline = TRUE
          ),
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
    req(input$selected_date_range)
    req(input$selected_roas_type)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(
        Date = as.Date(Date),
        Blended_ROAS = ifelse(Total_Spend == 0, NA, Total_Revenue / Total_Spend),
        wROAS = ifelse(Total_DTC_Spend == 0, NA, DTC_Revenue / Total_DTC_Spend),
        aROAS = ifelse(Amazon_Spend == 0, NA, Amazon_Revenue / Amazon_Spend),
        appROAS = ifelse(Total_App_Spend == 0, NA, App_Revenue / Total_App_Spend)
      )
    
    selected_metric <- input$selected_roas_type
    
    plot_data <- filtered_data %>%
      select(Date, !!selected_metric) %>%
      rename(ROAS = !!selected_metric) %>%
      mutate(
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
          "<b>", gsub("_", " ", selected_metric), ":</b> ", round(ROAS, 2),
          "</span>"
        )
      )
    
    p <- ggplot(plot_data, aes(x = Date, y = ROAS, text = Tooltip)) +
      geom_col(fill = "#2ecc71", width = 0.6) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
      scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_family = "Montserrat") +
      theme_minimal(base_family = "Montserrat") +
      theme(
        plot.title = element_blank(),
        axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background = element_rect(fill = "#ffffff", color = NA),
        panel.background = element_rect(fill = "#ffffff", color = NA)
      )
    
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  output$returning_customer_output <- renderText({
    paste0(format(round(selected_data()$current$Returning_Customer_Rate * 100, 2), nsmall = 2), " %")
  })
  
  

  
  
  output$revenue_share_chart <- renderPlotly({
    req(input$selected_date_range)
    view_mode <- input$selected_revenue_view_mode
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (view_mode == "Absolute") {
      # ----- ABSOLUTE MODE: LINE CHART -----
      df_long <- filtered_data %>%
        select(Date, DTC_Revenue, Amazon_Revenue, Digital_Marketplaces_Revenue) %>%
        pivot_longer(cols = -Date, names_to = "Category", values_to = "Revenue") %>%
        mutate(
          Category = recode(Category,
                            DTC_Revenue = "DTC",
                            Amazon_Revenue = "Amazon",
                            Digital_Marketplaces_Revenue = "Digital Marketplaces"),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", Category, ":</b> $", format(round(Revenue, 2), big.mark = ","),
            "</span>"
          )
        )
      
      p <- ggplot(df_long, aes(x = Date, y = Revenue, color = Category, group = Category, text = Tooltip)) +
        geom_line(size = 1.2) +
        geom_point(size = 2) +
        scale_color_manual(values = c("DTC" = "#2ecc71", "Amazon" = "#3498db", "Digital Marketplaces" = "#f39c12")) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
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
            x = 0.5,
            y = 1.15,
            xanchor = "center",
            font = list(family = "Montserrat", size = 14),
            title = list(text = NULL)  # <-- Hides legend title
          ),
          font = list(family = "Montserrat")
        )
      
    } else {
      # ----- RELATIVE MODE (existing logic) -----
      filtered_data <- filtered_data %>%
        mutate(
          Total = DTC_Revenue + Amazon_Revenue + Digital_Marketplaces_Revenue,
          DTC_Perc = ifelse(Total == 0, 0, DTC_Revenue / Total),
          Amazon_Perc = ifelse(Total == 0, 0, Amazon_Revenue / Total),
          DM_Perc = ifelse(Total == 0, 0, Digital_Marketplaces_Revenue / Total),
          
          DTC_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#2ecc71;'>DTC Revenue: $", format(round(DTC_Revenue, 2), big.mark = ","), " (", round(DTC_Perc * 100, 1), "%)</span>"),
          Amazon_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#3498db;'>Amazon Revenue: $", format(round(Amazon_Revenue, 2), big.mark = ","), " (", round(Amazon_Perc * 100, 1), "%)</span>"),
          DM_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#f39c12;'>Digital Marketplaces Revenue: $", format(round(Digital_Marketplaces_Revenue, 2), big.mark = ","), " (", round(DM_Perc * 100, 1), "%)</span>")
        )
      
      plot_ly() %>%
        add_trace(data = filtered_data, x = ~Date, y = ~DTC_Perc, type = 'scatter', mode = 'none', name = 'DTC',
                  stackgroup = 'one', fillcolor = 'rgba(46, 204, 113, 0.3)', line = list(color = '#2ecc71'), text = ~DTC_Label, hoverinfo = 'text') %>%
        add_trace(data = filtered_data, x = ~Date, y = ~Amazon_Perc, type = 'scatter', mode = 'none', name = 'Amazon',
                  stackgroup = 'one', fillcolor = 'rgba(52, 152, 219, 0.3)', line = list(color = '#3498db'), text = ~Amazon_Label, hoverinfo = 'text') %>%
        add_trace(data = filtered_data, x = ~Date, y = ~DM_Perc, type = 'scatter', mode = 'none', name = 'Digital Marketplaces',
                  stackgroup = 'one', fillcolor = 'rgba(243, 156, 18, 0.3)', line = list(color = '#f39c12'), text = ~DM_Label, hoverinfo = 'text') %>%
        layout(
          yaxis = list(title = list(text = ""), tickformat = ".0%", tickfont = list(family = "Montserrat", size = 16)),
          xaxis = list(title = list(text = ""), tickfont = list(family = "Montserrat", size = 16)),
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
    
    view_mode <- input$selected_spend_view_mode
    spend_type <- input$selected_spend_composition
    
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1], Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (view_mode == "Absolute") {
      if (spend_type == "Total") {
        df_long <- df %>%
          select(Date, DTC = Total_DTC_Spend, Amazon = Amazon_Spend, App = Total_App_Spend, Fees) %>%
          pivot_longer(-Date, names_to = "Category", values_to = "Spend") %>%
          mutate(
            Tooltip = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
              "<b>", Category, ":</b> $", format(round(Spend, 2), big.mark = ","),
              "</span>"
            )
          )
        
        p <- ggplot(df_long, aes(x = Date, y = Spend, color = Category, group = Category, text = Tooltip)) +
          geom_line(size = 1.2) +
          geom_point(size = 2) +
          scale_color_manual(values = c("DTC" = "#A52A2A", "Amazon" = "#f39c12", "App" = "#9b59b6", "Fees" = "#34495e")) +
          scale_y_continuous(labels = scales::label_dollar()) +
          scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
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
        
        return(ggplotly(p, tooltip = "text") %>%
                 layout(
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   legend = list(
                     orientation = "h",
                     x = 0.5,
                     y = 1.15,
                     xanchor = "center",
                     font = list(family = "Montserrat", size = 14),
                     title = list(text = NULL)  # <-- Hides legend title
                   ),
                   font = list(family = "Montserrat")
                 ))
        
        
      } else if (spend_type == "DTC") {
        df_long <- df %>%
          select(Date,
                 Meta = Meta_Spend,
                 Google = Google_Spend,
                 Bing = Bing_Spend,
                 TikTok = TikTok_Spend,
                 Nextdoor = Nextdoor_Spend,
                 Affiliate = Affiliate_Fees) %>%
          pivot_longer(-Date, names_to = "Channel", values_to = "Spend") %>%
          mutate(
            Tooltip = paste0(
              "<span style='font-family: Montserrat;'>",
              "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
              "<b>", Channel, ":</b> $", format(round(Spend, 2), big.mark = ","),
              "</span>"
            )
          )
        
        p <- ggplot(df_long, aes(x = Date, y = Spend, color = Channel, group = Channel, text = Tooltip)) +
          geom_line(size = 1.2) +
          geom_point(size = 2) +
          scale_color_manual(values = c("Meta" = "#2ecc71", "Google" = "#3498db", "Bing" = "#9b59b6",
                                        "TikTok" = "#e74c3c", "Nextdoor" = "#f1c40f", "Affiliate" = "#34495e")) +
          scale_y_continuous(labels = scales::label_dollar()) +
          scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
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
        
        return(ggplotly(p, tooltip = "text") %>%
                 layout(
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   legend = list(
                     orientation = "h",
                     x = 0.5,
                     y = 1.15,
                     xanchor = "center",
                     font = list(family = "Montserrat", size = 14),
                     title = list(text = NULL)  # <-- Hides legend title
                   ),
                   font = list(family = "Montserrat")
                 ))
        
      }
    } else {
      if (spend_type == "Total") {
        df <- df %>%
          filter(!is.na(Total_Spend) & Total_Spend > 0) %>%
          mutate(
            DTC_Perc = Total_DTC_Spend / Total_Spend,
            Amazon_Perc = Amazon_Spend / Total_Spend,
            App_Perc = Total_App_Spend / Total_Spend,
            Fees_Perc = Fees / Total_Spend
          ) %>%
          rowwise() %>%
          mutate(
            Total_Percent = sum(c_across(ends_with("_Perc")), na.rm = TRUE),
            Scale_Factor = ifelse(Total_Percent > 1, 1 / Total_Percent, 1),
            DTC_Perc = DTC_Perc * Scale_Factor,
            Amazon_Perc = Amazon_Perc * Scale_Factor,
            App_Perc = App_Perc * Scale_Factor,
            Fees_Perc = Fees_Perc * Scale_Factor
          ) %>%
          ungroup() %>%
          mutate(
            DTC_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                               "<span style='color:#A52A2A;'>DTC Spend:</span> $", format(round(Total_DTC_Spend, 2), big.mark = ","),
                               " (", round(DTC_Perc * 100, 1), "%)"),
            Amazon_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                                  "<span style='color:#f39c12;'>Amazon Spend:</span> $", format(round(Amazon_Spend, 2), big.mark = ","),
                                  " (", round(Amazon_Perc * 100, 1), "%)"),
            App_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                               "<span style='color:#9b59b6;'>App Spend:</span> $", format(round(Total_App_Spend, 2), big.mark = ","),
                               " (", round(App_Perc * 100, 1), "%)"),
            Fees_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br>",
                                "<span style='color:#34495e;'>Fees:</span> $", format(round(Fees, 2), big.mark = ","),
                                " (", round(Fees_Perc * 100, 1), "%)")
          )
        
        return(plot_ly() %>%
                 add_trace(data = df, x = ~Date, y = ~DTC_Perc, type = "scatter", mode = "none", name = "DTC Spend",
                           stackgroup = "one", fillcolor = "rgba(165, 42, 42, 0.3)", line = list(color = "#A52A2A"),
                           text = ~DTC_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Amazon_Perc, type = "scatter", mode = "none", name = "Amazon Spend",
                           stackgroup = "one", fillcolor = "rgba(243, 156, 18, 0.3)", line = list(color = "#f39c12"),
                           text = ~Amazon_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~App_Perc, type = "scatter", mode = "none", name = "App Spend",
                           stackgroup = "one", fillcolor = "rgba(155, 89, 182, 0.3)", line = list(color = "#9b59b6"),
                           text = ~App_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Fees_Perc, type = "scatter", mode = "none", name = "Fees",
                           stackgroup = "one", fillcolor = "rgba(52, 73, 94, 0.3)", line = list(color = "#34495e"),
                           text = ~Fees_Label, hoverinfo = "text") %>%
                 layout(
                   yaxis = list(title = list(text = ""),tickformat = ".0%", tickfont = list(family = "Montserrat", size = 14)),
                   xaxis = list(title = list(text = ""),tickfont = list(family = "Montserrat", size = 14)),
                   hovermode = "x unified",
                   showlegend = TRUE,
                   legend = list(orientation = "h", x = 0.5, y = 1.1, xanchor = "center",
                                 font = list(family = "Montserrat", size = 14)),
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   font = list(family = "Montserrat")
                 ))
      } else if (spend_type == "DTC") {
        df <- df %>%
          filter(!is.na(Total_DTC_Spend) & Total_DTC_Spend > 0) %>%
          mutate(
            Meta_Perc = Meta_Spend / Total_DTC_Spend,
            Google_Perc = Google_Spend / Total_DTC_Spend,
            Bing_Perc = Bing_Spend / Total_DTC_Spend,
            TikTok_Perc = TikTok_Spend / Total_DTC_Spend,
            Nextdoor_Perc = Nextdoor_Spend / Total_DTC_Spend,
            Affiliate_Perc = Affiliate_Fees / Total_DTC_Spend
          ) %>%
          rowwise() %>%
          mutate(
            Total_Percent = sum(c_across(ends_with("_Perc")), na.rm = TRUE),
            Scale_Factor = ifelse(Total_Percent > 1, 1 / Total_Percent, 1),
            Meta_Perc = Meta_Perc * Scale_Factor,
            Google_Perc = Google_Perc * Scale_Factor,
            Bing_Perc = Bing_Perc * Scale_Factor,
            TikTok_Perc = TikTok_Perc * Scale_Factor,
            Nextdoor_Perc = Nextdoor_Perc * Scale_Factor,
            Affiliate_Perc = Affiliate_Perc * Scale_Factor
          ) %>%
          ungroup() %>%
          mutate(
            Meta_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#2ecc71;'>Meta Spend:</span> $", format(round(Meta_Spend, 2), big.mark = ","), " (", round(Meta_Perc * 100, 1), "%)"),
            Google_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#3498db;'>Google Spend:</span> $", format(round(Google_Spend, 2), big.mark = ","), " (", round(Google_Perc * 100, 1), "%)"),
            Bing_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#9b59b6;'>Bing Spend:</span> $", format(round(Bing_Spend, 2), big.mark = ","), " (", round(Bing_Perc * 100, 1), "%)"),
            TikTok_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#e74c3c;'>TikTok Spend:</span> $", format(round(TikTok_Spend, 2), big.mark = ","), " (", round(TikTok_Perc * 100, 1), "%)"),
            Nextdoor_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#f1c40f;'>Nextdoor Spend:</span> $", format(round(Nextdoor_Spend, 2), big.mark = ","), " (", round(Nextdoor_Perc * 100, 1), "%)"),
            Affiliate_Label = paste0("<b>", format(Date, "%b %d, %Y"), "</b><br><span style='color:#34495e;'>Affiliate Fees:</span> $", format(round(Affiliate_Fees, 2), big.mark = ","), " (", round(Affiliate_Perc * 100, 1), "%)")
          )
        
        return(plot_ly() %>%
                 add_trace(data = df, x = ~Date, y = ~Meta_Perc, type = "scatter", mode = "none", name = "Meta Spend",
                           stackgroup = "one", fillcolor = "rgba(46, 204, 113, 0.3)", line = list(color = "#2ecc71"),
                           text = ~Meta_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Google_Perc, type = "scatter", mode = "none", name = "Google Spend",
                           stackgroup = "one", fillcolor = "rgba(52, 152, 219, 0.3)", line = list(color = "#3498db"),
                           text = ~Google_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Bing_Perc, type = "scatter", mode = "none", name = "Bing Spend",
                           stackgroup = "one", fillcolor = "rgba(155, 89, 182, 0.3)", line = list(color = "#9b59b6"),
                           text = ~Bing_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~TikTok_Perc, type = "scatter", mode = "none", name = "TikTok Spend",
                           stackgroup = "one", fillcolor = "rgba(231, 76, 60, 0.3)", line = list(color = "#e74c3c"),
                           text = ~TikTok_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Nextdoor_Perc, type = "scatter", mode = "none", name = "Nextdoor Spend",
                           stackgroup = "one", fillcolor = "rgba(241, 196, 15, 0.3)", line = list(color = "#f1c40f"),
                           text = ~Nextdoor_Label, hoverinfo = "text") %>%
                 add_trace(data = df, x = ~Date, y = ~Affiliate_Perc, type = "scatter", mode = "none", name = "Affiliate Fees",
                           stackgroup = "one", fillcolor = "rgba(52, 73, 94, 0.3)", line = list(color = "#34495e"),
                           text = ~Affiliate_Label, hoverinfo = "text") %>%
                 layout(
                   yaxis = list(title = list(text = ""),tickformat = ".0%", tickfont = list(family = "Montserrat", size = 14)),
                   xaxis = list(title = list(text = ""),tickfont = list(family = "Montserrat", size = 14)),
                   hovermode = "x unified",
                   showlegend = TRUE,
                   legend = list(orientation = "h", x = 0.5, y = 1.1, xanchor = "center",
                                 font = list(family = "Montserrat", size = 14)),
                   margin = list(l = 40, r = 20, t = 60, b = 60),
                   plot_bgcolor = "#ffffff",
                   paper_bgcolor = "#ffffff",
                   font = list(family = "Montserrat")
                 ))
      }
    }
  })
  
  
  
  output$blended_cac_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_cac_type)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(
        Date = as.Date(Date),
        Blended_CAC = ifelse(Total_Orders == 0, NA, Total_Spend / Total_Orders),
        wCAC = ifelse(DTC_Orders == 0, NA, Total_DTC_Spend / DTC_Orders),
        aCAC = ifelse(Amazon_Orders == 0, NA, Amazon_Spend / Amazon_Orders),
        appCAC = ifelse(App_Orders == 0, NA, Total_App_Spend / App_Orders)
      )
    
    selected_metric <- input$selected_cac_type
    
    plot_data <- filtered_data %>%
      select(Date, !!selected_metric) %>%
      rename(CAC = !!selected_metric) %>%
      mutate(
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
          "<b>", gsub("_", " ", selected_metric), ":</b> $", round(CAC, 2),
          "</span>"
        )
      )
    
    p <- ggplot(plot_data, aes(x = Date, y = CAC, text = Tooltip)) +
      geom_col(fill = "#A52A2A", width = 0.6) +
      scale_y_continuous(expand = expansion(mult = c(0, 0.1))) +
      scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
      labs(x = NULL, y = NULL) +
      theme_minimal(base_family = "Montserrat") +
      theme(
        plot.title = element_blank(),
        axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background = element_rect(fill = "#ffffff", color = NA),
        panel.background = element_rect(fill = "#ffffff", color = NA)
      )
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff"
      )
  })
  
  
  output$cr_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    plot_data <- filtered_data %>%
      select(Date, Web_CR) %>%
      mutate(
        CR_Percent = Web_CR * 100,
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
          "<b>Conversion Rate:</b> ", round(CR_Percent, 2), " %",
          "</span>"
        )
      )
    
    p <- ggplot(plot_data, aes(x = Date, y = CR_Percent, text = Tooltip)) +
      geom_col(fill = "#7b868c", width = 0.6) +
      scale_y_continuous(labels = function(x) paste0(x, "%"), expand = expansion(mult = c(0, 0.1))) +
      scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
      labs(x = "Date", y = "Conversion Rate (%)") +
      theme_minimal(base_family = "Montserrat") +
      theme(
        axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
        axis.text.y = element_text(size = 12),
        panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
        plot.background = element_rect(fill = "#ffffff", color = NA),
        panel.background = element_rect(fill = "#ffffff", color = NA)
      )
    
    ggplotly(p, tooltip = "text") %>%
      layout(
        margin = list(l = 40, r = 20, t = 20, b = 60),
        plot_bgcolor = "#ffffff",
        paper_bgcolor = "#ffffff",
        yaxis = list(title = list(text = "")), 
        xaxis = list(title = list(text = ""))
      )
  })
  
  output$aov_bar_chart <- renderPlotly({
    req(input$selected_date_range)
    req(input$selected_aov_type)
    
    filtered_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    
    if (input$selected_aov_type == "Segmented_AOV") {
      plot_data <- filtered_data %>%
        select(Date, fAOV, rAOV) %>%
        pivot_longer(cols = c(fAOV, rAOV), names_to = "Segment", values_to = "AOV") %>%
        mutate(
          Segment = recode(Segment, fAOV = "First-Time", rAOV = "Returning"),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", Segment, " AOV:</b> $", round(AOV, 2),
            "</span>"
          )
        )
      
      p <- ggplot(plot_data, aes(x = Date, y = AOV, fill = Segment, text = Tooltip)) +
        geom_bar(stat = "identity", position = "dodge", width = 0.6) +
        scale_y_continuous(labels = scales::label_dollar()) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
        scale_fill_manual(values = c("First-Time" = "#3498db", "Returning" = "#2ecc71")) +
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
            x = 0.5,
            y = 1.15,
            xanchor = "center",
            font = list(family = "Montserrat", size = 14),
            title = list(text = NULL)  # <-- Hides legend title
          ),
          font = list(family = "Montserrat")
        )
      
    } else {
      selected_metric <- input$selected_aov_type
      plot_data <- filtered_data %>%
        select(Date, !!selected_metric) %>%
        rename(AOV = !!selected_metric) %>%
        mutate(
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>Date:</b> ", format(Date, "%Y-%m-%d"), "<br>",
            "<b>", gsub("_", " ", selected_metric), ":</b> $", round(AOV, 2),
            "</span>"
          )
        )
      
      p <- ggplot(plot_data, aes(x = Date, y = AOV, text = Tooltip)) +
        geom_col(fill = "#3498db", width = 0.6) +
        scale_y_continuous(labels = scales::label_dollar(), expand = expansion(mult = c(0, 0.1))) +
        scale_x_date(date_breaks = "5 days", date_labels = "%b %d") +
        labs(x = NULL, y = NULL) +
        theme_minimal(base_family = "Montserrat") +
        theme(
          axis.text.x = element_text(size = 12, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 12),
          panel.border = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
          plot.background = element_rect(fill = "#ffffff", color = NA),
          panel.background = element_rect(fill = "#ffffff", color = NA)
        )
      
      ggplotly(p, tooltip = "text") %>%
        layout(
          margin = list(l = 40, r = 20, t = 20, b = 60),
          plot_bgcolor = "#ffffff",
          paper_bgcolor = "#ffffff"
        )
    }
  })
  
  output$customer_split_chart <- renderPlotly({
    req(input$selected_date_range)
    
    plot_data <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(
        Date = as.Date(Date),
        Returning_Percent = Returning_Customers * 100,
        FirstTime_Percent = First_Time_Customers * 100
      )
    
    plot_ly(plot_data, x = ~Date) %>%
      add_trace(y = ~FirstTime_Percent, type = 'bar', name = 'First-Time',
                marker = list(color = 'rgba(52, 152, 219, 0.7)'),
                hoverinfo = 'text',
                text = ~paste0(format(Date, "%b %d, %Y"), "<br>First-Time: ", round(FirstTime_Percent, 1), "%"),
                textposition = "none") %>%
      add_trace(y = ~Returning_Percent, type = 'bar', name = 'Returning',
                marker = list(color = 'rgba(46, 204, 113, 0.7)'),
                hoverinfo = 'text',
                text = ~paste0(format(Date, "%b %d, %Y"), "<br>Returning: ", round(Returning_Percent, 1), "%"),
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
          title = "", tickfont = list(family = "Montserrat", size = 14)
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
  
  output$blue_sku_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Blue_SKU_Count,
      selected_data()$current$Blue_SKU_AZ_Count,
      selected_data()$current$Rachio_Blue_SKU_Count,
      selected_data()$current$Weatherflow_Blue_SKU_Count,
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
      na.rm = TRUE
    )
    # Yellow
    yellow_all <- sum(
      selected_data()$current$Yellow_SKU_Count,
      selected_data()$current$Yellow_SKU_AZ_Count,
      selected_data()$current$Rachio_Yellow_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_SKU_Count,
      na.rm = TRUE
    )
    # Blue w/ Solar
    blue_roof_all <- sum(
      selected_data()$current$Blue_Roof_SKU_Count,
      selected_data()$current$Blue_Roof_SKU_AZ_Count,
      selected_data()$current$Rachio_Blue_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Blue_Roof_SKU_Count,
      na.rm = TRUE
    )
    # Yellow w/ Solar
    yellow_roof_all <- sum(
      selected_data()$current$Yellow_Roof_SKU_Count,
      selected_data()$current$Yellow_Roof_SKU_AZ_Count,
      selected_data()$current$Rachio_Yellow_Roof_SKU_Count,
      selected_data()$current$Weatherflow_Yellow_Roof_SKU_Count,
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
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_suet_ball_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Suet_Ball_Units,
      selected_data()$current$`amazon_Suet Ball Holder`,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_blue_nutrition_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Blue_Nutrition_Units,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Blue`,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_yellow_nutrition_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Yellow_Nutrition_Units,
      selected_data()$current$`amazon_3-in-1 Nutrition Set - Yellow`,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_solar_roof_blue_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Solar_Roof_Blue_Units,
      selected_data()$current$`amazon_Solar Roof Single - Blue`,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_solar_roof_yellow_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Solar_Roof_Yellow_Units,
      selected_data()$current$`amazon_Solar Roof Single - Yellow`,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_perch_extender_blue_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Perch_Extender_Blue_Units,
      selected_data()$current$`amazon_Perch Extender - Blue`,
      na.rm = TRUE
    )
    format(total, big.mark = ",")
  })
  
  output$addon_perch_extender_yellow_all_channels <- renderText({
    total <- sum(
      selected_data()$current$Perch_Extender_Yellow_Units,
      selected_data()$current$`amazon_Perch Extender - Yellow`,
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
      na.rm = TRUE
    )
    format(grand, big.mark = ",")
  })
  
  output$units_ua_plot <- renderPlotly({
    req(input$selected_date_range, input$units_ua_channel, input$units_ua_view)
    
    legend_layout <- list(
      orientation = "h",
      x           = 0.5,
      y           = 1.15,
      xanchor     = "center",
      font        = list(family = "Montserrat", size = 14),
      title       = list(text = NULL)
    )
    
    # 1) filter date
    df0 <- revenue_data %>%
      filter(
        Date >= input$selected_date_range[1],
        Date <= input$selected_date_range[2]
      ) %>%
      mutate(Date = as.Date(Date))
    
    # 2) daily sums by channel
    df_sum <- df0 %>%
      group_by(Date) %>%
      summarise(
        Units_All    = sum(
          `dtc_SKU 1 - Blue` + `dtc_SKU 2 - Yellow` +
            `dtc_SKU 3 - Blue w/ Solar` + `dtc_SKU 4 - Yellow w/ Solar` +
            `dtc_SKU 5 - HBF` + `dtc_SKU 6 - HBF w/ Solar` +
            `amazon_SKU 1 - Blue` + `amazon_SKU 2 - Yellow` +
            `amazon_SKU 3 - Blue w/ Solar` + `amazon_SKU 4 - Yellow w/ Solar` +
            `rachio_SKU 1 - Blue` + `rachio_SKU 2 - Yellow` +
            `rachio_SKU 3 - Blue w/ Solar` + `rachio_SKU 4 - Yellow w/ Solar` +
            `weatherflow_SKU 1 - Blue` + `weatherflow_SKU 2 - Yellow` +
            `weatherflow_SKU 3 - Blue w/ Solar` + `weatherflow_SKU 4 - Yellow w/ Solar`,
          na.rm = TRUE
        ),
        Units_DTC     = sum(
          `dtc_SKU 1 - Blue` + `dtc_SKU 2 - Yellow` +
            `dtc_SKU 3 - Blue w/ Solar` + `dtc_SKU 4 - Yellow w/ Solar` +
            `dtc_SKU 5 - HBF` + `dtc_SKU 6 - HBF w/ Solar`,
          na.rm = TRUE
        ),
        Units_Amazon  = sum(
          `amazon_SKU 1 - Blue` + `amazon_SKU 2 - Yellow` +
            `amazon_SKU 3 - Blue w/ Solar` + `amazon_SKU 4 - Yellow w/ Solar`,
          na.rm = TRUE
        ),
        Units_Digital = sum(
          `rachio_SKU 1 - Blue` + `rachio_SKU 2 - Yellow` +
            `rachio_SKU 3 - Blue w/ Solar` + `rachio_SKU 4 - Yellow w/ Solar` +
            `weatherflow_SKU 1 - Blue` + `weatherflow_SKU 2 - Yellow` +
            `weatherflow_SKU 3 - Blue w/ Solar` + `weatherflow_SKU 4 - Yellow w/ Solar`,
          na.rm = TRUE
        ),
        Addons_All    = sum(
          `dtc_Wall Mount` + `dtc_Suet Ball Holder` +
            `dtc_3-in-1 Nutrition Set - Blue` + `dtc_3-in-1 Nutrition Set - Yellow` +
            `dtc_Solar Roof Single - Blue` + `dtc_Solar Roof Single - Yellow` +
            `dtc_Perch Extender - Blue` + `dtc_Perch Extender - Yellow` +
            `dtc_Solar Roof (HBF)` + `dtc_Housing - only (HBF)` +
            `amazon_Wall Mount` + `amazon_Suet Ball Holder` +
            `amazon_3-in-1 Nutrition Set - Blue` + `amazon_3-in-1 Nutrition Set - Yellow` +
            `amazon_Solar Roof Single - Blue` + `amazon_Solar Roof Single - Yellow` +
            `amazon_Perch Extender - Blue` + `amazon_Perch Extender - Yellow`,
          na.rm = TRUE
        ),
        Addons_DTC    = sum(
          `dtc_Wall Mount` + `dtc_Suet Ball Holder` +
            `dtc_3-in-1 Nutrition Set - Blue` + `dtc_3-in-1 Nutrition Set - Yellow` +
            `dtc_Solar Roof Single - Blue` + `dtc_Solar Roof Single - Yellow` +
            `dtc_Perch Extender - Blue` + `dtc_Perch Extender - Yellow` +
            `dtc_Solar Roof (HBF)` + `dtc_Housing - only (HBF)`,
          na.rm = TRUE
        ),
        Addons_Amazon = sum(
          `amazon_Wall Mount` + `amazon_Suet Ball Holder` +
            `amazon_3-in-1 Nutrition Set - Blue` + `amazon_3-in-1 Nutrition Set - Yellow` +
            `amazon_Solar Roof Single - Blue` + `amazon_Solar Roof Single - Yellow` +
            `amazon_Perch Extender - Blue` + `amazon_Perch Extender - Yellow`,
          na.rm = TRUE
        ),
        Addons_Digital = 0,
        Seeds_All     = sum(
          `dtc_Seasonal Curation - 8lb` + `dtc_Seasonal Curation - 20lb` +
            `dtc_Buddy Bites - 8lb` + `dtc_Buddy Bites - 20lb` +
            `dtc_Snack n' Soar - 8lb` + `dtc_Snack n' Soar - 20lb` +
            `dtc_Avian Choice - 8lb` + `dtc_Avian Choice - 20lb`,
          na.rm = TRUE
        ),
        Seeds_DTC      = sum(
          `dtc_Seasonal Curation - 8lb` + `dtc_Seasonal Curation - 20lb` +
            `dtc_Buddy Bites - 8lb` + `dtc_Buddy Bites - 20lb` +
            `dtc_Snack n' Soar - 8lb` + `dtc_Snack n' Soar - 20lb` +
            `dtc_Avian Choice - 8lb` + `dtc_Avian Choice - 20lb`,
          na.rm = TRUE
        ),
        Seeds_Amazon   = 0,
        Seeds_Digital  = 0
      )
    
    # 3) pick channel & pivot to long
    df_ch <- df_sum %>%
      transmute(
        Date,
        Units  = case_when(
          input$units_ua_channel == "All"     ~ Units_All,
          input$units_ua_channel == "DTC"     ~ Units_DTC,
          input$units_ua_channel == "Amazon"  ~ Units_Amazon,
          input$units_ua_channel == "Digital" ~ Units_Digital
        ),
        Addons = case_when(
          input$units_ua_channel == "All"     ~ Addons_All,
          input$units_ua_channel == "DTC"     ~ Addons_DTC,
          input$units_ua_channel == "Amazon"  ~ Addons_Amazon,
          input$units_ua_channel == "Digital" ~ Addons_Digital
        ),
        Seeds  = case_when(
          input$units_ua_channel == "All"     ~ Seeds_All,
          input$units_ua_channel == "DTC"     ~ Seeds_DTC,
          input$units_ua_channel == "Amazon"  ~ Seeds_Amazon,
          input$units_ua_channel == "Digital" ~ Seeds_Digital
        )
      ) %>%
      pivot_longer(c(Units, Addons, Seeds), names_to = "Category", values_to = "Count") %>%
      mutate(
        Tooltip = paste0(
          "<span style='font-family: Montserrat;'>",
          "<b>", format(Date, "%b %d, %Y"), "</b><br>",
          "<b>", Category, ": </b>", Count,
          "</span>"
        )
      ) %>%
      { if (!input$units_include_seeds) filter(., Category != "Seeds") else . } %>%
      filter(
        !(Category == "Seeds" & input$units_ua_channel == "Amazon"),
        !(Category %in% c("Seeds","Addons") & input$units_ua_channel == "Digital")
      )
    
    if (input$units_ua_view == "Absolute") {
      
      if (isTRUE(input$units_line_view)) {
        # ABSOLUTE & LINE: ensure lines + points, grouped by Category
        p <- ggplot(df_ch, aes(x = Date, y = Count, color = Category, group = Category, text = Tooltip)) +
          geom_line(size = 1) +
          geom_point(size = 2) +scale_color_manual(
            values = c(
              "Units"  = "#2ecc71",
              "Addons" = "#3498db",
              "Seeds"  = "#f39c12"
            )
          ) +
          theme_minimal(base_family = "Montserrat") +
          theme(
            axis.text.x     = element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y     = element_text(size = 12),
            panel.border    = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = element_rect(fill = "#ffffff", color = NA),
            panel.background= element_rect(fill = "#ffffff", color = NA)
          )
        
        ggplotly(p, tooltip = "text") %>%
          layout(
            margin        = list(l = 40, r = 20, t = 20, b = 60),
            plot_bgcolor  = "#ffffff",
            paper_bgcolor = "#ffffff",
            showlegend    = TRUE,
            legend        = legend_layout,
            font          = list(family = "Montserrat")
          )
        
      } else {
        # ABSOLUTE & BAR: grouped bar chart
        p <- ggplot(df_ch, aes(x = Date, y = Count, fill = Category, text = Tooltip)) +
          geom_col(position = position_dodge(width = 0.8), width = 0.7) +
          scale_fill_manual(values = c("Units" = "#2ecc71", "Addons" = "#3498db", "Seeds" = "#f39c12")) +
          theme_minimal(base_family = "Montserrat") +
          theme(
            axis.text.x     = element_text(size = 12, angle = 45, hjust = 1),
            axis.text.y     = element_text(size = 12),
            legend.position = "none",
            panel.border    = element_rect(color = "#ddd", fill = NA, linewidth = 0.5),
            plot.background = element_rect(fill = "#ffffff", color = NA),
            panel.background= element_rect(fill = "#ffffff", color = NA)
          )
        
        ggplotly(p, tooltip = "text") %>%
          layout(
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
      # RELATIVE: stacked bar chart (unchanged)
      totals <- df_ch %>% group_by(Date) %>% summarise(DayTotal = sum(Count), .groups="drop")
      df_rel <- left_join(df_ch, totals, by = "Date") %>%
        mutate(
          Share = ifelse(DayTotal == 0, 0, Count / DayTotal),
          Tooltip = paste0(
            "<span style='font-family: Montserrat;'>",
            "<b>", format(Date, "%b %d, %Y"), "</b><br>",
            "<span style='color:",
            case_when(
              Category=="Units"  ~ "#2ecc71",
              Category=="Addons" ~ "#3498db",
              Category=="Seeds"  ~ "#f39c12"
            ), ";'>",
            Category, ": ", round(Share*100,1), "% (", Count, " units)</span></span>"
          )
        )
      
      legend_df <- df_rel %>%
        group_by(Category) %>%
        summarise(Total = sum(Count), .groups="drop") %>%
        mutate(
          CumPct = round(Total / sum(Total) * 100, 1),
          Legend = paste0(Category, " (", CumPct, "%)")
        )
      
      p <- plot_ly()
      for (i in seq_len(nrow(legend_df))) {
        cat_name    <- legend_df$Category[i]
        legend_name <- legend_df$Legend[i]
        line_col    <- switch(cat_name,
                              "Units"  = '#2ecc71',
                              "Addons" = '#3498db',
                              "Seeds"  = '#f39c12')
        
        p <- p %>%
          add_trace(
            data        = df_rel %>% filter(Category == cat_name),
            x           = ~Date,
            y           = ~Share,
            type        = 'bar',
            name        = legend_name,
            marker      = list(color = line_col),
            hovertext   = ~Tooltip,       # use hovertext
            hoverinfo   = 'text',         # only show hovertext
            textposition= 'none'          # ensure no on-bar labels
          )
      }
      
      p %>% layout(
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
          ticks     = "outside"
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
    
    df <- revenue_data |>
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) |>
      mutate(Date = as.Date(Date))
    
    df_sum <- df |>
      group_by(Date) |>
      summarise(
        SBF = sum(
          switch(input$sbf_hbf_channel,
                 All     = c(`dtc_SKU 1 - Blue`, `dtc_SKU 2 - Yellow`,
                             `dtc_SKU 3 - Blue w/ Solar`, `dtc_SKU 4 - Yellow w/ Solar`,
                             `amazon_SKU 1 - Blue`, `amazon_SKU 2 - Yellow`,
                             `amazon_SKU 3 - Blue w/ Solar`, `amazon_SKU 4 - Yellow w/ Solar`,
                             `rachio_SKU 1 - Blue`, `rachio_SKU 2 - Yellow`,
                             `rachio_SKU 3 - Blue w/ Solar`, `rachio_SKU 4 - Yellow w/ Solar`,
                             `weatherflow_SKU 1 - Blue`, `weatherflow_SKU 2 - Yellow`,
                             `weatherflow_SKU 3 - Blue w/ Solar`, `weatherflow_SKU 4 - Yellow w/ Solar`),
                 DTC     = c(`dtc_SKU 1 - Blue`, `dtc_SKU 2 - Yellow`,
                             `dtc_SKU 3 - Blue w/ Solar`, `dtc_SKU 4 - Yellow w/ Solar`),
                 Amazon  = c(`amazon_SKU 1 - Blue`, `amazon_SKU 2 - Yellow`,
                             `amazon_SKU 3 - Blue w/ Solar`, `amazon_SKU 4 - Yellow w/ Solar`),
                 Digital = c(`rachio_SKU 1 - Blue`, `rachio_SKU 2 - Yellow`,
                             `rachio_SKU 3 - Blue w/ Solar`, `rachio_SKU 4 - Yellow w/ Solar`,
                             `weatherflow_SKU 1 - Blue`, `weatherflow_SKU 2 - Yellow`,
                             `weatherflow_SKU 3 - Blue w/ Solar`, `weatherflow_SKU 4 - Yellow w/ Solar`)
          ), na.rm = TRUE),
        HBF = sum(
          switch(input$sbf_hbf_channel,
                 All     = c(`dtc_SKU 5 - HBF`, `dtc_SKU 6 - HBF w/ Solar`),
                 DTC     = c(`dtc_SKU 5 - HBF`, `dtc_SKU 6 - HBF w/ Solar`),
                 Amazon  = integer(0),
                 Digital = integer(0)
          ), na.rm = TRUE)
      ) |>
      pivot_longer(c(SBF, HBF), names_to = "Group", values_to = "Count")
    
    ## ───────────── Absolute ────────────────────────────────────────────
    if (input$sbf_hbf_view == "Absolute") {
      
      df_abs <- df_sum |>
        mutate(Tooltip = paste0("<b>", format(Date,"%b %d, %Y"),
                                "</b><br>", Group, ": ", Count, " units"))
      
      if (want_lines()) {
        p <- plot_ly(df_abs, x = ~Date, y = ~Count, color = ~Group,
                     colors = c(SBF="#2980b9", HBF="#b12625"),
                     type = "scatter", mode = "lines+markers",
                     hovertext   = ~Tooltip,       # use hovertext
                     hoverinfo   = 'text',         # only show hovertext
                     textposition= 'none')
      } else {
        p <- plot_ly()
        for(g in c("SBF","HBF"))
          p <- p |> add_bars(data = df_abs |> filter(Group==g),
                             x = ~Date, y = ~Count, name = g,
                             marker = list(color = if(g=="SBF") "#2980b9" else "#b12625"),
                             hovertext   = ~Tooltip,       # use hovertext
                             hoverinfo   = 'text',         # only show hovertext
                             textposition= 'none')
        p <- p |> layout(barmode = "group")
      }
      
      ## ───────────── Relative ────────────────────────────────────────────
    } else {
      
      totals <- df_sum |> group_by(Date) |> summarise(DayTotal = sum(Count), .groups="drop")
      df_rel <- left_join(df_sum, totals, by="Date") |>
        mutate(Share   = ifelse(DayTotal==0,0,Count/DayTotal),
               Tooltip = paste0("<b>", format(Date,"%b %d, %Y"), "</b><br>",
                                Group, ": ", round(Share*100,1), "% (", Count," units)"))
      
      ## overall cumulative share for legend
      overall <- df_rel |> group_by(Group) |>
        summarise(Total = sum(Count), .groups="drop") |>
        mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$Group)
      
      p <- plot_ly()
      for(g in c("SBF","HBF"))
        p <- p |> add_bars(data = df_rel |> filter(Group==g),
                           x = ~Date, y = ~Share,
                           name = paste0(g, " (", pct[g], "%)"),
                           marker = list(color = if(g=="SBF") "#2980b9" else "#b12625"),
                           hovertext   = ~Tooltip,       # use hovertext
                           hoverinfo   = 'text',         # only show hovertext
                           textposition= 'none')
      p <- p |> layout(barmode="stack",
                       yaxis = list(tickformat=".0%"))
    }
    
    p |> layout(
      legend = list(orientation="h",x=0.5,y=1.15,xanchor="center"),
      margin = list(l=40,r=20,t=20,b=60),
      plot_bgcolor="#ffffff", paper_bgcolor="#ffffff",
      font = list(family="Montserrat"))
  }
  ## ---------------- 5.3  SKU + colour ----------------------------------------
  sku_channel_plot <- function() {
    
    req(input$selected_date_range, input$sku_channel, input$sku_view)
    
    df <- revenue_data |>
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) |>
      mutate(Date = as.Date(Date))
    
    sel_cols <- switch(input$sku_channel,
                       All     = grep("^(dtc|amazon|rachio|weatherflow)_SKU", names(df), value=TRUE),
                       DTC     = grep("^dtc_SKU", names(df),  value=TRUE),
                       Amazon  = grep("^amazon_SKU", names(df), value=TRUE),
                       Digital = c(grep("^rachio_SKU",names(df),value=TRUE),
                                   grep("^weatherflow_SKU",names(df),value=TRUE))
    )
    
    df_long <- df |>
      pivot_longer(all_of(sel_cols), names_to="col", values_to="Count") |>
      mutate(SKU = case_when(
        grepl("SKU 1", col) ~ "SBF Blue",
        grepl("SKU 2", col) ~ "SBF Yellow",
        grepl("SKU 3", col) ~ "SBF Solar Blue",
        grepl("SKU 4", col) ~ "SBF Solar Yellow",
        grepl("SKU 5", col) ~ "HBF",
        grepl("SKU 6", col) ~ "HBF Solar",
        TRUE ~ NA_character_
      )) |>
      filter(!is.na(SKU), SKU %in% input$selected_skus) |>
      group_by(Date,SKU) |>
      summarise(Count=sum(Count,na.rm=TRUE), .groups="drop") |>
      mutate(SKU = factor(SKU, levels=c("SBF Blue","SBF Yellow",
                                        "SBF Solar Blue","SBF Solar Yellow",
                                        "HBF","HBF Solar")))
    
    cols6 <- c("SBF Blue"="#005AB5","SBF Yellow"="#FDAF17",
               "SBF Solar Blue"="#3498db","SBF Solar Yellow"="#f1c40f",
               "HBF"="#7b868c","HBF Solar"="#e74c3c")
    
    ## ---------------- Absolute --------------------------------------------------
    if (input$sku_view == "Absolute") {
      
      df_abs <- df_long |>
        mutate(Tooltip = paste0("<b>",format(Date,"%b %d, %Y"),
                                "</b><br>",SKU,": ",Count," units"))
      
      if (want_lines()) {
        p <- plot_ly(df_abs, x=~Date, y=~Count, color=~SKU,
                     colors=cols6, type="scatter", mode="lines+markers",
                     hovertext   = ~Tooltip,       # use hovertext
                     hoverinfo   = 'text',         # only show hovertext
                     textposition= 'none')
      } else {
        p <- plot_ly()
        for(s in levels(df_abs$SKU))
          p <- p |> add_bars(data=df_abs|>filter(SKU==s),
                             x=~Date, y=~Count, name=s,
                             marker=list(color=cols6[s]),
                             hovertext   = ~Tooltip,       # use hovertext
                             hoverinfo   = 'text',         # only show hovertext
                             textposition= 'none')
        p <- p |> layout(barmode="group")
      }
      
      ## ---------------- Relative --------------------------------------------------
    } else {
      
      totals <- df_long |> group_by(Date) |> summarise(DayTotal=sum(Count), .groups="drop")
      df_rel <- left_join(df_long, totals, by="Date") |>
        mutate(Share = ifelse(DayTotal==0,0,Count/DayTotal),
               Tooltip=paste0("<b>",format(Date,"%b %d, %Y"),"</b><br>",
                              SKU,": ",round(Share*100,1)," % (",Count," units)"))
      
      overall <- df_rel |> group_by(SKU) |>
        summarise(Total=sum(Count), .groups="drop") |>
        mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$SKU)
      
      p <- plot_ly()
      for(s in levels(df_rel$SKU))
        p <- p |> add_bars(data=df_rel|>filter(SKU==s),
                           x=~Date, y=~Share,
                           name=paste0(s," (",pct[s],"%)"),
                           marker=list(color=cols6[s]),
                           hovertext   = ~Tooltip,       # use hovertext
                           hoverinfo   = 'text',         # only show hovertext
                           textposition= 'none')
      p <- p |> layout(barmode="stack",
                       yaxis=list(tickformat=".0%"))
    }
    
    p |> layout(
      legend=list(orientation="h", x=0.5, y=1.15, xanchor="center"),
      margin=list(l=40,r=20,t=20,b=60),
      plot_bgcolor="#ffffff", paper_bgcolor="#ffffff",
      font=list(family="Montserrat"))
  }
  
  ## ---------------- 5.2  SKU groups ------------------------------------------
  sku_group_plot <- function() {
    
    req(input$selected_date_range, input$grouped_skus_channel, input$grouped_skus_groups)
    
    df <- revenue_data |>
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) |>
      mutate(Date = as.Date(Date))
    
    df_sum <- df |>
      group_by(Date) |>
      summarise(
        SBF = sum(
          switch(input$grouped_skus_channel,
                 All     = c(`dtc_SKU 1 - Blue`, `dtc_SKU 2 - Yellow`,
                             `amazon_SKU 1 - Blue`, `amazon_SKU 2 - Yellow`,
                             `rachio_SKU 1 - Blue`, `rachio_SKU 2 - Yellow`,
                             `weatherflow_SKU 1 - Blue`, `weatherflow_SKU 2 - Yellow`),
                 DTC     = c(`dtc_SKU 1 - Blue`, `dtc_SKU 2 - Yellow`),
                 Amazon  = c(`amazon_SKU 1 - Blue`, `amazon_SKU 2 - Yellow`),
                 Digital = c(`rachio_SKU 1 - Blue`, `rachio_SKU 2 - Yellow`,
                             `weatherflow_SKU 1 - Blue`, `weatherflow_SKU 2 - Yellow`)
          ), na.rm=TRUE),
        `SBF Solar` = sum(
          switch(input$grouped_skus_channel,
                 All     = c(`dtc_SKU 3 - Blue w/ Solar`, `dtc_SKU 4 - Yellow w/ Solar`,
                             `amazon_SKU 3 - Blue w/ Solar`, `amazon_SKU 4 - Yellow w/ Solar`,
                             `rachio_SKU 3 - Blue w/ Solar`, `rachio_SKU 4 - Yellow w/ Solar`,
                             `weatherflow_SKU 3 - Blue w/ Solar`, `weatherflow_SKU 4 - Yellow w/ Solar`),
                 DTC     = c(`dtc_SKU 3 - Blue w/ Solar`, `dtc_SKU 4 - Yellow w/ Solar`),
                 Amazon  = c(`amazon_SKU 3 - Blue w/ Solar`, `amazon_SKU 4 - Yellow w/ Solar`),
                 Digital = c(`rachio_SKU 3 - Blue w/ Solar`, `rachio_SKU 4 - Yellow w/ Solar`,
                             `weatherflow_SKU 3 - Blue w/ Solar`, `weatherflow_SKU 4 - Yellow w/ Solar`)
          ), na.rm=TRUE),
        HBF = sum(
          if (input$grouped_skus_channel %in% c("All","DTC")) `dtc_SKU 5 - HBF` else 0,
          na.rm=TRUE),
        `HBF Solar` = sum(
          if (input$grouped_skus_channel %in% c("All","DTC")) `dtc_SKU 6 - HBF w/ Solar` else 0,
          na.rm=TRUE)
      ) |>
      pivot_longer(c(SBF,`SBF Solar`,HBF,`HBF Solar`),
                   names_to="Group", values_to="Count") |>
      filter(Group %in% input$grouped_skus_groups) |>
      mutate(Group = factor(Group, levels=c("SBF","SBF Solar","HBF","HBF Solar")))
    
    cols4 <- c("SBF"="#2ecc71","SBF Solar"="#3498db","HBF"="#7b868c","HBF Solar"="#e74c3c")
    
    ## ---------------- Absolute --------------------------------------------------
    if (input$grouped_skus_view == "Absolute") {
      
      df_abs <- df_sum |>
        mutate(Tooltip = paste0("<b>",format(Date,"%b %d, %Y"),
                                "</b><br>", Group,": ",Count," units"))
      
      if (want_lines()) {
        p <- plot_ly(df_abs, x=~Date, y=~Count, color=~Group,
                     colors=cols4, type="scatter", mode="lines+markers",
                     hovertext   = ~Tooltip,       # use hovertext
                     hoverinfo   = 'text',         # only show hovertext
                     textposition= 'none')
      } else {
        p <- plot_ly()
        for(g in levels(df_abs$Group))
          p <- p |> add_bars(data=df_abs|>filter(Group==g),
                             x=~Date, y=~Count, name=g,
                             marker=list(color=cols4[g]),
                             hovertext   = ~Tooltip,       # use hovertext
                             hoverinfo   = 'text',         # only show hovertext
                             textposition= 'none')
        p <- p |> layout(barmode="group")
      }
      
      ## ---------------- Relative --------------------------------------------------
    } else {
      
      totals <- df_sum |> group_by(Date) |> summarise(DayTotal=sum(Count),.groups="drop")
      df_rel <- left_join(df_sum, totals, by="Date") |>
        mutate(Share = ifelse(DayTotal==0,0,Count/DayTotal),
               Tooltip = paste0("<b>",format(Date,"%b %d, %Y"),"</b><br>",
                                Group,": ",round(Share*100,1)," % (",Count," units)"))
      
      overall <- df_rel |> group_by(Group) |>
        summarise(Total=sum(Count),.groups="drop") |>
        mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$Group)
      
      p <- plot_ly()
      for(g in levels(df_rel$Group))
        p <- p |> add_bars(data=df_rel |> filter(Group==g),
                           x=~Date, y=~Share,
                           name=paste0(g," (",pct[g],"%)"),
                           marker=list(color=cols4[g]),
                           hovertext   = ~Tooltip,       # use hovertext
                           hoverinfo   = 'text',         # only show hovertext
                           textposition= 'none')
      p <- p |> layout(barmode="stack",
                       yaxis=list(tickformat=".0%"))
    }
    
    p |> layout(
      legend=list(orientation="h",x=0.5,y=1.15,xanchor="center"),
      margin=list(l=40,r=20,t=20,b=60),
      plot_bgcolor="#ffffff",paper_bgcolor="#ffffff",
      font=list(family="Montserrat"))
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
    
    # ----- prepare long data (counts by date x group) ---------------
    df <- revenue_data |>
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) |>
      mutate(Date = as.Date(Date))
    
    df_sum <- df |>
      group_by(Date) |>
      summarise(
        `Wall Mount` = sum(
          switch(input$grouped_addons_channel,
                 All    = c(`dtc_Wall Mount`, `amazon_Wall Mount`),
                 DTC    = c(`dtc_Wall Mount`),
                 Amazon = c(`amazon_Wall Mount`)
          ), na.rm = TRUE),
        `Suet Ball Holder` = sum(
          switch(input$grouped_addons_channel,
                 All    = c(`dtc_Suet Ball Holder`, `amazon_Suet Ball Holder`),
                 DTC    = c(`dtc_Suet Ball Holder`),
                 Amazon = c(`amazon_Suet Ball Holder`)
          ), na.rm = TRUE),
        `3-in-1 Nutrition Set` = sum(
          switch(input$grouped_addons_channel,
                 All    = c(`dtc_3-in-1 Nutrition Set - Blue`,  `dtc_3-in-1 Nutrition Set - Yellow`,
                            `amazon_3-in-1 Nutrition Set - Blue`,`amazon_3-in-1 Nutrition Set - Yellow`),
                 DTC    = c(`dtc_3-in-1 Nutrition Set - Blue`,  `dtc_3-in-1 Nutrition Set - Yellow`),
                 Amazon = c(`amazon_3-in-1 Nutrition Set - Blue`,`amazon_3-in-1 Nutrition Set - Yellow`)
          ), na.rm = TRUE),
        `Solar Roof Single` = sum(
          switch(input$grouped_addons_channel,
                 All    = c(`dtc_Solar Roof Single - Blue`, `dtc_Solar Roof Single - Yellow`,
                            `amazon_Solar Roof Single - Blue`, `amazon_Solar Roof Single - Yellow`),
                 DTC    = c(`dtc_Solar Roof Single - Blue`, `dtc_Solar Roof Single - Yellow`),
                 Amazon = c(`amazon_Solar Roof Single - Blue`, `amazon_Solar Roof Single - Yellow`)
          ), na.rm = TRUE),
        `Perch Extender` = sum(
          switch(input$grouped_addons_channel,
                 All    = c(`dtc_Perch Extender - Blue`, `dtc_Perch Extender - Yellow`,
                            `amazon_Perch Extender - Blue`, `amazon_Perch Extender - Yellow`),
                 DTC    = c(`dtc_Perch Extender - Blue`, `dtc_Perch Extender - Yellow`),
                 Amazon = c(`amazon_Perch Extender - Blue`, `amazon_Perch Extender - Yellow`)
          ), na.rm = TRUE),
        `Solar Roof (HBF)` = sum(
          if (input$grouped_addons_channel %in% c("All","DTC")) `dtc_Solar Roof (HBF)` else 0,
          na.rm = TRUE),
        `Housing – only (HBF)` = sum(
          if (input$grouped_addons_channel %in% c("All","DTC")) `dtc_Housing - only (HBF)` else 0,
          na.rm = TRUE)
      ) |>
      pivot_longer(cols = -Date, names_to = "Addon", values_to = "Count") |>
      filter(Addon %in% input$grouped_addons_groups)
    
    cols7 <- RColorBrewer::brewer.pal(7, "Set2")       # seven nice colours
    names(cols7) <- levels(factor(df_sum$Addon))
    
    ## ---- Absolute view ---------------------------------------------------------
    if (input$grouped_addons_view == "Absolute") {
      
      df_abs <- df_sum |>
        mutate(Tooltip = paste0("<b>", format(Date,"%b %d, %Y"),
                                "</b><br>", Addon, ": ", Count, " add‑ons"))
      
      if (want_lines_addon()) {
        
        p <- plot_ly(df_abs, x = ~Date, y = ~Count, color = ~Addon,
                     colors = cols7, type = "scatter", mode = "lines+markers",
                     hovertext   = ~Tooltip,       # use hovertext
                     hoverinfo   = 'text',         # only show hovertext
                     textposition= 'none')
        
      } else {          # grouped bars (default)
        
        p <- plot_ly()
        for (g in names(cols7))
          p <- p |> add_bars(data = df_abs |> filter(Addon == g),
                             x = ~Date, y = ~Count, name = g,
                             marker = list(color = cols7[g]),
                             hovertext   = ~Tooltip,       # use hovertext
                             hoverinfo   = 'text',         # only show hovertext
                             textposition= 'none')
        p <- p |> layout(barmode = "group")
      }
      
      ## ---- Relative (100 % stacked) ---------------------------------------------
    } else {
      
      totals  <- df_sum |> group_by(Date) |> summarise(DayTotal = sum(Count), .groups="drop")
      df_rel  <- left_join(df_sum, totals, by="Date") |>
        mutate(Share = ifelse(DayTotal==0,0,Count/DayTotal),
               Tooltip = paste0("<b>", format(Date,"%b %d, %Y"), "</b><br>",
                                Addon, ": ", round(Share*100,1), "% (", Count," add‑ons)"))
      
      overall <- df_rel |> group_by(Addon) |>
        summarise(Total = sum(Count), .groups="drop") |>
        mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$Addon)
      
      p <- plot_ly()
      for (g in names(cols7))
        p <- p |> add_bars(data = df_rel |> filter(Addon==g),
                           x = ~Date, y = ~Share,
                           name = paste0(g," (",pct[g],"%)"),
                           marker = list(color = cols7[g]),
                           hovertext   = ~Tooltip,       # use hovertext
                           hoverinfo   = 'text',         # only show hovertext
                           textposition= 'none')
      p <- p |> layout(barmode = "stack",
                       yaxis   = list(tickformat = ".0%"))
    }
    
    p |> layout(
      legend = list(orientation="h", x=0.5, y=1.15, xanchor="center"),
      margin = list(l=40,r=20,t=20,b=60),
      plot_bgcolor="#ffffff", paper_bgcolor="#ffffff",
      font = list(family="Montserrat"))
  }
  
  ## =================================================================
  ## 5.2  Add‑on COLOUR view  (Blue / Yellow variants kept separate)
  ## =================================================================
  addon_colour_plot <- function() {
    
    req(input$selected_date_range, input$addon_channel,
        input$addon_view,        input$selected_addons)
    
    # ----- long data at colour level -------------------------------------------
    df <- revenue_data |>
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) |>
      mutate(Date = as.Date(Date))
    
    sel_cols <- switch(input$addon_channel,
                       All = grep("^(dtc|amazon)_(Wall Mount|Suet Ball Holder|3-in-1 Nutrition Set - Blue|3-in-1 Nutrition Set - Yellow|Solar Roof Single - Blue|Solar Roof Single - Yellow|Perch Extender - Blue|Perch Extender - Yellow|Solar Roof \\(HBF\\)|Housing - only \\(HBF\\))",
                                  names(df), value = TRUE),
                       DTC    = grep("^dtc_",    names(df), value = TRUE),
                       Amazon = grep("^amazon_", names(df), value = TRUE)
    )
    
    df_long <- df |>
      pivot_longer(all_of(sel_cols), names_to = "col", values_to = "Count") |>
      mutate(AddOn = case_when(
        grepl("Wall Mount", col)                     ~ "Wall Mount",
        grepl("Suet Ball Holder", col)               ~ "Suet Ball Holder",
        grepl("3-in-1 Nutrition Set - Blue", col)    ~ "3-in-1 Nutrition Set – Blue",
        grepl("3-in-1 Nutrition Set - Yellow", col)  ~ "3-in-1 Nutrition Set – Yellow",
        grepl("Solar Roof Single - Blue", col)       ~ "Solar Roof Single – Blue",
        grepl("Solar Roof Single - Yellow", col)     ~ "Solar Roof Single – Yellow",
        grepl("Perch Extender - Blue", col)          ~ "Perch Extender – Blue",
        grepl("Perch Extender - Yellow", col)        ~ "Perch Extender – Yellow",
        grepl("Solar Roof \\(HBF\\)", col)           ~ "Solar Roof (HBF)",
        grepl("Housing - only \\(HBF\\)", col)       ~ "Housing – only (HBF)",
        TRUE                                         ~ NA_character_
      )) |>
      filter(!is.na(AddOn), AddOn %in% input$selected_addons) |>
      group_by(Date, AddOn) |>
      summarise(Count = sum(Count, na.rm = TRUE), .groups = "drop")
    
    ## create a reproducible colour palette
    pal <- scales::hue_pal()(length(unique(df_long$AddOn)))
    names(pal) <- sort(unique(df_long$AddOn))
    
    ## ---------------- Absolute --------------------------------------------------
    if (input$addon_view == "Absolute") {
      
      df_abs <- df_long |>
        mutate(Tooltip = paste0("<b>", format(Date,"%b %d, %Y"),
                                "</b><br>", AddOn, ": ", Count, " add‑ons"))
      
      if (want_lines_addon()) {
        
        p <- plot_ly(df_abs, x=~Date, y=~Count, color=~AddOn,
                     colors=pal, type="scatter", mode="lines+markers",
                     hovertext   = ~Tooltip,       # use hovertext
                     hoverinfo   = 'text',         # only show hovertext
                     textposition= 'none')
        
      } else {         # grouped bars
        
        p <- plot_ly()
        for (g in names(pal))
          p <- p |> add_bars(data=df_abs |> filter(AddOn==g),
                             x=~Date, y=~Count, name=g,
                             marker=list(color=pal[g]),
                             hovertext   = ~Tooltip,       # use hovertext
                             hoverinfo   = 'text',         # only show hovertext
                             textposition= 'none')
        p <- p |> layout(barmode="group")
      }
      
      ## ---------------- Relative --------------------------------------------------
    } else {
      
      totals <- df_long |> group_by(Date) |> summarise(DayTotal=sum(Count), .groups="drop")
      df_rel <- left_join(df_long, totals, by="Date") |>
        mutate(Share = ifelse(DayTotal==0,0,Count/DayTotal),
               Tooltip = paste0("<b>",format(Date,"%b %d, %Y"),
                                "</b><br>",AddOn,": ",
                                round(Share*100,1)," % (",Count," add‑ons)"))
      
      overall <- df_rel |> group_by(AddOn) |>
        summarise(Total=sum(Count), .groups="drop") |>
        mutate(Cum = Total / sum(Total))
      pct <- setNames(round(overall$Cum*100,1), overall$AddOn)
      
      p <- plot_ly()
      for (g in names(pal))
        p <- p |> add_bars(data=df_rel |> filter(AddOn==g),
                           x=~Date, y=~Share,
                           name=paste0(g," (",pct[g],"%)"),
                           marker=list(color=pal[g]),
                           hovertext   = ~Tooltip,       # use hovertext
                           hoverinfo   = 'text',         # only show hovertext
                           textposition= 'none')
      p <- p |> layout(barmode="stack",
                       yaxis=list(tickformat=".0%"))
    }
    
    p |> layout(
      legend=list(orientation="h",x=0.5,y=1.15,xanchor="center"),
      margin=list(l=40,r=20,t=20,b=60),
      plot_bgcolor="#ffffff",paper_bgcolor="#ffffff",
      font=list(family="Montserrat"))
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
    
    # --- 1. prepare long data ---------------------------------------------
    df <- revenue_data %>%
      filter(Date >= input$selected_date_range[1],
             Date <= input$selected_date_range[2]) %>%
      mutate(Date = as.Date(Date))
    

    
    long <- df %>%
      select(Date, matches("^dtc_")) %>%
      pivot_longer(-Date, names_to = "Seed", values_to = "Count") %>%
      mutate(Seed = sub("^dtc_", "", Seed))
    
    # Grouping logic: by weight or by brand
    if (isTRUE(input$seed_by_weight)) {
      long <- long %>% filter(Seed %in% input$selected_seeds)
    } else {
      long <- long %>%
        mutate(Brand = gsub(" - (8lb|20lb)", "", Seed)) %>%
        filter(Brand %in% input$selected_seeds) %>%
        group_by(Date, Seed = Brand) %>%
        summarise(Count = sum(Count), .groups = "drop")
    }
    
    # desired order for legend and bars
    ordered_levels <- c("Seasonal Curation - 8lb", "Seasonal Curation - 20lb",
                        "Buddy Bites - 8lb",       "Buddy Bites - 20lb",
                        "Snack n' Soar - 8lb",     "Snack n' Soar - 20lb",
                        "Avian Choice - 8lb",      "Avian Choice - 20lb")
    
    if (!isTRUE(input$seed_by_weight)) {
      ordered_levels <- c("Seasonal Curation", "Buddy Bites", "Snack n' Soar", "Avian Choice")
    }
    
    # apply the order
    long$Seed <- factor(long$Seed, levels = ordered_levels)
    
    seed_levels <- levels(long$Seed)[levels(long$Seed) %in% unique(long$Seed)]

pal <- if (length(seed_levels) > 0) {
  setNames(scales::hue_pal()(length(seed_levels)), seed_levels)
} else {
  setNames(character(0), character(0))
}

    
    
    
    # --- 2. absolute -------------------------------------------------------
    if (input$seed_view_mode == "Absolute") {
      
      long <- long %>%
        mutate(TT = paste0("<b>", format(Date, "%b %d, %Y"),
                           "</b><br>", Seed, ": ",
                           Count, " bags"))
      
      if (want_lines_seed()) {
        p <- plot_ly(long, x = ~Date, y = ~Count,
                     color = ~Seed, colors = pal,
                     type = "scatter", mode = "lines+markers",
                     hoverinfo = "text", hovertext = ~TT)
      } else {
        p <- plot_ly(type = "bar")
        for (s in names(pal))
          p <- p %>% add_bars(data = long %>% dplyr::filter(Seed == s),
                              x = ~Date, y = ~Count, name = s,
                              marker = list(color = pal[s]),
                              hoverinfo = "text",
                              hovertext = ~TT)
        p <- p %>% layout(barmode = "group")
      }
      
      # --- 3. relative (100 % stacked) --------------------------------------
    } else {
      
      rel <- long %>%
        dplyr::group_by(Date) %>%
        dplyr::mutate(Total = sum(Count),
                      Share = ifelse(Total == 0, 0, Count/Total),
                      TT = paste0("<b>", format(Date, "%b %d, %Y"),
                                  "</b><br>", Seed, ": ",
                                  round(Share*100, 1), "% (", Count, " bags)")) %>%
        dplyr::ungroup()
      
      # overall % for legend
      leg <- rel %>%
        dplyr::group_by(Seed) %>%
        dplyr::summarise(TT = sum(Count), .groups = "drop") %>%
        dplyr::mutate(Pct = round(TT/sum(TT)*100, 1))
      
      p <- plot_ly(type = "bar")
      for (s in names(pal))
        p <- p %>% add_bars(data = rel %>% dplyr::filter(Seed == s),
                            x = ~Date, y = ~Share,
                            name = paste0(s, " (", leg$Pct[leg$Seed==s], "%)"),
                            marker = list(color = pal[s]),
                            hoverinfo = "text",
                            hovertext = ~TT)
      p <- p %>% layout(barmode = "stack",
                        yaxis   = list(tickformat = ".0%"))
    }
    
    # --- 4. common layout --------------------------------------------------
    p %>% layout(
      legend = list(orientation = "h", x = 0.5, y = 1.15,
                    xanchor = "center", font = list(family = "Montserrat")),
      margin = list(l = 40, r = 20, t = 20, b = 60),
      plot_bgcolor = "#ffffff",
      paper_bgcolor = "#ffffff",
      font = list(family = "Montserrat"))
  })
  
  
  
  
  
  
  
  
  
}


# ---- Run App ----
# Run the application
shinyApp(ui = ui, server = server)

