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
    end
  end
end
