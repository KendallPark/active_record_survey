module ActiveRecordSurvey
	class Node::Answer < Node
		# Answer nodes are valid if their questions are valid!
		# Validate this node against an instance
		def validate_node(instance)
			# Ensure each parent node to this node (the goal here is to hit a question node) is valid
			!self.node_maps.collect { |node_map|
				node_map.parent.node.validate_node(instance)
			}.include?(false)
		end

		# Returns the question that preceeds this answer
		def question
			self.node_maps.collect { |node_map|
				if node_map.parent && node_map.parent.node
					# Question is not the next parent - recurse!
					if node_map.parent.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
						node_map.parent.node.question
					else
						node_map.parent.node
					end
				# Root already
				else
					nil
				end
			}.first
		end

		# Returns the question that follows this answer
		def next_question
			self.node_maps.each { |answer_node_map|
				answer_node_map.children.each { |child|
					if !child.node.nil?
						if child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
							return child.node
						elsif child.node.class.ancestors.include?(::ActiveRecordSurvey::Node::Answer)
							return child.node.next_question 
						end
					else
						return nil
					end
				}
			}
			return nil
		end

		# Removes the link
		# TODO - does this work when saved??
		def remove_link
			self.node_maps.each { |answer_node_map|
				answer_node_map.children.each { |child|
					# Should not know about parent
					child.parent = nil
				}
				# Should not know about children
				answer_node_map.children = []
			}
		end

		# Build a link from this node to another node
		# Building a link actually needs to throw off a whole new clone of all children nodes
		def build_link(to_node)
			# build_link only accepts a to_node that inherits from Question
			if !to_node.class.ancestors.include?(::ActiveRecordSurvey::Node::Question)
				raise ArgumentError.new "to_node must inherit from ::ActiveRecordSurvey::Node::Question"
			end

			# Answer has already got a question - throw error
			if self.node_maps.select { |i|
				i.children.length === 0
			}.length === 0
				raise RuntimeError.new "This answer has already been linked"
			end

			# Attempt to find an unused to_node node_map
			if !(to_without_parent = to_node.node_maps.select { |i| i.parent.nil? }.first)
				# no unused path exists
				# we need to recursively clone the existing path

				to_node_map = to_node.node_maps.first || to_node.node_maps.build(:node => to_node, :survey => self.node_maps.first.survey)

				# Add it to all the from_node_maps
				self.node_maps.each { |from_node_map|
					from_node_map.children << to_node_map.recursive_clone
				}
			else
				# Find the node map from this node that has no children
				from_with_no_children = self.node_maps.select { |i|
					i.children.length == 0
				}

				if from_with_no_children.length > 1
					to_node_map = to_node.node_maps.first || to_node.node_maps.build(:node => to_node, :survey => self.node_maps.first.survey)
				end

				from_with_no_children.each_with_index { |from_with_no_children, index|
					# Use up the node that hasn't been used yet
					if index === 0
						from_with_no_children.children << to_without_parent
					# We need to clone destinations for each of the subsequent
					else
						from_with_no_children.children << to_node_map.recursive_clone
					end
				}

			end
		end

		# By default - answers build off the original question node
		#
		# This allows us to easily override the answer building behaviour for different answer types
		#
		def build_answer(question_node, survey)
			# No node_maps exist yet from this question
			if question_node.node_maps.length === 0
				# Build our first node-map
				question_node.node_maps.build(:node => question_node, :survey => survey)
			end

			# Each instance of this question needs the answer hung from it
			question_node.node_maps.each { |question_node_map|
				answer_node_map = self.node_maps.build(:node => self, :survey => survey)
				question_node_map.children << answer_node_map
			}

			true
		end
	end
end
