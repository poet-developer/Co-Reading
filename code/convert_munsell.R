library(munsell)
library(grDevices)

munsell_to_rgb_hex_print <- function(munsell_code) {

  # ✅ 1) Neutral (N 계열) 처리
  if (grepl("^N", munsell_code)) {
    value <- as.numeric(sub("N", "", munsell_code))
    gray <- round((value / 10) * 255)

    rgb <- matrix(c(gray, gray, gray), nrow = 3)
    rownames(rgb) <- c("red", "green", "blue")

    hex <- rgb(gray, gray, gray, maxColorValue = 255)

  } else {
    # ✅ 2) 일반 Munsell (유채색)
    hex <- mnsl2hex(munsell_code, fix = TRUE)
    rgb <- col2rgb(hex)
  }

  cat("Munsell code:", munsell_code, "\n")
  cat("HEX:", hex, "\n")
  cat("RGB:\n")
  print(rgb)
}
# Example usage:
munsell_to_rgb_hex_print("7.5Y 9/10")
# munsell_to_rgb_hex_print("N1")