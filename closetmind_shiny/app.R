# =============================================================================
#  ClosetMind — Shiny Demo
# =============================================================================
#  A small, self-contained mock of the real desktop application. Three tabs:
#    1. Upload   — fake form, adds a row to the in-memory closet
#    2. Closet   — grid of items with emoji placeholders
#    3. Recommend — temperature slider + occasion dropdown → picks top-3 outfits
#
#  Scoring is a simplified version of the real Phase-1 layer-coverage model
#  from the desktop app — enough to show how warmth and formality interact,
#  not the full XGBoost three-stage chain (which needs trained models).
#
#  The intent here is to give a graders / class audience an interactive
#  preview of the UI concept without requiring them to install the full
#  desktop app. The real implementation lives at:
#    https://buttegggggggg.github.io/closetmind.html
#
#  Deploy: see DEPLOY.md sibling file. Single-file `app.R`, no external
#  data files (mock items are embedded), so it works from a fresh deploy
#  with zero file-staging.
# =============================================================================

library(shiny)
library(bslib)

# ---- Mock wardrobe ---------------------------------------------------------
# Each row is one piece of clothing. `emoji` stands in for a photo since the
# real app uses uploaded images. `warmth` is the same 1–4 scale the desktop
# app uses for thickness (very_thin → very_thick); `formality` is 0–5
# matching the OUTFIT_FORMALITY enum in the real backend.
mock_items <- data.frame(
  id        = 1:14,
  name      = c("White Cotton Tee", "Navy Oxford Shirt", "Black T-Shirt",
                "Beige Knit Sweater", "Charcoal Suit Jacket", "Black Down Puffer",
                "Light-Wash Jeans", "Beige Chinos", "Black Tuxedo Trousers",
                "Khaki Shorts",
                "White Sneakers", "Brown Chelsea Boots", "Black Leather Shoes",
                "Navy Wool Scarf"),
  category  = c("top","top","top","top","top","top",
                "bottom","bottom","bottom","bottom",
                "shoes","shoes","shoes",
                "accessory"),
  warmth    = c(1, 2, 1, 3, 4, 4,    2, 2, 3, 1,    2, 3, 2, 4),
  formality = c(1, 3, 1, 2, 5, 2,    1, 3, 5, 1,    1, 3, 5, 3),
  emoji     = c("👕","👔","👕","🧥","🤵","🧥",
                "👖","👖","👖","🩳",
                "👟","🥾","👞",
                "🧣"),
  stringsAsFactors = FALSE
)

# Recommendation logic — small but real ---------------------------------------
# Mirrors the actual desktop app's Phase 1 layer-coverage model in spirit:
#   • warmth budget per temperature (cold day = need more warmth, hot day = less)
#   • formality floor per occasion (casual/work/formal)
#   • outfit = one top + one bottom + one shoe; pick the combination whose
#     total warmth lands closest to the target and meets the formality floor
TARGET_WARMTH <- function(temp_c) {
  # Same shape as the real IDEAL_WARMTH_TABLE — linear-ish from very-warm
  # (3 at 30 °C) up to thick-coat territory (10 at 0 °C).
  pmax(2.5, pmin(11, 10 - 0.27 * temp_c))
}
FORMALITY_MIN <- list(
  casual = 0, work = 2, formal = 4, sport = 0, home = 0
)

generate_outfits <- function(items, temp_c, occasion, n = 3) {
  tops    <- items[items$category == "top",    , drop = FALSE]
  bottoms <- items[items$category == "bottom", , drop = FALSE]
  shoes   <- items[items$category == "shoes",  , drop = FALSE]
  if (nrow(tops) == 0 || nrow(bottoms) == 0 || nrow(shoes) == 0) {
    return(NULL)
  }

  target <- TARGET_WARMTH(temp_c)
  fm     <- FORMALITY_MIN[[occasion]] %||% 0

  # Cartesian product of tops × bottoms × shoes — small enough at 14 items
  combos <- expand.grid(
    t = tops$id, b = bottoms$id, s = shoes$id,
    KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
  )

  # Score each combo: closer to target warmth = better; below formality
  # floor = excluded entirely
  combos$total_warmth <- tops$warmth[match(combos$t, tops$id)] +
                        bottoms$warmth[match(combos$b, bottoms$id)] +
                        shoes$warmth[match(combos$s, shoes$id)]
  combos$min_form <- pmin(
    tops$formality[match(combos$t, tops$id)],
    bottoms$formality[match(combos$b, bottoms$id)],
    shoes$formality[match(combos$s, shoes$id)]
  )
  combos <- combos[combos$min_form >= fm, , drop = FALSE]
  if (nrow(combos) == 0) return(NULL)

  combos$dist <- abs(combos$total_warmth - target)
  combos <- combos[order(combos$dist), , drop = FALSE]
  head(combos, n)
}

