#############################################################
# Assignment 2 (HPI-adapted Murrell examples, individual plots)
# Dataset: HPI 2024 ("1. All countries", skip=7)
# Variables:
#   - GDP per capita ($)
#   - HPI
#   - Ladder of life (Wellbeing) (0-10)
#   - Life Expectancy (years)
#   - Carbon Footprint (tCO2e)
#############################################################

library(readxl)

hpi <- read_excel(
  "~/Desktop/UTD/DV/HPI_2024_public_dataset.xlsx",
  sheet = "1. All countries",
  skip = 7
)


keep <- complete.cases(hpi$`GDP per capita ($)`, hpi$HPI, hpi$`Ladder of life (Wellbeing) (0-10)`)
x_raw <- hpi$`GDP per capita ($)`[keep]
y1_raw <- hpi$HPI[keep]
y2_wb <- hpi$`Ladder of life (Wellbeing) (0-10)`[keep]

ord <- order(x_raw, na.last = NA)
x  <- x_raw[ord]
y1 <- y1_raw[ord]
# Affine transformation(Wellbeing mapping to HPI) 
y2 <- (y2_wb[ord] - min(y2_wb[ord])) / (max(y2_wb[ord]) - min(y2_wb[ord])) *
  (max(y1, na.rm=TRUE) - min(y1, na.rm=TRUE)) + min(y1, na.rm=TRUE)

#############################################################
# Scatterplot (HPI vs Wellbeing, with legend)
#############################################################
plot.new()
plot.window(range(x, na.rm=TRUE), range(c(y1, y2), na.rm=TRUE))
lines(x, y1)
lines(x, y2)
points(x, y1, pch=16, cex=1.2, col="blue")     # HPI
points(x, y2, pch=21, bg="white", cex=1.2)     # Wellbeing (scaled)
axis(1, at=pretty(x))
axis(2, at=pretty(c(y1, y2)))
axis(4, at=pretty(c(y1, y2)))
box(bty="u")
mtext("GDP per capita ($)", side=1, line=2, cex=0.8)
mtext("Wellbeing (scaled)", side=2, line=2, cex=0.8)
mtext("HPI", side=4, line=2, cex=0.8)

text(x[round(length(x)*.3)], max(c(y1,y2), na.rm=TRUE)*0.99, "Scatterplot")

# 加上圖例說明
legend("bottomright",
       legend=c("HPI","Wellbeing (scaled)"),
       pch=c(16,21),
       pt.bg=c(NA,"white"),   # 背景色，HPI不用，Wellbeing是白底
       col=c("blue","black"),
       bty="n", cex=0.8)


#############################################################
# 2. Histogram
#############################################################
Y <- y1
q <- quantile(Y, c(.25,.75), na.rm=TRUE); IQRv <- q[2]-q[1]
Y[Y < q[1]-3*IQRv | Y > q[2]+3*IQRv] <- NA
hist(Y, breaks=pretty(Y), col="gray80", freq=FALSE,
     main="Histogram of HPI", xlab="HPI")
lines(density(na.omit(Y)), lwd=2, col="red")

#############################################################
# 3. Barplot
#############################################################
gdp_grp <- cut(x_raw,
               breaks = quantile(x_raw, probs=c(0,1/3,2/3,1), na.rm=TRUE),
               include.lowest = TRUE,
               labels = c("Low GDP","Middle GDP","High GDP"))

bar_df <- data.frame(
  HPI       = tapply(hpi$HPI[keep], gdp_grp, mean, na.rm=TRUE),
  LifeExp   = tapply(hpi$`Life Expectancy (years)`[keep], gdp_grp, mean, na.rm=TRUE),
  Wellbeing = tapply(hpi$`Ladder of life (Wellbeing) (0-10)`[keep], gdp_grp, mean, na.rm=TRUE),
  Carbon    = tapply(hpi$`Carbon Footprint (tCO2e)`[keep], gdp_grp, mean, na.rm=TRUE)
)
HPIStack <- as.matrix(t(bar_df))

midpts <- barplot(HPIStack,
                  col=gray(0.1 + seq(1, 9, 2)/11),
                  names=rep("", ncol(HPIStack)),
                  main="Barplot of HPI indicators")
mtext(sub(" ", "\n", colnames(HPIStack)),
      at=midpts, side=1, line=0.5, cex=0.7)
text(rep(midpts, each=nrow(HPIStack)),
     apply(HPIStack, 2, cumsum) - HPIStack/2,
     round(HPIStack,1), cex=0.7, col="white")

#############################################################
# 3. Barplot
#############################################################

gdp_grp <- cut(x_raw,
               breaks = quantile(x_raw, probs=c(0,1/3,2/3,1), na.rm=TRUE),
               include.lowest = TRUE,
               labels = c("Low GDP","Middle GDP","High GDP"))

