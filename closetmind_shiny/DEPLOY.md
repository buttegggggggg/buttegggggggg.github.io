# ClosetMind Shiny Demo — Deploy Guide

Single-file Shiny app (`app.R`) that mocks the desktop app's three core
flows for graders / class audience preview. Deploy to **shinyapps.io**
free tier, then embed the resulting URL in `closetmind.qmd`.

## Prereqs

```r
install.packages(c("shiny", "bslib", "rsconnect"))
```

## One-time account setup

1. Sign up at <https://www.shinyapps.io/> (free tier: 5 apps, 25 active
   hours / month — plenty for a class demo).
2. Account → Tokens → "Show" → copy the three lines that look like:

   ```r
   rsconnect::setAccountInfo(
     name   = "your-username",
     token  = "ABC123...",
     secret = "xyz789..."
   )
   ```

3. Paste into RStudio / R console once.

## Deploy

From the project root (one level above this folder):

```r
rsconnect::deployApp("closetmind_shiny", appName = "closetmind-demo")
```

First deploy takes ~3-5 minutes (shinyapps.io installs `shiny` + `bslib`
in a fresh container). Subsequent deploys are ~30 seconds.

The app will be live at:
```
https://your-username.shinyapps.io/closetmind-demo/
```

## Embed in the Quarto site

Edit `closetmind.qmd`, after the hero section, drop in:

````markdown
## Live demo

```{=html}
<iframe src="https://your-username.shinyapps.io/closetmind-demo/"
        width="100%" height="800"
        style="border:1px solid #ccc;border-radius:10px;"
        loading="lazy">
</iframe>
```
````

Then `quarto render closetmind.qmd && git add docs/closetmind.html
&& git commit && git push`.

## What the demo shows

Three tabs, each demonstrating a real concept from the desktop app:

| Tab | Demonstrates |
|---|---|
| **Upload** | The metadata-driven upload form. Adds items to an in-memory closet (no real DB — page refresh resets). |
| **Closet** | Grid of items with emoji as photo placeholders. Mirrors the real `/closet` page layout. |
| **Recommend** | A tiny version of the layer-coverage scoring: pick context (temperature + occasion) → top 3 outfits ranked by warmth-target gap, formality floor enforced as a hard filter. |

The scoring formula is intentionally simplified — the real app uses
XGBoost classifiers chained across three stages (temperature × aesthetic
× occasion). Showing the full ML pipeline in a stateless Shiny demo
isn't worth the complexity; the goal here is the **UI concept**, not
the model.

## Cost / lifecycle

- shinyapps.io free tier sleeps the app after 15 min of inactivity;
  first visitor after that waits ~10 sec for cold start. Acceptable
  for a class demo.
- 25 active hours / month is more than enough for graders to click
  through twice each.
- If the app gets popular and you want it always-warm, the Starter
  plan is $9/month. Not needed for class.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| `Error: Account not configured` | You forgot step 2 of one-time setup. Re-run `rsconnect::setAccountInfo(...)`. |
| Deploy succeeds but the app shows "Disconnected from server" | Free-tier instance ran out of memory. The mock data is tiny so this should never happen — but if it does, add `options(shiny.maxRequestSize = 10*1024^2)` and retry. |
| Emojis render as `?` boxes in the deployed app | Browser font issue, not a Shiny problem. Modern browsers all render emoji natively; if testing on a fresh Linux install, install `fonts-noto-color-emoji`. |
