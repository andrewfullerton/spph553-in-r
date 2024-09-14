library(tidyverse)

#Question 1
m1 <- read_csv("M1_exercise.csv")
head(m1)

#Question 2
m1_clean <- m1 %>%
  mutate(across(c(Gender, Program:Q5), factor)) #%>%
  #mutate(across(Q1:Q5 ~ fct_recode(.,
                    #"strongly disagree" = "1",
                    #"disagree" = "2",
                    #"neutral" = "3",
                    #"agree" = "4",
                    #"strongly agree" = "5")))

#Question 8
m1_clean_age <- m1_clean %>%
  mutate(age_group = if_else(Age > 31, "31 or older", "30 and under"))

#Question 9
m1_clean_age %>%
  group_by(age_group) %>%
  summarize(across(Q1:Q5, ~ mean(as.numeric(.), na.rm = TRUE), .names = "mean_{col}"))

#Question 10
m1_clean_age_rescore <- m1_clean_age %>%
  mutate(across(Q1:Q5, ~ as.numeric(.))) %>%
  mutate(Q1 = 6-Q1, 
         Q3 = 6-Q3) %>%
  mutate(attitude = (Q1+Q2+Q3+Q4+Q5)/5)

