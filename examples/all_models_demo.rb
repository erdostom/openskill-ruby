#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/openskill'

# Demonstrate all 5 OpenSkill rating models

puts 'OpenSkill Ruby - All Models Demo'
puts '=' * 50
puts

# Create teams
def create_teams(model)
  team1 = [model.create_rating(name: 'Alice'), model.create_rating(name: 'Bob')]
  team2 = [model.create_rating(name: 'Charlie'), model.create_rating(name: 'Diana')]
  [team1, team2]
end

def display_ratings(teams, title)
  puts title
  teams.each_with_index do |team, i|
    puts "  Team #{i + 1}:"
    team.each do |player|
      puts "    #{player.name}: μ=#{player.mu.round(2)}, σ=#{player.sigma.round(2)}, " \
           "ordinal=#{player.ordinal.round(2)}"
    end
  end
  puts
end

# 1. Plackett-Luce Model
puts '1. PlackettLuce Model (Algorithm 4)'
puts '   - Multidimensional ability vectors'
puts '   - Recommended as default model'
puts
model = OpenSkill::Models::PlackettLuce.new
teams = create_teams(model)
display_ratings(teams, 'Before match:')
teams = model.calculate_ratings(teams, ranks: [1, 2]) # Team 1 wins
display_ratings(teams, 'After match (Team 1 wins):')

# 2. Bradley-Terry Full Model
puts '2. BradleyTerryFull Model (Algorithm 1)'
puts '   - Full pairing - compares all teams'
puts '   - Logistic regression approach'
puts
model = OpenSkill::Models::BradleyTerryFull.new
teams = create_teams(model)
display_ratings(teams, 'Before match:')
teams = model.calculate_ratings(teams, ranks: [1, 2]) # Team 1 wins
display_ratings(teams, 'After match (Team 1 wins):')

# 3. Bradley-Terry Part Model
puts '3. BradleyTerryPart Model (Algorithm 2)'
puts '   - Partial pairing with sliding window (default size: 4)'
puts '   - More efficient than full pairing'
puts
model = OpenSkill::Models::BradleyTerryPart.new
teams = create_teams(model)
display_ratings(teams, 'Before match:')
teams = model.calculate_ratings(teams, ranks: [1, 2]) # Team 1 wins
display_ratings(teams, 'After match (Team 1 wins):')

# 4. Thurstone-Mosteller Full Model
puts '4. ThurstoneMostellerFull Model (Algorithm 3)'
puts '   - Full pairing with Gaussian CDF'
puts '   - Maximum likelihood estimation'
puts '   - Includes epsilon parameter for draw margin (default: 0.1)'
puts
model = OpenSkill::Models::ThurstoneMostellerFull.new
teams = create_teams(model)
display_ratings(teams, 'Before match:')
teams = model.calculate_ratings(teams, ranks: [1, 2]) # Team 1 wins
display_ratings(teams, 'After match (Team 1 wins):')

# 5. Thurstone-Mosteller Part Model
puts '5. ThurstoneMostellerPart Model (Partial Pairing)'
puts '   - Partial pairing with sliding window'
puts '   - Uses Gaussian CDF with v/w/vt/wt functions'
puts '   - Most efficient Thurstone-Mosteller variant'
puts
model = OpenSkill::Models::ThurstoneMostellerPart.new
teams = create_teams(model)
display_ratings(teams, 'Before match:')
teams = model.calculate_ratings(teams, ranks: [1, 2]) # Team 1 wins
display_ratings(teams, 'After match (Team 1 wins):')

# Prediction example with PlackettLuce
puts '=' * 50
puts 'Prediction Example with PlackettLuce'
puts '=' * 50
puts
model = OpenSkill::Models::PlackettLuce.new
strong = [model.create_rating(mu: 35, sigma: 2, name: 'Pro')]
weak = [model.create_rating(mu: 15, sigma: 2, name: 'Novice')]

probs = model.predict_win_probability([strong, weak])
puts 'Win probabilities:'
puts "  Pro: #{(probs[0] * 100).round(1)}%"
puts "  Novice: #{(probs[1] * 100).round(1)}%"
puts

draw_prob = model.predict_draw_probability([strong, weak])
puts "Draw probability: #{(draw_prob * 100).round(1)}%"
puts

puts 'All models successfully demonstrated!'