bar_df <- data.frame(
  HPI       = tapply(hpi$HPI[keep], gdp_grp, mean, na.rm=TRUE),
  LifeExp   = tapply(hpi$`Life Expectancy (years)`[keep], gdp_grp, mean, na.rm=TRUE),
  Wellbeing = tapply(hpi$`Ladder of life (Wellbeing) (0-10)`[keep], gdp_grp, mean, na.rm=TRUE),
  Carbon    = tapply(hpi$`Carbon Footprint (tCO2e)`[keep], gdp_grp, mean, na.rm=TRUE)
)
HPIStack <- as.matrix(t(bar_df))

cols <- gray(0.1 + seq(1, 9, 2)/11)

midpts <- barplot(HPIStack,
                  col=cols,
                  names=rep("", ncol(HPIStack)),
                  main="Barplot of HPI indicators")

# x 軸標籤
mtext(sub(" ", "\n", colnames(HPIStack)),
      at=midpts, side=1, line=0.5, cex=0.7)

# 每段柱子上標數字
text(rep(midpts, each=nrow(HPIStack)),
     apply(HPIStack, 2, cumsum) - HPIStack/2,
     round(HPIStack,1), cex=0.7, col="white")

# 圖例放到圖外右邊
legend("topright",
       inset=c(-0.235,0),          # 向右推出去
       legend=rownames(bar_df),  # HPI, LifeExp, Wellbeing, Carbon
       fill=cols,
       bty="n", cex=0.7, xpd=TRUE)
#############################################################
# 4. Boxplot
#############################################################

# 畫圖：HPI (白色, 左側) vs Wellbeing scaled (灰色, 右側)
boxplot(value ~ dose, data = DF,
        subset=supp=="HPI",
        boxwex=0.25, at=1:3-0.2,
        col="white", ylim=range(DF$value, na.rm=TRUE),
        xaxt="n", xlab = "", main="Boxplot: HPI vs Wellbeing (scaled)",
        ylab="Value (HPI scale)")

boxplot(value ~ dose, data = DF,
        subset=supp=="Wellbeing",
        add=TRUE, boxwex=0.25, at=1:3+0.2, col="gray", xaxt="n")

# 手動標 X 軸群組
mtext(c("Low GDP","Middle GDP","High GDP"),
      side=1, at=1:3, line=2, cex=0.8)

# Legend 左上角 + 縮小間距
legend("topleft",
       legend=c("HPI","Wellbeing (scaled)"),
       fill=c("white","gray"),
       bty="n", cex=0.6,
       x.intersp=0.5,  # 水平方向縮小
       y.intersp=0.8)  # 垂直方向縮小
#############################################################
# 5. Persp
#############################################################
xg <- seq(min(hpi$`GDP per capita ($)`, na.rm=TRUE),
          max(hpi$`GDP per capita ($)`, na.rm=TRUE), length=30)
yg <- seq(min(hpi$`Carbon Footprint (tCO2e)`, na.rm=TRUE),
          max(hpi$`Carbon Footprint (tCO2e)`, na.rm=TRUE), length=30)
f_demo <- function(a, b) {
  (a / mean(hpi$`GDP per capita ($)`, na.rm=TRUE)) *
    exp(-b / mean(hpi$`Carbon Footprint (tCO2e)`, na.rm=TRUE)) *
    mean(hpi$HPI, na.rm=TRUE)
}
zg <- outer(xg, yg, Vectorize(f_demo))
persp(xg, yg, zg, theta=30, phi=30, expand=0.5,
      col="lightblue", main="Persp (GDP vs Carbon vs HPI)",
      xlab="GDP per capita", ylab="Carbon Footprint", zlab="HPI (approx.)")
#############################################################
# Persp (真實 HPI 內插)
# x = GDP per capita ($)
# y = Carbon Footprint (tCO2e)
# z = HPI (內插值)
#############################################################

# 載入套件
install.packages("akima")
library(akima)

# 準備資料
df_persp <- data.frame(
  gdp    = hpi$`GDP per capita ($)`,
  carbon = hpi$`Carbon Footprint (tCO2e)`,
  hpi    = hpi$HPI
)

# 移除缺失值
df_persp <- na.omit(df_persp)

# 內插到網格 (30 x 30)
interp_res <- interp(
  x = df_persp$gdp,
  y = df_persp$carbon,
  z = df_persp$hpi,
  nx = 30, ny = 30
)

# 繪製 3D 曲面
persp(interp_res$x, interp_res$y, interp_res$z,
      theta = 30, phi = 30, expand = 0.6,
      col = "lightblue",
      main = "Persp: GDP vs Carbon vs HPI (Interpolated)",
      xlab = "GDP per capita ($)",
      ylab = "Carbon Footprint (tCO2e)",
      zlab = "HPI")
#############################################################
# 6. Piechart
#############################################################
carbon_diff <- hpi$`Carbon Footprint (tCO2e)` - 
  hpi$`CO2 threshold for year  (tCO2e)`

carbon_status <- ifelse(carbon_diff > 0,
                        "Above Threshold", "Within Threshold")

pie_sales <- prop.table(table(carbon_status))

pie(pie_sales,
    col=c("darkred","lightgreen"),
    labels=paste0(names(pie_sales), ": ",
                  round(100*pie_sales,1), "%"),
    main="Carbon Footprint vs CO2 Threshold")

