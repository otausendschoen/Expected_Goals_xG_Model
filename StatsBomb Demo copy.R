#####
#Pulling StatsBomb Free Data Into R
library(tidyverse)
library(StatsBombR)
Comps <- FreeCompetitions()
comps_shots <- Comps %>%
  filter(
    competition_gender == 'male',
    !competition_name %in% c('FIFA U20 World Cup', 'Indian Super league', 'Major League Soccer', 'North American League')
  )

Matches <- FreeMatches(Comps)

Matches_Shots <- Matches

Matches_Passes <- Matches %>%
  filter(year(match_date) >= 2000)

StatsBombData_Shots <- free_allevents(MatchesDF = Matches_Shots, Parallel = T)
StatsBombData_Passes <- free_allevents(MatchesDF = Matches_Passes, Parallel = T)

StatsBombData_Shots = allclean(StatsBombData_Shots)
StatsBombData_Passes = allclean(StatsBombData_Passes)

shots <- StatsBombData_Shots %>%
  filter(type.name == "Shot", !is.na(location)) %>%
  unnest_wider(location, names_sep = "_") %>%
  rename(x = location_1, y = location_2)

passes <- StatsBombData_Passes %>%
  filter(type.name == "Pass", !is.na(location)) %>%
  unnest_wider(location, names_sep = "_") %>%
  rename(x = location_1, y = location_2)

shots <- shots %>%
  left_join(
    Matches %>%
      select(match_id, match_date),
    by = "match_id"
  ) %>%
  left_join(
    Comps %>%
      select(competition_id, season_id, competition_name, season_name),
    by = c("competition_id", "season_id")
  ) %>%
  mutate(match_date = as.Date(match_date))

shots_clean <- shots %>%
  select(
    -carry.end_location,
    -goalkeeper.end_location,
    -tactics.lineup,
    -related_events,
    -shot.freeze_frame,
    -pass.end_location
  ) %>%
  unnest_wider(shot.end_location, names_sep = "_") %>%
  rename(
    shot.end_x = shot.end_location_1,
    shot.end_y = shot.end_location_2
  )

passes <- passes %>%
  left_join(
    Matches %>%
      select(match_id, match_date),
    by = "match_id"
  ) %>%
  left_join(
    Comps %>%
      select(competition_id, season_id, competition_name, season_name),
    by = c("competition_id", "season_id")
  ) %>%
  mutate(match_date = as.Date(match_date))

passes_clean <- passes %>%
  select(
    -carry.end_location,
    -goalkeeper.end_location,
    -tactics.lineup,
    -related_events,
    -shot.end_location,
    -shot.freeze_frame
  ) %>%
  unnest_wider(pass.end_location, names_sep = "_") %>%
  rename(
    pass.end_x = pass.end_location_1,
    pass.end_y = pass.end_location_2
  )

write_csv(shots_clean, "shots.csv")
write_csv(passes_clean, "passes.csv")

### sample code i've used in the past below

#####
##Filtering to Team Shots and Goals
#Totals
shots_goals = StatsBombData %>%
  group_by(team.name) %>%
  summarise(shots = sum(type.name=="Shot", na.rm = TRUE),
            goals = sum(shot.outcome.name=="Goal", na.rm = TRUE))
#Per Match
shots_goals = StatsBombData %>%
  group_by(team.name) %>%
  summarise(shots = sum(type.name=="Shot", na.rm = TRUE)/n_distinct(match_id),
            
            goals = sum(shot.outcome.name=="Goal", na.rm = TRUE)/n_distinct(match_id))
#####
##Filter to Player Shots and Key Passes
#Total
player_shots_keypasses = StatsBombData %>%
  group_by(player.name, player.id) %>%
  summarise(shots = sum(type.name=="Shot", na.rm = TRUE),
            keypasses = sum(pass.shot_assist==TRUE, na.rm = TRUE))
#Get Minutes Data
player_minutes = get.minutesplayed(StatsBombData)
player_minutes = player_minutes %>%
  group_by(player.id) %>%
  summarise(minutes = sum(MinutesPlayed))
#Join Minutes Played Data To Player Shots Dataframe
player_shots_keypasses = left_join(player_shots_keypasses, player_minutes)
player_shots_keypasses = player_shots_keypasses %>% mutate(nineties = minutes/90)
player_shots_keypasses = player_shots_keypasses %>% mutate(shots_per90 =
                                                             shots/nineties,
                                                           
                                                           kp_per90 = keypasses/nineties,
                                                           shots_kp_per90 = shots_per90+kp_per90)