# Tiny null-coalescing operator (R doesn't ship with one)
`%||%` <- function(a, b) if (is.null(a)) b else a

# UI helpers ------------------------------------------------------------------
item_card <- function(it) {
  div(class = "cm-card",
    div(class = "cm-card-emoji", it$emoji),
    div(class = "cm-card-name", it$name),
    div(class = "cm-card-meta",
        sprintf("%s · warmth %d · formality %d",
                it$category, it$warmth, it$formality))
  )
}

outfit_block <- function(rank, combo, items) {
  pieces <- items[items$id %in% c(combo$t, combo$b, combo$s), , drop = FALSE]
  div(class = "cm-outfit",
    div(class = "cm-outfit-rank", paste0("#", rank)),
    div(class = "cm-outfit-pieces",
      lapply(seq_len(nrow(pieces)), function(i) {
        div(class = "cm-outfit-piece",
            div(class = "cm-outfit-emoji", pieces$emoji[i]),
            div(class = "cm-outfit-name",  pieces$name[i]))
      })),
    div(class = "cm-outfit-meta",
        sprintf("Total warmth %.0f · target %.1f · gap %.1f",
                combo$total_warmth, TARGET_WARMTH_GLOBAL, combo$dist))
  )
}

# Hack: stash target warmth so outfit_block can reference it without
# threading it through props
TARGET_WARMTH_GLOBAL <- 6

