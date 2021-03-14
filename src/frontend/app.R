require("shiny")
library(leaflet)
library(tidyverse)
library(vroom)
library(shinycssloaders)
library(highcharter)
library(RSQLite)
library(stringr)
library(xts)

options(digits = 2)


ui <-fluidPage(
  tags$head(
    tags$script(src="https://cdnjs.cloudflare.com/ajax/libs/iframe-resizer/3.5.16/iframeResizer.contentWindow.min.js",
                type="text/javascript")
  ),
  
  # Header
  headerPanel(
    title=tags$a(href='http://www.hidrosaf.com',tags$img(src='https://www.metu.edu.tr/system/files/logo_orj/5/5.4.jpg', height = 125, width = 100*2.85*1.75), target="_blank"),
    tags$head(tags$link(rel = "icon", type = "image/png", href = "dwq_logo_small.png"), windowTitle="Lake profile dashboard")
  ),
  
  #,
  
  # Input widgets
  fluidRow(
    column(7,
           tabsetPanel(id="ui_tab",
                       tabPanel("Map",
                                column(12,shinycssloaders::withSpinner(leaflet::leafletOutput("map", height="600px"),size=2, color="#0080b7"))
                       )
           ),
    ),
    column(5,tabsetPanel(id="plot_tabs",
                         
                         tabPanel("Plot",
                                  fluidRow(column(12,h4("Remotely sensed ponds"),
                                                  withSpinner(
                                                    highchartOutput(outputId = "plot", height = "600px")
                                                  ),))),
                         tabPanel("Table",
                                  fluidRow(column(12,
                                                  withSpinner(
                                                    DT::dataTableOutput(outputId = "table", height = "600px")
                                                  ),)))
                         
                         
    ))))

server <- function(input, output, session){
  
  
  reactive_objects=reactiveValues()
  reactive_objects$Station <- '03-18'
  
  
  data_file <- './data/Data.db'
  conn <- dbConnect(RSQLite::SQLite(), data_file)
  station_file <- './data/stations.geojson'
  river_file <- './data/river.geojson'
  query = "SELECT * FROM Discharge d where d.Station = '03-18';"
  data = dbGetQuery(conn, query)
  data <- rapply(object = data, f = round, classes = "numeric", how = "replace", digits = 6) 
  
  stations <-  rgdal::readOGR(station_file)
  rivers <-  rgdal::readOGR(river_file)
  mypalette <- colorNumeric( palette="viridis", domain=pond_polygon$id, na.color="transparent")
  
  
  map = leaflet::createLeafletMap(session, 'map')
  
  session$onFlushed(once = T, function() {
    
    
    content <- paste(sep = "<br/>",
                     "<b><a href='http://www.samurainoodle.com'>Samurai Noodle</a></b>",
                     "606 5th Ave. S",
                     "Seattle, WA 98138"
    )
    
    
    output$map <- leaflet::renderLeaflet({
      # buildMap(sites=prof_sites, plot_polys=TRUE, au_poly=lake_aus)
      leaflet() %>%
        addProviderTiles("Esri.WorldImagery") %>%
        setView(lng = 35, lat = 35, zoom = 6) %>%
        addMarkers(
          data = stations,
          # label = paste0(pond_point$Name),
          popup = paste0(
            "<b>Name: </b>"
            , stations$Name
            , "<br>"
            ,"<b>Station No: </b>"
            , stations$Station
            , "<br>"
            ,"<b>Elevation : </b>"
            , stations$Elevation ," m"
            , "<br>"
            ,"<b>Basin Area: </b>"
            , stations$Basin_Area , "m"
          ),
          # labelOptions = labelOptions(noHide = F),
          layerId = ~Station,
          clusterOptions = markerClusterOptions()) %>%
        setMaxBounds( lng1 = 25
                      , lat1 = 35
                      , lng2 = 45
                      , lat2 = 45
        ) %>%
        addPolylines(data=rivers,weight = 1,opacity = 0.5)
    })
    
    output$plot <- renderHighchart({
      
      station <- reactive_objects$Station
      query = str_interp("SELECT * FROM Discharge d where d.Station = '${station}';")
      # query = "SELECT * FROM Discharge d"
      data = dbGetQuery(conn, query)
      data$Dischage <- as.numeric(data$Dischage)
      data <- rapply(object = data, f = round, classes = "numeric", how = "replace", digits = 6) 
      dfx = xts(data$Dischage, order.by=as.Date(data$Date))
      
      highchart(type = "stock") %>% 
        hc_title(text = paste("Observed discharge at station : ",station)) %>%
        hc_add_series(dfx, yAxis = 0,name = "Observed") %>%
      hc_add_yAxis(nid = 1L, title = list(text = "Discharge m3/s"), relative = 4) %>%
        hc_xAxis(
          type = 'datetime') %>%
        hc_legend(enabled = TRUE) %>%
        hc_tooltip(
          crosshairs = TRUE,
          backgroundColor = "#F0F0F0",
          shared = TRUE, 
          borderWidth = 5
        )
    })
    
    
    output$table <- DT::renderDataTable({
      
      station <- reactive_objects$Station
      query = str_interp("SELECT * FROM Discharge d where d.Station = '${station}';")
      # query = "SELECT * FROM Discharge d"
      data = dbGetQuery(conn, query)
      data$Dischage <- as.numeric(data$Dischage)
      data <- select(data,"Date","Dischage")
      DT::datatable(data,  extensions = 'Buttons',options = list(dom = 'Blfrtip',
                                          buttons = c('copy', 'csv', 'excel', 'pdf', 'print'),
                                          lengthMenu = list(c(10,25,50,-1),
                                                            c(10,25,50,"All"))))
    },
    options = 
      list(sPaginationType = "two_button")
    )
    
    output$pond_stat <- DT::renderDataTable({
    })
    
  })
  
  observe({
    click <- input$map_marker_click
    if (is.null(click)){return()}
    p <- input$map_marker_click$id
    # siteid=site_click$id
    # reactive_objects$sel_mlid=siteid
    reactive_objects$Station=p
    print(reactive_objects$Station)
  })

}

shinyApp(ui = ui, server = server)
