# frozen_string_literal: true

module OpenSkill
  module Models
    # Common utility functions shared across models
    module Common
      # Normalize a vector to a target range
      #
      # @param vector [Array<Numeric>] the input vector
      # @param target_min [Numeric] the target minimum value
      # @param target_max [Numeric] the target maximum value
      # @return [Array<Float>] the normalized vector
      def self.normalize(vector, target_min, target_max)
        return [] if vector.empty?

        source_min = vector.min
        source_max = vector.max
        source_range = source_max - source_min

        # If all values are the same, return target_min for all
        return Array.new(vector.size, target_min.to_f) if source_range.zero?

        target_range = target_max - target_min

        vector.map do |value|
          ((value - source_min) / source_range) * target_range + target_min
        end
      end

      # Transpose a 2D matrix
      #
      # @param matrix [Array<Array>] the input matrix
      # @return [Array<Array>] the transposed matrix
      def self.matrix_transpose(matrix)
        return [] if matrix.empty? || matrix[0].empty?

        matrix[0].zip(*matrix[1..])
      end

      # Sort objects by tenet and return both sorted objects and indices to restore order
      #
      # @param tenet [Array<Numeric>] values to sort by
      # @param objects [Array] objects to sort
      # @return [Array<(Array, Array<Numeric>)>] sorted objects and restoration indices
      def self.unwind(tenet, objects)
        return [[], []] if objects.empty?

        # Create array of [tenet_value, [object, original_index]]
        indexed = tenet.each_with_index.map { |t, i| [t, [objects[i], i]] }

        # Sort by tenet value
        sorted = indexed.sort_by { |t, _| t }

        # Extract sorted objects and their indices
        sorted_objects = sorted.map { |_, (obj, _)| obj }
        restoration_indices = sorted.map { |_, (_, idx)| idx }

        [sorted_objects, restoration_indices]
      end

      # The V function as defined in Weng-Lin 2011
      # Computes phi_minor(x-t) / phi_major(x-t)
      #
      # @param x [Float] input value
      # @param t [Float] threshold value
      # @return [Float] the V function result
      def self.v(x, t)
        xt = x - t
        denominator = Statistics::Normal.cdf(xt)

        return -xt if denominator < Float::EPSILON

        Statistics::Normal.pdf(xt) / denominator
      end

      # The W function as defined in Weng-Lin 2011
      # Computes V(x,t) * (V(x,t) + (x-t))
      #
      # @param x [Float] input value
      # @param t [Float] threshold value
      # @return [Float] the W function result
      def self.w(x, t)
        xt = x - t
        denominator = Statistics::Normal.cdf(xt)

        if denominator < Float::EPSILON
          return x < 0 ? 1.0 : 0.0
        end

        v_val = v(x, t)
        v_val * (v_val + xt)
      end

      # The V-tilde function for draws as defined in Weng-Lin 2011
      # Handles doubly truncated Gaussians
      #
      # @param x [Float] input value
      # @param t [Float] threshold value
      # @return [Float] the V-tilde function result
      def self.vt(x, t)
        xx = x.abs
        b = Statistics::Normal.cdf(t - xx) - Statistics::Normal.cdf(-t - xx)

        if b < 1e-5
          return x < 0 ? (-x - t) : (-x + t)
        end

        a = Statistics::Normal.pdf(-t - xx) - Statistics::Normal.pdf(t - xx)
        (x < 0 ? -a : a) / b
      end

      # The W-tilde function for draws as defined in Weng-Lin 2011
      # Handles variance for doubly truncated Gaussians
      #
      # @param x [Float] input value
      # @param t [Float] threshold value
      # @return [Float] the W-tilde function result
      def self.wt(x, t)
        xx = x.abs
        b = Statistics::Normal.cdf(t - xx) - Statistics::Normal.cdf(-t - xx)

        return 1.0 if b < Float::EPSILON

        numerator = ((t - xx) * Statistics::Normal.pdf(t - xx) +
                    (t + xx) * Statistics::Normal.pdf(-t - xx))
        vt_val = vt(x, t)
        numerator / b + vt_val * vt_val
      end
    end
  end
end