# UI --------------------------------------------------------------------------
ui <- page_fluid(
  theme = bs_theme(version = 5, primary = "#111", base_font = font_google("Inter")),
  tags$head(tags$style(HTML("
    body { background: #f6f6f4; }
    .cm-header {
      text-align: center; padding: 28px 16px 16px;
      border-bottom: 1px solid #eee; margin-bottom: 18px;
    }
    .cm-header h1 { margin: 0; font-weight: 800; letter-spacing: -0.5px; }
    .cm-header p { color: #888; margin: 4px 0 0; font-size: 0.9rem; }
    .cm-grid {
      display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
      gap: 12px;
    }
    .cm-card {
      background: #fff; border: 1px solid #ececec; border-radius: 10px;
      padding: 14px; text-align: center;
    }
    .cm-card-emoji { font-size: 2.6rem; line-height: 1; margin-bottom: 6px; }
    .cm-card-name  { font-weight: 600; font-size: 0.92rem; color: #111; margin-bottom: 3px; }
    .cm-card-meta  { font-size: 0.74rem; color: #888; }

    .cm-outfit {
      background: #fff; border: 1px solid #ececec; border-radius: 12px;
      padding: 18px; margin-bottom: 14px;
    }
    .cm-outfit-rank {
      display: inline-block; background: #111; color: #fff;
      padding: 3px 10px; border-radius: 6px; font-weight: 700;
      font-size: 0.85rem; margin-bottom: 10px;
    }
    .cm-outfit-pieces {
      display: flex; gap: 14px; flex-wrap: wrap; align-items: flex-start;
    }
    .cm-outfit-piece { text-align: center; flex: 1; min-width: 80px; }
    .cm-outfit-emoji { font-size: 2.2rem; line-height: 1; margin-bottom: 4px; }
    .cm-outfit-name  { font-size: 0.82rem; color: #444; }
    .cm-outfit-meta  {
      margin-top: 10px; padding-top: 10px;
      border-top: 1px dashed #eee;
      color: #999; font-size: 0.8rem;
    }
    .cm-form-row { margin-bottom: 14px; }
    .well, .panel { box-shadow: none !important; }
  "))),

  div(class = "cm-header",
      h1("ClosetMind"),
      p("Wardrobe Recommendation — Shiny Demo")),

  navset_tab(
    # ---- Upload tab ----
    nav_panel("Upload",
      div(style = "max-width: 560px; margin: 0 auto;",
        h3("Mock upload"),
        p(style = "color:#777;",
          "This mirrors the real desktop app's upload form.",
          " For the demo, image processing is skipped — only the metadata is recorded."),
        div(class = "cm-form-row",
            textInput("up_name", "Name", placeholder = "e.g. Burgundy Cardigan")),
        div(class = "cm-form-row",
            selectInput("up_category", "Category",
                        choices = c("top","bottom","shoes","accessory"),
                        selected = "top")),
        fluidRow(
          column(6, sliderInput("up_warmth",   "Warmth (1=very thin → 4=very thick)",
                                min = 1, max = 4, value = 2, step = 1)),
          column(6, sliderInput("up_formality","Formality (0=athletic → 5=tuxedo)",
                                min = 0, max = 5, value = 2, step = 1))),
        div(class = "cm-form-row",
            textInput("up_emoji", "Visual placeholder (emoji)",
                      value = "👕", placeholder = "Pick any emoji")),
        actionButton("up_submit", "Add to closet",
                     class = "btn btn-primary btn-lg",
                     style = "width:100%;"),
        div(style = "margin-top:14px;color:#2a8c2a;text-align:center;",
            textOutput("up_status"))
      )
    ),

    # ---- Closet tab ----
    nav_panel("Closet",
      div(style = "padding: 4px 0 12px;",
        textOutput("closet_count")),
      uiOutput("closet_grid")
    ),

    # ---- Recommend tab ----
    nav_panel("Recommend",
      fluidRow(
        column(4,
          h4("Today's context"),
          sliderInput("rec_temp", "Temperature (°C)",
                      min = -5, max = 35, value = 18, step = 1),
          selectInput("rec_occasion", "Occasion",
                      choices = c("casual","work","formal","sport","home"),
                      selected = "casual"),
          actionButton("rec_run", "Recommend",
                       class = "btn btn-primary btn-lg",
                       style = "width:100%;")),
        column(8,
          h4("Top 3 outfits"),
          uiOutput("rec_output"))
      )
    )
  ),

  div(style = "text-align:center;padding:30px 16px;color:#aaa;font-size:0.82rem;",
      "Demo · ",
      a(href = "https://buttegggggggg.github.io/closetmind.html",
        target = "_blank", style = "color:#666;",
        "Back to full project page →"))
)

# Server ----------------------------------------------------------------------
server <- function(input, output, session) {
  closet <- reactiveVal(mock_items)

  # ---- Upload handler ----
  observeEvent(input$up_submit, {
    name <- trimws(input$up_name %||% "")
    if (nchar(name) == 0) {
      showNotification("Please enter a name first.", type = "warning")
      return()
    }
    new_row <- data.frame(
      id        = max(closet()$id) + 1L,
      name      = name,
      category  = input$up_category,
      warmth    = as.integer(input$up_warmth),
      formality = as.integer(input$up_formality),
      emoji     = input$up_emoji %||% "👕",
      stringsAsFactors = FALSE
    )
    closet(rbind(closet(), new_row))
    output$up_status <- renderText({
      sprintf("Added '%s' to your closet (now %d items).",
              name, nrow(closet()))
    })
    updateTextInput(session, "up_name", value = "")
  })

  # ---- Closet grid ----
  output$closet_count <- renderText({
    sprintf("%d items in closet · %d tops, %d bottoms, %d shoes, %d accessories",
            nrow(closet()),
            sum(closet()$category == "top"),
            sum(closet()$category == "bottom"),
            sum(closet()$category == "shoes"),
            sum(closet()$category == "accessory"))
  })
  output$closet_grid <- renderUI({
    items <- closet()
    div(class = "cm-grid",
        lapply(seq_len(nrow(items)), function(i) item_card(items[i, ])))
  })

  # ---- Recommendation ----
  rec_state <- reactiveValues(combos = NULL, items = NULL,
                              temp = NULL, occasion = NULL)

  observeEvent(input$rec_run, {
    items <- closet()
    combos <- generate_outfits(items, input$rec_temp, input$rec_occasion, n = 3)
    rec_state$combos   <- combos
    rec_state$items    <- items
    rec_state$temp     <- input$rec_temp
    rec_state$occasion <- input$rec_occasion
  })

  output$rec_output <- renderUI({
    if (is.null(rec_state$combos)) {
      return(div(style = "color:#888;padding:20px;",
                 "Set the temperature and occasion, then click Recommend."))
    }
    if (nrow(rec_state$combos) == 0) {
      return(div(style = "color:#c66;padding:20px;",
                 "No outfit in your closet matches both the warmth target and ",
                 "the formality floor for this context."))
    }
    target <- TARGET_WARMTH(rec_state$temp)
    # update the global so outfit_block can show the gap
    TARGET_WARMTH_GLOBAL <<- target

    items <- rec_state$items
    blocks <- lapply(seq_len(nrow(rec_state$combos)), function(i) {
      outfit_block(i, rec_state$combos[i, ], items)
    })
    tagList(
      div(style = "color:#888;font-size:0.85rem;margin-bottom:10px;",
          sprintf("Context: %d°C · %s · target warmth %.1f",
                  rec_state$temp, rec_state$occasion, target)),
      blocks
    )
  })
}

shinyApp(ui, server)
