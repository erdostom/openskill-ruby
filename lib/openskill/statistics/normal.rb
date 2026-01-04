# frozen_string_literal: true

require 'distribution'

module OpenSkill
  module Statistics
    # Wrapper for normal distribution functions
    class Normal
      # Normal cumulative distribution function (CDF)
      #
      # @param x [Float] the value
      # @return [Float] the cumulative probability
      def self.cdf(x)
        Distribution::Normal.cdf(x)
      end

      # Normal inverse cumulative distribution function (inverse CDF)
      #
      # @param x [Float] the probability (0 to 1)
      # @return [Float] the value at that probability
      def self.inv_cdf(x)
        Distribution::Normal.p_value(x)
      end

      # Normal probability density function (PDF)
      #
      # @param x [Float] the value
      # @return [Float] the probability density
      def self.pdf(x)
        Distribution::Normal.pdf(x)
      end
    end
  end
end
