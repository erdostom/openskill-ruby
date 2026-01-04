#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating basic OpenSkill usage

require_relative '../lib/openskill'

puts "OpenSkill Ruby Example\n"
puts '=' * 50

# Create a model
model = OpenSkill::Models::PlackettLuce.new

puts "\n1. Simple 1v1 Match"
puts '-' * 50

# Create two players
alice = model.create_rating(name: 'Alice')
bob = model.create_rating(name: 'Bob')

puts 'Before match:'
puts "  Alice: mu=#{alice.mu.round(2)}, sigma=#{alice.sigma.round(2)}, ordinal=#{alice.ordinal.round(2)}"
puts "  Bob:   mu=#{bob.mu.round(2)}, sigma=#{bob.sigma.round(2)}, ordinal=#{bob.ordinal.round(2)}"

# Alice beats Bob
updated = model.calculate_ratings([[alice], [bob]])
alice, bob = updated.flatten

puts "\nAfter match (Alice wins):"
puts "  Alice: mu=#{alice.mu.round(2)}, sigma=#{alice.sigma.round(2)}, ordinal=#{alice.ordinal.round(2)}"
puts "  Bob:   mu=#{bob.mu.round(2)}, sigma=#{bob.sigma.round(2)}, ordinal=#{bob.ordinal.round(2)}"

puts "\n2. Team Match (2v2)"
puts '-' * 50

charlie = model.create_rating(name: 'Charlie')
dave = model.create_rating(name: 'Dave')

puts 'Team 1: Alice + Bob'
puts 'Team 2: Charlie + Dave'

# Team 1 wins
teams = [[alice, bob], [charlie, dave]]
updated = model.calculate_ratings(teams)

puts "\nAfter match (Team 1 wins):"
updated.each_with_index do |team, idx|
  puts "  Team #{idx + 1}:"
  team.each do |player|
    puts "    #{player.name}: ordinal=#{player.ordinal.round(2)}"
  end
end

puts "\n3. Free-For-All (4 players)"
puts '-' * 50

# Final ranking: Charlie > Alice > Dave > Bob
teams = [[alice], [bob], [charlie], [dave]]
updated = model.calculate_ratings(teams, ranks: [1, 3, 0, 2])

players = updated.flatten.sort_by(&:ordinal).reverse

puts 'Final rankings (by ordinal):'
players.each_with_index do |player, idx|
  puts "  #{idx + 1}. #{player.name}: #{player.ordinal.round(2)}"
end

puts "\n4. Win Probability Prediction"
puts '-' * 50

probs = model.predict_win_probability([[alice], [bob], [charlie], [dave]])

puts 'Predicted win probabilities:'
%w[Alice Bob Charlie Dave].each_with_index do |name, idx|
  puts "  #{name}: #{(probs[idx] * 100).round(1)}%"
end

puts "\n5. Score-Based Match"
puts '-' * 50

# Reset ratings for demo
p1 = model.create_rating(name: 'Player 1')
p2 = model.create_rating(name: 'Player 2')

# Player 1 wins with a score of 100 vs 50
updated = model.calculate_ratings([[p1], [p2]], scores: [100, 50])
p1, p2 = updated.flatten

puts 'After match (100-50):'
puts "  Player 1: ordinal=#{p1.ordinal.round(2)}"
puts "  Player 2: ordinal=#{p2.ordinal.round(2)}"

puts "\n" + '=' * 50
puts 'Example complete!'
