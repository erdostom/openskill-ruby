# frozen_string_literal: true

require 'test_helper'

module OpenSkill
  module Models
    class TestBradleyTerryPart < Minitest::Test
      def setup
        @model = BradleyTerryPart.new
        @fixture_path = File.expand_path('../../fixtures/bradley_terry_part.json', __dir__)
        @data = JSON.parse(File.read(@fixture_path))
      end

      def test_model_defaults
        assert_equal 25.0, @model.mu
        assert_in_delta 25.0 / 3.0, @model.sigma, 0.0001
        assert_in_delta 25.0 / 6.0, @model.beta, 0.0001
        assert_equal 0.0001, @model.kappa
        assert_in_delta 25.0 / 300.0, @model.tau, 0.0001
        assert_equal 0.0, @model.margin
        assert_equal false, @model.limit_sigma
        assert_equal false, @model.balance
        assert_equal 4, @model.window_size
      end

      def test_rating_creation
        rating = @model.create_rating
        assert_equal 25.0, rating.mu
        assert_in_delta 25.0 / 3.0, rating.sigma, 0.0001
        assert_nil rating.name

        rating_with_name = @model.create_rating(name: 'Alice')
        assert_equal 'Alice', rating_with_name.name
      end

      def test_rating_with_custom_values
        rating = @model.create_rating(mu: 30.0, sigma: 5.0, name: 'Bob')
        assert_equal 30.0, rating.mu
        assert_equal 5.0, rating.sigma
        assert_equal 'Bob', rating.name
      end

      def test_load_rating
        rating = @model.load_rating([30.0, 5.0])
        assert_equal 30.0, rating.mu
        assert_equal 5.0, rating.sigma

        rating_with_name = @model.load_rating([28.0, 6.5], name: 'Charlie')
        assert_equal 'Charlie', rating_with_name.name
      end

      def test_load_rating_errors
        assert_raises(ArgumentError) { @model.load_rating('invalid') }
        assert_raises(ArgumentError) { @model.load_rating([1, 2, 3]) }
        assert_raises(ArgumentError) { @model.load_rating([1, 'invalid']) }
      end

      def test_rating_ordinal
        rating = @model.create_rating(mu: 30.0, sigma: 5.0)
        ordinal = rating.ordinal
        expected = 30.0 - 3.0 * 5.0
        assert_in_delta expected, ordinal, 0.0001
      end

      def test_rating_comparison
        r1 = @model.create_rating(mu: 30.0, sigma: 5.0)
        r2 = @model.create_rating(mu: 25.0, sigma: 5.0)
        r3 = @model.create_rating(mu: 30.0, sigma: 5.0)

        assert r1 > r2
        assert r2 < r1
        assert_equal r1, r3
        refute_equal r1, r2
      end

      def test_calculate_ratings_basic
        mu = @data['model']['mu']
        sigma = @data['model']['sigma']
        model = BradleyTerryPart.new(mu: mu, sigma: sigma)

        team1 = [model.create_rating]
        team2 = [model.create_rating, model.create_rating]

        result = model.calculate_ratings([team1, team2])

        check_expected(@data, 'normal', result)
      end

      def test_calculate_ratings_with_ranks
        mu = @data['model']['mu']
        sigma = @data['model']['sigma']
        model = BradleyTerryPart.new(mu: mu, sigma: sigma)

        team1 = [model.create_rating]
        team2 = [model.create_rating, model.create_rating]
        team3 = [model.create_rating]
        team4 = [model.create_rating, model.create_rating]

        result = model.calculate_ratings(
          [team1, team2, team3, team4],
          ranks: [2, 1, 4, 3]
        )

        check_expected(@data, 'ranks', result)
      end

      def test_calculate_ratings_with_scores
        mu = @data['model']['mu']
        sigma = @data['model']['sigma']
        model = BradleyTerryPart.new(mu: mu, sigma: sigma)

        team1 = [model.create_rating]
        team2 = [model.create_rating, model.create_rating]

        result = model.calculate_ratings(
          [team1, team2],
          scores: [1, 2]
        )

        check_expected(@data, 'scores', result)
      end

      def test_calculate_ratings_validation_errors
        rating = @model.create_rating
        team1 = [rating]
        team2 = [rating, rating]

        # Not an array
        assert_raises(ArgumentError) { @model.calculate_ratings({}) }

        # Too few teams
        assert_raises(ArgumentError) { @model.calculate_ratings([team1]) }

        # Empty team
        assert_raises(ArgumentError) { @model.calculate_ratings([[], team2]) }

        # Invalid ranks
        assert_raises(ArgumentError) { @model.calculate_ratings([team1, team2], ranks: 'invalid') }
        assert_raises(ArgumentError) { @model.calculate_ratings([team1, team2], ranks: [1]) }

        # Invalid scores
        assert_raises(ArgumentError) { @model.calculate_ratings([team1, team2], scores: [1]) }

        # Both ranks and scores
        assert_raises(ArgumentError) do
          @model.calculate_ratings([team1, team2], ranks: [1, 2], scores: [1, 2])
        end

        # Invalid weights
        assert_raises(ArgumentError) { @model.calculate_ratings([team1, team2], weights: [[1]]) }
      end

      def test_sigma_limiting
        a = @model.create_rating(mu: 40, sigma: 3)
        b = @model.create_rating(mu: -20, sigma: 3)

        result = @model.calculate_ratings([[a], [b]], tau: 0.3, limit_sigma: true)
        winner = result[0][0]
        loser = result[1][0]

        assert_equal a.sigma, winner.sigma
        assert_equal b.sigma, loser.sigma
      end

      def test_sigma_does_not_increase_with_limit
        a = @model.create_rating
        b = @model.create_rating

        result = @model.calculate_ratings([[a], [b]], tau: 0.3, limit_sigma: true)
        winner = result[0][0]
        loser = result[1][0]

        assert winner.sigma <= a.sigma
        assert loser.sigma <= b.sigma
      end

      def test_predict_win_probability
        a1 = @model.create_rating
        a2 = @model.create_rating(mu: 32.444, sigma: 5.123)
        b1 = @model.create_rating(mu: 73.381, sigma: 1.421)
        b2 = @model.create_rating(mu: 25.188, sigma: 6.211)

        team1 = [a1, a2]
        team2 = [b1, b2]

        probs = @model.predict_win_probability([team1, team2, [a2], [a1], [b1]])
        assert_in_delta 1.0, probs.sum, 0.0001

        probs = @model.predict_win_probability([team1, team2])
        assert_in_delta 1.0, probs.sum, 0.0001

        # Must have at least 2 teams
        assert_raises(ArgumentError) { @model.predict_win_probability([team1]) }
      end

      def test_predict_draw_probability
        a1 = @model.create_rating
        a2 = @model.create_rating(mu: 32.444, sigma: 1.123)
        b1 = @model.create_rating(mu: 35.881, sigma: 0.0001)
        b2 = @model.create_rating(mu: 25.188, sigma: 0.00001)

        team1 = [a1, a2]
        team2 = [b1, b2]

        prob = @model.predict_draw_probability([team1, team2])
        assert_in_delta 0.1919967, prob, 0.001

        prob = @model.predict_draw_probability([team1, team2, [a1], [a2], [b1]])
        assert_in_delta 0.0603735, prob, 0.001

        prob = @model.predict_draw_probability([[b1], [b1]])
        assert_in_delta 0.5, prob, 0.01

        assert_raises(ArgumentError) { @model.predict_draw_probability([team1]) }
      end

      def test_predict_rank_probability
        a1 = @model.create_rating(mu: 34, sigma: 0.25)
        a2 = @model.create_rating(mu: 32, sigma: 0.25)
        a3 = @model.create_rating(mu: 30, sigma: 0.25)
        b1 = @model.create_rating(mu: 24, sigma: 0.5)
        b2 = @model.create_rating(mu: 22, sigma: 0.5)
        b3 = @model.create_rating(mu: 20, sigma: 0.5)

        team1 = [a1, b1]
        team2 = [a2, b2]
        team3 = [a3, b3]

        ranks = @model.predict_rank_probability([team1, team2, team3])
        total_prob = ranks.sum { |_, prob| prob }
        assert_in_delta 1.0, total_prob, 0.0001

        # Test with identical teams
        identical_ranks = @model.predict_rank_probability([team1, team1, team1])
        total_prob = identical_ranks.sum { |_, prob| prob }
        assert_in_delta 1.0, total_prob, 0.0001

        assert_raises(ArgumentError) { @model.predict_rank_probability([team1]) }
      end

      private

      def check_expected(data, key, result)
        teams_data = data[key]
        result.each_with_index do |team, team_idx|
          team.each_with_index do |player, player_idx|
            expected_data = teams_data["team_#{team_idx + 1}"][player_idx]
            assert_in_delta expected_data['mu'], player.mu, 0.0001,
                            "Mismatch in team #{team_idx + 1}, player #{player_idx} mu"
            assert_in_delta expected_data['sigma'], player.sigma, 0.0001,
                            "Mismatch in team #{team_idx + 1}, player #{player_idx} sigma"
          end
        end
      end
    end
  end
end
