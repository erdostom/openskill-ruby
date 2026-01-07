# frozen_string_literal: true

require 'securerandom'
require_relative '../statistics/normal'
require_relative 'common'

module OpenSkill
  module Models
    # Thurstone-Mosteller Full rating model (Algorithm 3)
    #
    # This model uses full pairing where all teams are compared against each other.
    # It uses a maximum likelihood estimation approach for rating estimation.
    class ThurstoneMostellerFull
      attr_reader :mu, :sigma, :beta, :kappa, :tau, :margin, :limit_sigma, :balance, :gamma, :epsilon

      # Default gamma function for ThurstoneMostellerFull
      DEFAULT_GAMMA = lambda do |_c, _k, _mu, sigma_squared, _team, _rank, _weights|
        Math.sqrt(sigma_squared) / _c
      end

      # @param mu [Float] initial mean skill rating
      # @param sigma [Float] initial standard deviation
      # @param beta [Float] performance uncertainty
      # @param kappa [Float] minimum variance (regularization)
      # @param gamma [Proc] custom gamma function
      # @param tau [Float] dynamics factor (skill decay)
      # @param epsilon [Float] draw margin for Thurstone-Mosteller
      # @param margin [Float] score margin for impressive wins
      # @param limit_sigma [Boolean] prevent sigma from increasing
      # @param balance [Boolean] emphasize rating outliers
      def initialize(
        mu: 25.0,
        sigma: 25.0 / 3.0,
        beta: 25.0 / 6.0,
        kappa: 0.0001,
        gamma: DEFAULT_GAMMA,
        tau: 25.0 / 300.0,
        epsilon: 0.1,
        margin: 0.0,
        limit_sigma: false,
        balance: false
      )
        @mu = mu.to_f
        @sigma = sigma.to_f
        @beta = beta.to_f
        @kappa = kappa.to_f
        @gamma = gamma
        @tau = tau.to_f
        @epsilon = epsilon.to_f
        @margin = margin.to_f
        @limit_sigma = limit_sigma
        @balance = balance
      end

      # Create a new rating with default or custom parameters
      #
      # @param mu [Float, nil] override default mu
      # @param sigma [Float, nil] override default sigma
      # @param name [String, nil] optional player name
      # @return [Rating] a new rating object
      def create_rating(mu: nil, sigma: nil, name: nil)
        Rating.new(
          mu: mu || @mu,
          sigma: sigma || @sigma,
          name: name
        )
      end

      # Load a rating from an array [mu, sigma]
      #
      # @param rating_array [Array<Numeric>] [mu, sigma]
      # @param name [String, nil] optional player name
      # @return [Rating] a new rating object
      # @raise [ArgumentError] if rating_array is invalid
      def load_rating(rating_array, name: nil)
        raise ArgumentError, "Rating must be an Array, got #{rating_array.class}" unless rating_array.is_a?(Array)
        raise ArgumentError, 'Rating array must have exactly 2 elements' unless rating_array.size == 2
        raise ArgumentError, 'Rating values must be numeric' unless rating_array.all? { |v| v.is_a?(Numeric) }

        Rating.new(mu: rating_array[0], sigma: rating_array[1], name: name)
      end

      # Calculate new ratings after a match
      #
      # @param teams [Array<Array<Rating>>] list of teams
      # @param ranks [Array<Numeric>, nil] team ranks (lower is better, 0-indexed)
      # @param scores [Array<Numeric>, nil] team scores (higher is better)
      # @param weights [Array<Array<Numeric>>, nil] player contribution weights
      # @param tau [Float, nil] override tau for this match
      # @param limit_sigma [Boolean, nil] override limit_sigma for this match
      # @return [Array<Array<Rating>>] updated teams
      def calculate_ratings(teams, ranks: nil, scores: nil, weights: nil, tau: nil, limit_sigma: nil)
        validate_teams!(teams)
        validate_ranks!(teams, ranks) if ranks
        validate_scores!(teams, scores) if scores
        validate_weights!(teams, weights) if weights

        raise ArgumentError, 'Cannot provide both ranks and scores' if ranks && scores

        # Deep copy teams to avoid mutating input
        original_teams = teams
        teams = deep_copy_teams(teams)

        # Apply tau (skill decay over time)
        tau_value = tau || @tau
        tau_squared = tau_value**2
        teams.each do |team|
          team.each do |player|
            player.sigma = Math.sqrt(player.sigma**2 + tau_squared)
          end
        end

        # Convert scores to ranks if provided
        if !ranks && scores
          ranks = scores.map { |s| -s }
          ranks = calculate_rankings(teams, ranks)
        end

        # Normalize weights to [1, 2] range
        weights = weights.map { |w| Common.normalize(w, 1, 2) } if weights

        # Sort teams by rank and track original order
        tenet = nil
        if ranks
          sorted_objects, restoration_indices = Common.unwind(ranks, teams)
          teams = sorted_objects
          tenet = restoration_indices

          weights, = Common.unwind(ranks, weights) if weights

          ranks = ranks.sort
        end

        # Compute new ratings
        result = compute_ratings(teams, ranks: ranks, scores: scores, weights: weights)

        # Restore original order
        result, = Common.unwind(tenet, result) if ranks && tenet

        # Apply sigma limiting if requested
        limit_sigma_value = limit_sigma.nil? ? @limit_sigma : limit_sigma
        if limit_sigma_value
          result = result.each_with_index.map do |team, team_idx|
            team.each_with_index.map do |player, player_idx|
              player.sigma = [player.sigma, original_teams[team_idx][player_idx].sigma].min
              player
            end
          end
        end

        result
      end

      # Predict win probability for each team
      #
      # @param teams [Array<Array<Rating>>] list of teams
      # @return [Array<Float>] probability each team wins
      def predict_win_probability(teams)
        validate_teams!(teams)

        n = teams.size

        # Special case for 2 teams
        if n == 2
          team_ratings = calculate_team_ratings(teams)
          a = team_ratings[0]
          b = team_ratings[1]

          result = phi_major(
            (a.mu - b.mu) / Math.sqrt(2 * @beta**2 + a.sigma_squared + b.sigma_squared)
          )
          return [result, 1 - result]
        end

        # For n teams, compute pairwise probabilities
        team_ratings = teams.map { |team| calculate_team_ratings([team])[0] }

        win_probs = []
        team_ratings.each_with_index do |team_i, i|
          prob_sum = 0.0
          team_ratings.each_with_index do |team_j, j|
            next if i == j

            prob_sum += phi_major(
              (team_i.mu - team_j.mu) / Math.sqrt(2 * @beta**2 + team_i.sigma_squared + team_j.sigma_squared)
            )
          end
          win_probs << prob_sum / (n - 1)
        end

        # Normalize to sum to 1
        total = win_probs.sum
        win_probs.map { |p| p / total }
      end

      # Predict draw probability
      #
      # @param teams [Array<Array<Rating>>] list of teams
      # @return [Float] probability of a draw
      def predict_draw_probability(teams)
        validate_teams!(teams)

        total_player_count = teams.sum(&:size)
        draw_probability = 1.0 / total_player_count
        draw_margin = Math.sqrt(total_player_count) * @beta * phi_major_inverse((1 + draw_probability) / 2)

        pairwise_probs = []
        teams.combination(2).each do |team_a, team_b|
          team_a_ratings = calculate_team_ratings([team_a])
          team_b_ratings = calculate_team_ratings([team_b])

          mu_a = team_a_ratings[0].mu
          sigma_a = team_a_ratings[0].sigma_squared
          mu_b = team_b_ratings[0].mu
          sigma_b = team_b_ratings[0].sigma_squared

          denominator = Math.sqrt(2 * @beta**2 + sigma_a + sigma_b)

          pairwise_probs << (
            phi_major((draw_margin - mu_a + mu_b) / denominator) -
            phi_major((mu_b - mu_a - draw_margin) / denominator)
          )
        end

        pairwise_probs.sum / pairwise_probs.size
      end

      # Predict rank probability for each team
      #
      # @param teams [Array<Array<Rating>>] list of teams
      # @return [Array<Array(Integer, Float)>] rank and probability for each team
      def predict_rank_probability(teams)
        validate_teams!(teams)

        n = teams.size
        team_ratings = calculate_team_ratings(teams)

        # Calculate win probability for each team against all others
        win_probs = team_ratings.map do |team_i|
          prob = 0.0
          team_ratings.each do |team_j|
            next if team_i == team_j

            prob += phi_major(
              (team_i.mu - team_j.mu) /
              Math.sqrt(2 * @beta**2 + team_i.sigma_squared + team_j.sigma_squared)
            )
          end
          prob / (n - 1)
        end

        # Normalize probabilities
        total = win_probs.sum
        normalized_probs = win_probs.map { |p| p / total }

        # Sort by probability (descending) and assign ranks
        sorted_indices = normalized_probs.each_with_index.sort_by { |prob, _| -prob }
        ranks = Array.new(n)

        current_rank = 1
        sorted_indices.each_with_index do |(prob, team_idx), i|
          current_rank = i + 1 if i > 0 && prob < sorted_indices[i - 1][0]
          ranks[team_idx] = current_rank
        end

        ranks.zip(normalized_probs)
      end

      private

      # Helper for log(1 + x)
      def log1p(value)
        Math.log(1 + value)
      end

      # Rating class for individual players
      class Rating
        attr_accessor :mu, :sigma, :name
        attr_reader :id

        def initialize(mu:, sigma:, name: nil)
          @id = SecureRandom.hex
          @mu = mu.to_f
          @sigma = sigma.to_f
          @name = name
        end

        # Calculate display rating (conservative estimate)
        #
        # @param z [Float] number of standard deviations
        # @param alpha [Float] scaling factor
        # @param target [Float] target adjustment
        # @return [Float] the ordinal rating
        def ordinal(z: 3.0, alpha: 1.0, target: 0.0)
          alpha * ((@mu - z * @sigma) + (target / alpha))
        end

        def <=>(other)
          return nil unless other.is_a?(Rating)

          ordinal <=> other.ordinal
        end

        def <(other)
          raise ArgumentError, 'comparison with non-Rating' unless other.is_a?(Rating)

          ordinal < other.ordinal
        end

        def >(other)
          raise ArgumentError, 'comparison with non-Rating' unless other.is_a?(Rating)

          ordinal > other.ordinal
        end

        def <=(other)
          raise ArgumentError, 'comparison with non-Rating' unless other.is_a?(Rating)

          ordinal <= other.ordinal
        end

        def >=(other)
          raise ArgumentError, 'comparison with non-Rating' unless other.is_a?(Rating)

          ordinal >= other.ordinal
        end

        def ==(other)
          return false unless other.is_a?(Rating)

          @mu == other.mu && @sigma == other.sigma
        end

        def hash
          [@id, @mu, @sigma].hash
        end

        def eql?(other)
          self == other
        end

        def to_s
          "Rating(mu=#{@mu}, sigma=#{@sigma}#{", name=#{@name}" if @name})"
        end

        def inspect
          to_s
        end
      end

      # Internal class for team ratings
      class TeamRating
        attr_reader :mu, :sigma_squared, :team, :rank

        def initialize(mu:, sigma_squared:, team:, rank:)
          @mu = mu.to_f
          @sigma_squared = sigma_squared.to_f
          @team = team
          @rank = rank.to_i
        end

        def ==(other)
          return false unless other.is_a?(TeamRating)

          @mu == other.mu &&
            @sigma_squared == other.sigma_squared &&
            @team == other.team &&
            @rank == other.rank
        end

        def hash
          [@mu, @sigma_squared, @team, @rank].hash
        end

        def to_s
          "TeamRating(mu=#{@mu}, sigma_squared=#{@sigma_squared}, rank=#{@rank})"
        end
      end

      # Validate teams structure
      def validate_teams!(teams)
        raise ArgumentError, 'Teams must be an Array' unless teams.is_a?(Array)
        raise ArgumentError, 'Must have at least 2 teams' if teams.size < 2

        teams.each_with_index do |team, idx|
          raise ArgumentError, "Team #{idx} must be an Array" unless team.is_a?(Array)
          raise ArgumentError, "Team #{idx} must have at least 1 player" if team.empty?

          team.each do |player|
            raise ArgumentError, "All players must be Rating objects, got #{player.class}" unless player.is_a?(Rating)
          end
        end
      end

      # Validate ranks
      def validate_ranks!(teams, ranks)
        raise ArgumentError, "Ranks must be an Array, got #{ranks.class}" unless ranks.is_a?(Array)
        raise ArgumentError, 'Ranks must have same length as teams' if ranks.size != teams.size

        ranks.each do |rank|
          raise ArgumentError, "All ranks must be numeric, got #{rank.class}" unless rank.is_a?(Numeric)
        end
      end

      # Validate scores
      def validate_scores!(teams, scores)
        raise ArgumentError, "Scores must be an Array, got #{scores.class}" unless scores.is_a?(Array)
        raise ArgumentError, 'Scores must have same length as teams' if scores.size != teams.size

        scores.each do |score|
          raise ArgumentError, "All scores must be numeric, got #{score.class}" unless score.is_a?(Numeric)
        end
      end

      # Validate weights
      def validate_weights!(teams, weights)
        raise ArgumentError, "Weights must be an Array, got #{weights.class}" unless weights.is_a?(Array)
        raise ArgumentError, 'Weights must have same length as teams' if weights.size != teams.size

        weights.each_with_index do |team_weights, idx|
          raise ArgumentError, "Weights for team #{idx} must be an Array" unless team_weights.is_a?(Array)
          unless team_weights.size == teams[idx].size
            raise ArgumentError, "Weights for team #{idx} must match team size"
          end

          team_weights.each do |weight|
            raise ArgumentError, "All weights must be numeric, got #{weight.class}" unless weight.is_a?(Numeric)
          end
        end
      end

      # Deep copy teams to avoid mutation
      def deep_copy_teams(teams)
        teams.map do |team|
          team.map do |player|
            Rating.new(mu: player.mu, sigma: player.sigma, name: player.name).tap do |new_player|
              new_player.instance_variable_set(:@id, player.id)
            end
          end
        end
      end

      # Calculate team ratings from individual player ratings
      def calculate_team_ratings(game, ranks: nil, weights: nil)
        ranks ||= calculate_rankings(game)

        game.each_with_index.map do |team, idx|
          sorted_team = team.sort_by { |p| -p.ordinal }
          max_ordinal = sorted_team.first.ordinal

          mu_sum = 0.0
          sigma_squared_sum = 0.0

          sorted_team.each do |player|
            balance_weight = if @balance
                               ordinal_diff = max_ordinal - player.ordinal
                               1 + (ordinal_diff / (max_ordinal + @kappa))
                             else
                               1.0
                             end

            mu_sum += player.mu * balance_weight
            sigma_squared_sum += (player.sigma * balance_weight)**2
          end

          TeamRating.new(
            mu: mu_sum,
            sigma_squared: sigma_squared_sum,
            team: team,
            rank: ranks[idx].to_i
          )
        end
      end

      # Calculate rankings from scores or indices
      def calculate_rankings(game, ranks = nil)
        return [] if game.empty?

        team_scores = if ranks
                        ranks.each_with_index.map { |rank, idx| rank || idx }
                      else
                        game.each_index.to_a
                      end

        sorted_scores = team_scores.sort
        rank_map = {}
        sorted_scores.each_with_index do |value, index|
          rank_map[value] ||= index
        end

        team_scores.map { |score| rank_map[score].to_f }
      end

      # Core rating computation algorithm using Thurstone-Mosteller Full pairing
      def compute_ratings(teams, ranks: nil, scores: nil, weights: nil)
        team_ratings = calculate_team_ratings(teams, ranks: ranks)

        # Build score mapping for margin calculations
        score_mapping = {}
        if scores && scores.size == team_ratings.size
          team_ratings.each_with_index do |_, i|
            score_mapping[i] = scores[i]
          end
        end

        team_ratings.each_with_index.map do |team_i, i|
          omega = 0.0
          delta = 0.0

          # Thurstone-Mosteller Full: Compare with ALL other teams using v/w functions
          team_ratings.each_with_index do |team_q, q|
            next if q == i

            # Calculate c_iq
            c_iq = Math.sqrt(team_i.sigma_squared + team_q.sigma_squared + 2 * @beta**2)

            # Calculate margin factor
            margin_factor = 1.0
            if scores && score_mapping.key?(i) && score_mapping.key?(q)
              score_diff = (score_mapping[i] - score_mapping[q]).abs
              margin_factor = log1p(score_diff / @margin) if score_diff > @margin && @margin > 0.0
            end

            # Calculate delta_mu
            delta_mu = ((team_i.mu - team_q.mu) / c_iq) * margin_factor
            epsilon_over_c = @epsilon / c_iq

            # Use v/w/vt/wt functions based on rank comparison
            if team_q.rank > team_i.rank
              # team_i won
              omega += (team_i.sigma_squared / c_iq) * Common.v(delta_mu, epsilon_over_c)
              v_val = Common.w(delta_mu, epsilon_over_c)
            elsif team_q.rank < team_i.rank
              # team_i lost
              omega -= (team_i.sigma_squared / c_iq) * Common.v(-delta_mu, epsilon_over_c)
              v_val = Common.w(-delta_mu, epsilon_over_c)
            else
              # draw
              omega += (team_i.sigma_squared / c_iq) * Common.vt(delta_mu, epsilon_over_c)
              v_val = Common.wt(delta_mu, epsilon_over_c)
            end

            # Apply gamma
            team_weights = weights ? weights[i] : nil
            gamma_value = @gamma.call(
              c_iq,
              team_ratings.size,
              team_i.mu,
              team_i.sigma_squared,
              team_i.team,
              team_i.rank,
              team_weights
            )

            delta += (gamma_value * team_i.sigma_squared / (c_iq**2)) * v_val
          end

          # Update each player in the team
          team_i.team.each_with_index.map do |player, j|
            weight = weights ? weights[i][j] : 1.0

            new_mu = player.mu
            new_sigma = player.sigma

            if omega >= 0
              new_mu += (new_sigma**2 / team_i.sigma_squared) * omega * weight
              new_sigma *= Math.sqrt(
                [1 - (new_sigma**2 / team_i.sigma_squared) * delta * weight, @kappa].max
              )
            else
              new_mu += (new_sigma**2 / team_i.sigma_squared) * omega / weight
              new_sigma *= Math.sqrt(
                [1 - (new_sigma**2 / team_i.sigma_squared) * delta / weight, @kappa].max
              )
            end

            player.mu = new_mu
            player.sigma = new_sigma
            player
          end
        end
      end

      # Normal distribution CDF
      def phi_major(value)
        Statistics::Normal.cdf(value)
      end

      # Normal distribution inverse CDF
      def phi_major_inverse(value)
        Statistics::Normal.inv_cdf(value)
      end
    end
  end
end