#filter minutes
player_shots_keypasses = player_shots_keypasses %>% filter(minutes>360)

#####
#Passes To The Final Third
passes = StatsBombData %>%
  filter(type.name=="Pass" & is.na(pass.outcome.name)) %>%
  filter(location.x<80 & pass.end_location.x>=80) %>%
  group_by(player.name) %>%
  summarise(f3_passes = sum(type.name=="Pass"))

#####
#Plotting Team Shots and Goals
#Totals
shots_goals = StatsBombData %>%
  group_by(team.name) %>%
  summarise(shots = sum(type.name=="Shot", na.rm = TRUE),
            goals = sum(shot.outcome.name=="Goal", na.rm = TRUE))
#Per Match
shots_goals = StatsBombData %>%
  
  group_by(team.name) %>%
  summarise(shots = sum(type.name=="Shot", na.rm = TRUE)/n_distinct(match_id),
            goals = sum(shot.outcome.name=="Goal", na.rm = TRUE)/n_distinct(match_id))
#Plotting the data
library(ggplot2)
ggplot(data = shots_goals,
       aes(x = reorder(team.name, shots), y = shots)) +
  geom_bar(stat = "identity", width = 0.5) +
  labs(y="Shots") +
  theme(axis.title.y = element_blank()) +
  scale_y_continuous( expand = c(0,0)) +
  coord_flip()
#####
#Plotting Player Shots and Key Passes
#Total
player_shots_keypasses = StatsBombData %>%
  group_by(player.name, player.id) %>%
  summarise(shots = sum(type.name=="Shot", na.rm = TRUE),
            keypasses = sum(pass.shot_assist==TRUE, na.rm = TRUE))
#Get Minutes Data
player_minutes = get.minutesplayed(StatsBombData)
player_minutes = player_minutes %>%
  group_by(player.id) %>%
  summarise(minutes = sum(MinutesPlayed))
#Join Minutes Played Data To Player Shots Dataframe
player_shots_keypasses = left_join(player_shots_keypasses, player_minutes)
player_shots_keypasses = player_shots_keypasses %>% mutate(nineties = minutes/90)
player_shots_keypasses = player_shots_keypasses %>% mutate(shots_per90 =
                                                             shots/nineties,
                                                           
                                                           kp_per90 = keypasses/nineties,
                                                           shots_kp_per90 = shots_per90+kp_per90)

#filter minutes
player_shots_keypasses = player_shots_keypasses %>% filter(minutes>360)
#Creating A Scatter Plot
ggplot(player_shots_keypasses, aes(x = shots_per90, y = kp_per90,
                                   colour = shots_kp_per90, alpha = 0.9)) +
  labs(x = "Shots per 90", y = "Key Passes per 90") +
  geom_point(size = 5, show.legend = FALSE) +
  geom_text(data = player_shots_keypasses, aes(label = player.name),
            colour = "black", size = 5, vjust = -0.5) +
  
  guides(alpha = "none")
#####
#Plotting things on a pitch
library(SBpitch)
passes = StatsBombData %>%
  filter(type.name=="Pass" & is.na(pass.outcome.name)) %>%
  filter(location.x<80 & pass.end_location.x>=80) %>%
  group_by(player.id, player.name) %>%
  summarise(f3_passes = sum(type.name=="Pass"))
#Get Minutes Data
player_minutes = get.minutesplayed(StatsBombData)
player_minutes = player_minutes %>%
  group_by(player.id) %>%
  summarise(minutes = sum(MinutesPlayed))
#Join Minutes Played Data To Player Shots Dataframe
passes = left_join(passes, player_minutes)
passes = passes %>% mutate(nineties = minutes/90)
passes = passes %>% mutate(f3passes_per90 = f3_passes/nineties)
#filter minutes
passes = passes %>% filter(minutes>360) %>%
  arrange(desc(f3passes_per90))
player_passes = StatsBombData %>%
  filter(type.name=="Pass" & is.na(pass.outcome.name) & player.name=="") %>%
  filter(location.x<80 & pass.end_location.x>=80)
create_Pitch() +
  geom_segment(data = player_passes, aes(x = location.x, y = location.y,
                                         xend = pass.end_location.x, yend = pass.end_location.y),
               
               lineend = "round", linewidth = 0.5, colour = "#000000",
               arrow = arrow(length = unit(0.07, "inches"), ends = "last", type = "open")) +
  labs(title = "Player Name, Passes to the final third", subtitle = "Competition") +
  scale_y_reverse() +
  coord_fixed(ratio = 105/100)