library(tidyverse)

module_1 <- read_csv("M1_exercise.csv")
head(module_1)

module_1 <- module_1 %>%
  mutate(Gender = as_factor(Gender)) %>%
  mutate(across(c(Program:Q5), factor))



  

