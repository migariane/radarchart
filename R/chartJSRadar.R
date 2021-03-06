#' Make a ChartJS Radar Plot
#'
#' R bindings to the radar plot in the chartJS library
#'
#' @param scores Data frame or named list of scores for each axis. 
#' If \code{labs} is not specified then labels are taken from the first column (or element).
#' @param labs Labels for each axis. If left unspecified labels are taken from 
#' the scores data set. If set to NA then labels are left blank.
#' @param width Width of output plot
#' @param height Height of output plot
#' @param main Character: Title to be displayed
#' @param maxScale Max value on each axis
#' @param scaleStepWidth Spacing between rings on radar
#' @param scaleStartValue Value at the centre of the radar
#' @param responsive Logical. whether or not the chart should be responsive and resize when the browser does
#' @param labelSize Numeric. Point label font size in pixels
#' @param showLegend Logical whether to show the legend
#' @param addDots Logical. Whether to show a dot for each point
#' @param colMatrix Numeric matrix of rgb colour values. If \code{NULL} defaults are used
#' @param polyAlpha Alpha value for the fill of polygons
#' @param lineAlpha Alpha value for the outlines
#' @param showToolTipLabel Logical. If \code{TRUE} then data set labels are shown in the tooltip hover over
#' @param ... Extra options passed straight to chart.js. Names must match existing options
#' \url{http://www.chartjs.org/docs/#getting-started-global-chart-configuration}
#'
#' @import htmlwidgets
#' @import htmltools
#'
#' @export
#' @examples 
#' # Using the data frame interface
#' chartJSRadar(scores=skills)
#' 
#' # Or using a list interface
#' labs <- c("Communicator", "Data Wangler", "Programmer", "Technologist",  "Modeller", "Visualizer")
#'
#' scores <- list("Rich" = c(9, 7, 4, 5, 3, 7),
#'  "Andy" = c(7, 6, 6, 2, 6, 9),
#'  "Aimee" = c(6, 5, 8, 4, 7, 6))
#'
#' # Default settings
#' chartJSRadar(scores=scores, labs=labs)
#' 
#' # Fix the max score
#' chartJSRadar(scores=scores, labs=labs, maxScale=10)
#' 
#' # Fix max and spacing
#' chartJSRadar(scores=scores, labs=labs, maxScale=12, scaleStepWidth = 2)
#' 
#' # Change title and remove legend
#' chartJSRadar(scores=scores, labs=labs, main = "Data Science Radar", showLegend = FALSE)
#' 
#' # Add pass through settings for extra options
#' chartJSRadar(scores=scores, labs=labs, maxScale =10, scaleLineWidth=5)
#' 
chartJSRadar <- function(scores, labs, width = NULL, height = NULL, main = NULL,
                         maxScale = NULL, scaleStepWidth = NULL,
                         scaleStartValue = 0, responsive = TRUE, labelSize = 18,
                         showLegend = TRUE,
                         addDots = TRUE, colMatrix = NULL, polyAlpha = .2,
                         lineAlpha = .8, showToolTipLabel = TRUE, ...) {
  
  # Should we keep variable names consistent from chart.js to R?
  # Then we can just pass through anything that doesn't need preprocessing
  
  # If it comes through as a single vector wrap it back up
  if(!is.list(scores)) scores <- list(scores)

  # This block trys to handle different ways the data might
  # not look how we expect. Missings etc.
  if(missing(labs)) {
    if(is.character(scores[[1]]) | is.factor(scores[[1]])) {
      labs <- scores[[1]] # Copy the first column of scores into the labels
      if (length(scores) > 1) { # This catches empty data
        scores[[1]] <- NULL # Drop the labels column
      } else {
        # Add a dummy column with no data
        scores <- data.frame("null"=rep(NA, length(labs)))
      }
    } else {
      stop("if labs is unspecified then the first column of scores must be character data")
    }
  }

  
  
  # If NA is supplied then put blank labels  
  if(all(is.na(labs))) {
    labs <- rep("", length(scores[[1]]))
  }
    
  # Check data is in right shape
  x <- vapply(scores, function(x) length(x)==length(labs), FALSE)
  if(!all(x)) {
    stop("Each score vector must be the same length as the labs vector")
  }
  
  colMatrix <- colourMatrix(colMatrix)
  
  # Check for maxScale
  opScale <- list(scale = list())
  opScale$scale <- setRadarScale(maxScale, scaleStepWidth, scaleStartValue)
  opScale$scale$pointLabels <- list(fontSize = labelSize) 
                                   #fontColor = "#111",
                                   #fontFamily = "Times")
  
  opToolTip <- list(tooltips = list(enabled = showToolTipLabel,
                                    mode = "label"))
  
  # Any extra options passed straight through. Names must match existing options
  # http://www.chartjs.org/docs/#getting-started-global-chart-configuration
  opPassThrough <- list(...)
  
  opTitle <- list(title = list(display = !is.null(main), text = main))

  opLegend <- list(legend = list(display = showLegend))
  
  # Combine scale options, pass through and explicit options
  opList <- c(list(responsive = responsive),
              opTitle, opScale, opToolTip, opLegend, opPassThrough)
              
    
  # forward options using x
  datasets <- lapply(names(scores), function(x) list(label=x))
  
  for (i in seq_along(datasets)) {
    
    iCol <- (i-1) %% ncol(colMatrix) + 1 # cyclic repeat colours

    fillCol <- paste0("rgba(", paste0(colMatrix[ , iCol], collapse=","),
                      ",", polyAlpha, ")")
    lineCol <- paste0("rgba(", paste0(colMatrix[ , iCol], collapse=","), 
                      ",", lineAlpha, ")")
    
    datasets[[i]]$data <- scores[[i]]             # Data Points
    
    datasets[[i]]$backgroundColor  <- fillCol           # Polygon Fill
    datasets[[i]]$borderColor  <- lineCol         # Line Colour
    datasets[[i]]$pointBackgroundColor  <- lineCol          # Point colour
    
    datasets[[i]]$pointBorderColor  <- "#fff"     # Point outline
    datasets[[i]]$pointHoverBackgroundColor  <- "#fff"   # Point Highlight fill
    datasets[[i]]$pointHoverBorderColor <- lineCol # Point Highlight line
    if(!addDots) datasets[[i]]$pointRadius <- 0
  }
  
  x <- list(data = list(labels=labs, datasets=datasets), options = opList)
  
  #print(jsonlite::toJSON(x, pretty = TRUE, auto_unbox = TRUE))
  
  # create widget
  htmlwidgets::createWidget(
    name = "chartJSRadar",
    x,
    width = width,
    height = height,
    package = "radarchart"
  )
}

