library(readxl)
library(ggplot2)
library(reshape2)

hpi <- read_excel(
  "~/Desktop/UTD/DV/HPI_2024_public_dataset.xlsx",
  sheet = "1. All countries",
  skip = 7
)
head(hpi)
colnames(hpi)


# heat map
num_data <- hpi[, c("Life Expectancy (years)", 
                    "Ladder of life (Wellbeing) (0-10)",
                    "Carbon Footprint (tCO2e)",
                    "HPI", 
                    "CO2 threshold for year  (tCO2e)",
                    "GDP per capita ($)")]

cor_matrix <- cor(num_data, use = "complete.obs")

melted_cor <- melt(cor_matrix)

ggplot(melted_cor, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "skyblue", high = "darkred", mid = "white",
                       midpoint = 0, limit = c(-1,1), name = "Correlation") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1)) +
  labs(title = "Correlation Heatmap of HPI Components")

# adjusted data set
library(dplyr)

hpi2 <- hpi %>%
  mutate(`Carbon Difference (tCO2e)` = `Carbon Footprint (tCO2e)` - 3.17) %>%
  select(-`CO2 threshold for year  (tCO2e)`)

head(hpi2)

# new heat map
num_data2 <- hpi2[, c("Life Expectancy (years)", 
                      "Ladder of life (Wellbeing) (0-10)",
                      "HPI", 
                      "GDP per capita ($)",
                      "Carbon Footprint (tCO2e)",
                      "Carbon Difference (tCO2e)")]

cor_matrix2 <- cor(num_data2, use = "complete.obs")
melted_cor2 <- melt(cor_matrix2)
ggplot(melted_cor2, aes(Var1, Var2, fill = value)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "skyblue", high = "darkred", mid = "white",
                       midpoint = 0, limit = c(-1,1), name = "Correlation") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, vjust = 1, hjust = 1),
        axis.text.y = element_text(size = 10)) +
  labs(title = "Correlation Heatmap of HPI Components (Cleaned)")

# scatter plot(HPI & Carbon Difference & Continent)
ggplot(na.omit(hpi2), aes(x = `Carbon Difference (tCO2e)`, 
                          y = HPI, 
                          color = as.factor(Continent))) +  # 把數字轉成 factor
  geom_point(size = 3, alpha = 0.7) +
  geom_hline(yintercept = mean(hpi2$HPI, na.rm = TRUE), 
             linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = 0, 
             linetype = "dashed", color = "red") +
  theme_minimal() +
  scale_color_manual(
    values = c(
      "1" = "brown",
      "2" = "blue",
      "3" = "skyblue",
      "4" = "darkgreen",
      "5" = "pink",
      "6" = "gold",
      "7" = "purple",
      "8" = "yellow"
      
    ),
    labels = c(
      "1" = "Latin America",
      "2" = "North America & Oceania",
      "3" = "Europe",
      "4" = "MENA",            # Middle East & North Africa
      "5" = "Africa",
      "6" = "South Asia",
      "7" = "Eastern Europe/Central Asia",
      "8" = "East Asia"
    )
  ) +
  labs(title = "HPI vs Carbon Difference vs Continent",
       x = "Carbon Difference (tCO2e) (Footprint - threshold)",
       y = "Happy Planet Index (HPI)",
       color = "Continent")

# HPI & GDP & Continent
# scatter plot (HPI & GDP & Continent)
ggplot(na.omit(hpi2), aes(x = `GDP per capita ($)`, 
                          y = HPI, 
                          color = as.factor(Continent))) +
  geom_point(size = 3, alpha = 0.7) +
  geom_hline(yintercept = mean(hpi2$HPI, na.rm = TRUE), 
             linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = mean(hpi2$`GDP per capita ($)`, na.rm = TRUE), 
             linetype = "dashed", color = "red") +
  theme_minimal() +
  scale_color_manual(
    values = c(
      "1" = "brown",
      "2" = "blue",
      "3" = "skyblue",
      "4" = "darkgreen",
      "5" = "pink",
      "6" = "gold",
      "7" = "purple",
      "8" = "yellow"
    ),
    labels = c(
      "1" = "Latin America",
      "2" = "North America & Oceania",
      "3" = "Europe",
      "4" = "MENA",
      "5" = "Africa",
      "6" = "South Asia",
      "7" = "Eastern Europe/Central Asia",
      "8" = "East Asia"
    )
  ) +
  labs(title = "HPI vs GDP per capita vs Continent",
       x = "GDP per capita ($)",
       y = "Happy Planet Index (HPI)",
       color = "Continent")

# Choropleth Map
library(rnaturalearth)
library(rnaturalearthdata)

world <- ne_countries(scale = "medium", returnclass = "sf")
world_hpi <- merge(world, hpi, by.x = "iso_a3", by.y = "ISO", all.x = TRUE)

ggplot(world_hpi) +
  geom_sf(aes(fill = HPI)) +
  scale_fill_gradient(low = "purple", high = "yellow",na.value = "white") +
  theme_minimal() +
  labs(title = "Global HPI Distribution")




