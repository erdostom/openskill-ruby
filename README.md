# OpenSkill

A Ruby implementation of the OpenSkill rating system for multiplayer games. OpenSkill is a Bayesian skill rating system that can handle teams of varying sizes, asymmetric matches, and complex game scenarios.

[![Gem Version](https://badge.fury.io/rb/openskill.svg)](https://badge.fury.io/rb/openskill)
![](https://github.com/erdostom/openskill-ruby/actions/workflows/test.yml/badge.svg)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.1.0-red.svg)]()
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- 🎮 **Multiplayer Support**: Handle 2+ teams of any size
- ⚖️ **Asymmetric Teams**: Teams don't need equal player counts
- 🎯 **Multiple Ranking Methods**: Use ranks or scores
- 📊 **Prediction Methods**: Predict win probabilities, draws, and final rankings
- 🔢 **Player Weights**: Account for partial participation or contribution
- 📈 **Score Margins**: Factor in impressive wins
- 🔄 **Tie Handling**: Properly handle drawn matches
- ⚡ **Fast**: Efficient Ruby implementation
- 🧪 **Well Tested**: Comprehensive test suite matching reference implementation

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'openskill'
```

And then execute:

```bash
bundle install
```

Or install it yourself as:

```bash
gem install openskill
```

## Quick Start

```ruby
require 'openskill'

# Create a model (Plackett-Luce by default)
model = OpenSkill::Models::PlackettLuce.new

# Create player ratings
alice = model.create_rating(name: "Alice")
bob = model.create_rating(name: "Bob")
charlie = model.create_rating(name: "Charlie")
dave = model.create_rating(name: "Dave")

# Simple 1v1 match (alice wins)
team1 = [alice]
team2 = [bob]
new_ratings = model.calculate_ratings([team1, team2])
alice, bob = new_ratings.flatten

puts "Alice: #{alice.mu.round(2)} ± #{alice.sigma.round(2)}"
puts "Bob: #{bob.mu.round(2)} ± #{bob.sigma.round(2)}"
```

## Usage

### Creating Ratings

```ruby
model = OpenSkill::Models::PlackettLuce.new

# Create with defaults (mu=25, sigma=8.333)
player = model.create_rating

# Create with custom values
player = model.create_rating(mu: 30.0, sigma: 5.0, name: "Alice")

# Load from database [mu, sigma]
player = model.load_rating([28.5, 7.2], name: "Bob")
```

### Calculating New Ratings

#### Simple Match (Team 1 wins)

```ruby
team1 = [alice, bob]
team2 = [charlie, dave]

updated_teams = model.calculate_ratings([team1, team2])
```

#### Match with Explicit Ranks

Lower rank = better performance (0 is best)

```ruby
teams = [[alice], [bob], [charlie]]
# Charlie wins, Bob second, Alice third
updated = model.calculate_ratings(teams, ranks: [2, 1, 0])
```

#### Match with Scores

Higher score = better performance

```ruby
teams = [[alice, bob], [charlie, dave]]
# Team 2 wins 100-80
updated = model.calculate_ratings(teams, scores: [80, 100])
```

#### Match with Ties

```ruby
teams = [[alice], [bob], [charlie]]
# Alice and Charlie tie for first, Bob comes third
updated = model.calculate_ratings(teams, ranks: [0, 2, 0])
```

#### Player Contribution Weights

When players contribute different amounts:

```ruby
teams = [
  [alice, bob],      # Alice contributed more
  [charlie, dave]    # Dave carried the team
]

updated = model.calculate_ratings(
  teams,
  weights: [[2.0, 1.0], [1.0, 2.0]]
)
```

#### Score Margins (Impressive Wins)

Factor in score differences:

```ruby
model = OpenSkill::Models::PlackettLuce.new(margin: 5.0)

# Large score difference means more rating change
updated = model.calculate_ratings(
  [[alice], [bob]],
  scores: [100, 20]  # Alice dominated
)
```

### Predictions

#### Win Probability

```ruby
teams = [[alice, bob], [charlie, dave], [eve]]
probabilities = model.predict_win_probability(teams)
# => [0.35, 0.45, 0.20] (sums to 1.0)
```

#### Draw Probability

Higher values mean more evenly matched:

```ruby
probability = model.predict_draw_probability([[alice], [bob]])
# => 0.25
```

#### Rank Prediction

```ruby
teams = [[alice], [bob], [charlie]]
predictions = model.predict_rank_probability(teams)
# => [[1, 0.504], [2, 0.333], [3, 0.163]]
# Format: [predicted_rank, probability]
```

### Rating Display

The `ordinal` method provides a conservative rating estimate:

```ruby
player = model.create_rating(mu: 30.0, sigma: 5.0)

# 99.7% confidence (3 standard deviations)
puts player.ordinal  # => 15.0 (30 - 3*5)

# 99% confidence
puts player.ordinal(z: 2.576)  # => 17.12

# For leaderboards
players.sort_by(&:ordinal).reverse
```

### Model Options

```ruby
model = OpenSkill::Models::PlackettLuce.new(
  mu: 25.0,           # Initial mean skill
  sigma: 25.0 / 3,    # Initial skill uncertainty
  beta: 25.0 / 6,     # Performance variance
  kappa: 0.0001,      # Minimum variance (regularization)
  tau: 25.0 / 300,    # Skill decay per match
  margin: 0.0,        # Score margin threshold
  limit_sigma: false, # Prevent sigma from increasing
  balance: false      # Emphasize rating outliers in teams
)
```

### Advanced Features

#### Prevent Rating Uncertainty from Growing

```ruby
# Useful for active players
updated = model.calculate_ratings(teams, limit_sigma: true)
```

#### Balance Outliers in Teams

```ruby
model = OpenSkill::Models::PlackettLuce.new(balance: true)
# Gives more weight to rating differences within teams
```

#### Custom Tau (Skill Decay)

```ruby
# Higher tau = more rating volatility
updated = model.calculate_ratings(teams, tau: 1.0)
```

## How It Works

OpenSkill uses a Bayesian approach to model player skill as a normal distribution:

- **μ (mu)**: The mean skill level
- **σ (sigma)**: The uncertainty about the skill level

After each match:

1. Compute team strengths from individual player ratings
2. Calculate expected outcomes based on team strengths
3. Update ratings based on actual vs expected performance
4. Reduce uncertainty (sigma) as more matches are played

The **ordinal** value (`μ - 3σ`) provides a conservative estimate where the true skill is 99.7% likely to be higher.

## Why OpenSkill?

### vs Elo

- ✅ Handles multiplayer (3+ players/teams)
- ✅ Works with team games
- ✅ Accounts for rating uncertainty
- ✅ Faster convergence to true skill

### vs TrueSkill

- ✅ Open source (MIT license)
- ✅ Faster computation
- ✅ Similar accuracy
- ✅ More flexible (weights, margins, custom parameters)

## API Design Philosophy

This Ruby implementation uses idiomatic Ruby naming conventions:

| Python API                       | Ruby API                                |
| -------------------------------- | --------------------------------------- |
| `model.rating()`                 | `model.create_rating`                   |
| `model.create_rating([25, 8.3])` | `model.load_rating([25, 8.3])`          |
| `model.rate(teams)`              | `model.calculate_ratings(teams)`        |
| `model.predict_win(teams)`       | `model.predict_win_probability(teams)`  |
| `model.predict_draw(teams)`      | `model.predict_draw_probability(teams)` |
| `model.predict_rank(teams)`      | `model.predict_rank_probability(teams)` |

## Examples

### 2v2 Team Game

```ruby
model = OpenSkill::Models::PlackettLuce.new

# Create players
alice = model.create_rating(name: "Alice")
bob = model.create_rating(name: "Bob")
charlie = model.create_rating(name: "Charlie")
dave = model.create_rating(name: "Dave")

# Match: Alice + Bob vs Charlie + Dave (Team 1 wins)
teams = [[alice, bob], [charlie, dave]]
updated = model.calculate_ratings(teams)

# Updated ratings
updated[0].each { |p| puts "#{p.name}: #{p.ordinal.round(1)}" }
updated[1].each { |p| puts "#{p.name}: #{p.ordinal.round(1)}" }
```

### Free-for-All (5 players)

```ruby
players = 5.times.map { model.create_rating }

# Player 3 wins, 1 second, 4 third, 0 fourth, 2 fifth
updated = model.calculate_ratings(
  players.map { |p| [p] },
  ranks: [3, 1, 4, 0, 2]
)
```

### Tracking Player Progress

```ruby
class Player
  attr_accessor :name, :mu, :sigma

  def initialize(name, model)
    @name = name
    rating = model.create_rating
    @mu = rating.mu
    @sigma = rating.sigma
  end

  def to_rating(model)
    model.load_rating([@mu, @sigma], name: @name)
  end

  def update_from_rating!(rating)
    @mu = rating.mu
    @sigma = rating.sigma
  end

  def ordinal(z: 3.0)
    @mu - z * @sigma
  end
end

# Usage
model = OpenSkill::Models::PlackettLuce.new
alice = Player.new("Alice", model)
bob = Player.new("Bob", model)

# Play match
teams = [[alice.to_rating(model)], [bob.to_rating(model)]]
updated = model.calculate_ratings(teams)

# Update players
alice.update_from_rating!(updated[0][0])
bob.update_from_rating!(updated[1][0])
```

## Testing

```bash
bundle install
bundle exec rake test
```

## Development

This gem follows the [OpenSkill specification](https://openskill.me) and maintains compatibility with the Python reference implementation.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License

MIT License. See [LICENSE](LICENSE) for details.

## References

- [OpenSkill Python Implementation](https://github.com/vivekjoshy/openskill.py)
- [OpenSkill Documentation](https://openskill.me)
- Original Paper: [A Bayesian Approximation Method for Online Ranking](https://jmlr.org/papers/v12/weng11a.html) by Ruby C. Weng and Chih-Jen Lin

## Acknowledgments

This Ruby implementation is based on the excellent [openskill.py](https://github.com/vivekjoshy/openskill.py) Python library by Vivek Joshy.

The Plackett-Luce model implemented here is based on the work by Weng and Lin (2011), providing a faster and more accessible alternative to Microsoft's TrueSkill system.