#' Autoscale the radar plot
#'
#' @param maxScale Numeric length 1. Desired max limit
#' @param scaleStepWidth Numeric length 1. Spacing between rings
#' @param scaleStartValue Numeric length 1. Value of the centre
#'
#' @return A list containing the scale options for chartjs
#'
#' @examples
#' \dontrun{
#' setRadarScale(15, 3)
#' setRadarScale(15, 5, 2)
#' }
setRadarScale <- function(maxScale = NULL, scaleStepWidth = NULL, 
                          scaleStartValue = 0) {
  
  if (!is.null(maxScale)) {
    
    opScale <- list(ticks = list(max = maxScale))
    opScale$ticks$min <- scaleStartValue
    
    # Did they fix the tick points?
    if (!is.null(scaleStepWidth)) {
      opScale$ticks$stepSize <- scaleStepWidth
      opScale$ticks$maxTicksLimit <- 1000
    }
    # else {
    #   if (maxScale-scaleStartValue <= 12) {
    #     opScale$scaleStepWidth <- 1
    #   } else {
    #     opScale$scaleStepWidth <- floor( (maxScale-scaleStartValue) / 10)
    #   }
    # }
    # opScale$scaleSteps <- ceiling( (maxScale - scaleStartValue) / 
    #                                 opScale$scaleStepWidth)
    # opScale$scaleStartValue <- scaleStartValue
  } else {
    if(!is.null(scaleStartValue)) {
      opScale <- list(ticks = list(min = scaleStartValue))
    } else {
      opScale <- list()
    }
  }
  opScale
}

#' Tell htmltools where to output the chart
#' 
#' @param id The id of the target object
#' @param style css stylings
#' @param class class of the target
#' @param width width of target
#' @param height height of target
#' @param ... extra arguments currently unused
#' 
#' @export
chartJSRadar_html <- function(id, style, class, width, height, ...){
  htmltools::tags$canvas(id = id, class = class, width=width, height=height)
}

#' Widget output function for use in Shiny
#'
#' @param outputId output variable to read from
#' @param width Must be valid CSS unit
#' @param height Must be valid CSS unit
#'
#' @export
chartJSRadarOutput <- function(outputId, width = "450", height = "300"){
  shinyWidgetOutput(outputId, "chartJSRadar", width, height, package = "radarchart")
}

#' Widget render function for use in Shiny
#'
#' @param expr expression passed to \link[htmlwidgets]{shinyRenderWidget}
#' @param env environment in which to evaluate expression
#' @param quoted Logical. Is expression quoted?
#'
#' @export
renderChartJSRadar <- function(expr, env = parent.frame(), quoted = FALSE) {
  if (!quoted) { 
    expr <- substitute(expr) 
  } # force quoted
  shinyRenderWidget(expr, chartJSRadarOutput, env, quoted = TRUE)
}
