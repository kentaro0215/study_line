# frozen_string_literal: true
=begin
This file is generated by the templates/template.rb script and should not be
modified manually. See templates/lib/prism/serialize.rb.erb
if you are looking to modify the template
=end

require "stringio"

# Polyfill for String#unpack1 with the offset parameter.
if String.instance_method(:unpack1).parameters.none? { |_, name| name == :offset }
  String.prepend(
    Module.new {
      def unpack1(format, offset: 0)
        offset == 0 ? super(format) : self[offset..].unpack1(format)
      end
    }
  )
end

module Prism
  module Serialize
    MAJOR_VERSION = 0
    MINOR_VERSION = 15
    PATCH_VERSION = 1

    def self.load(input, serialized)
      input = input.dup
      source = Source.new(input)
      loader = Loader.new(source, serialized)
      result = loader.load_result

      input.force_encoding(loader.encoding)
      result
    end

    def self.load_tokens(source, serialized)
      Loader.new(source, serialized).load_tokens_result
    end

    class Loader
      attr_reader :encoding, :input, :serialized, :io
      attr_reader :constant_pool_offset, :constant_pool, :source

      def initialize(source, serialized)
        @encoding = Encoding::UTF_8

        @input = source.source.dup
        @serialized = serialized
        @io = StringIO.new(serialized)
        @io.set_encoding(Encoding::BINARY)

        @constant_pool_offset = nil
        @constant_pool = nil

        @source = source
      end

      def load_encoding
        Encoding.find(io.read(load_varint))
      end

      def load_metadata
        comments = load_varint.times.map { Comment.new(Comment::TYPES.fetch(load_varint), load_location) }
        magic_comments = load_varint.times.map { MagicComment.new(load_location, load_location) }
        errors = load_varint.times.map { ParseError.new(load_embedded_string, load_location) }
        warnings = load_varint.times.map { ParseWarning.new(load_embedded_string, load_location) }
        [comments, magic_comments, errors, warnings]
      end

      def load_tokens
        tokens = []
        while type = TOKEN_TYPES.fetch(load_varint)
          start = load_varint
          length = load_varint
          lex_state = load_varint
          location = Location.new(@source, start, length)
          tokens << [Prism::Token.new(type, location.slice, location), lex_state]
        end

        tokens
      end

      def load_tokens_result
        tokens = load_tokens
        encoding = load_encoding
        comments, magic_comments, errors, warnings = load_metadata

        if encoding != @encoding
          tokens.each { |token,| token.value.force_encoding(encoding) }
        end

        raise "Expected to consume all bytes while deserializing" unless @io.eof?
        Prism::ParseResult.new(tokens, comments, magic_comments, errors, warnings, @source)
      end

      def load_nodes
        raise "Invalid serialization" if io.read(5) != "PRISM"
        raise "Invalid serialization" if io.read(3).unpack("C3") != [MAJOR_VERSION, MINOR_VERSION, PATCH_VERSION]
        only_semantic_fields = io.read(1).unpack1("C")
        unless only_semantic_fields == 0
          raise "Invalid serialization (location fields must be included but are not)"
        end

        @encoding = load_encoding
        @input = input.force_encoding(@encoding).freeze

        comments, magic_comments, errors, warnings = load_metadata

        @constant_pool_offset = io.read(4).unpack1("L")
        @constant_pool = Array.new(load_varint, nil)

        [load_node, comments, magic_comments, errors, warnings]
      end

      def load_result
        node, comments, magic_comments, errors, warnings = load_nodes
        Prism::ParseResult.new(node, comments, magic_comments, errors, warnings, @source)
      end

      private

      # variable-length integer using https://en.wikipedia.org/wiki/LEB128
      # This is also what protobuf uses: https://protobuf.dev/programming-guides/encoding/#varints
      def load_varint
        n = io.getbyte
        if n < 128
          n
        else
          n -= 128
          shift = 0
          while (b = io.getbyte) >= 128
            n += (b - 128) << (shift += 7)
          end
          n + (b << (shift + 7))
        end
      end

      def load_serialized_length
        io.read(4).unpack1("L")
      end

      def load_optional_node
        if io.getbyte != 0
          io.pos -= 1
          load_node
        end
      end

      def load_embedded_string
        io.read(load_varint).force_encoding(encoding)
      end

      def load_string
        type = io.getbyte
        case type
        when 1
          input.byteslice(load_varint, load_varint).force_encoding(encoding)
        when 2
          load_embedded_string
        else
          raise "Unknown serialized string type: #{type}"
        end
      end

      def load_location
        Location.new(source, load_varint, load_varint)
      end

      def load_optional_location
        load_location if io.getbyte != 0
      end

      def load_constant(index)
        constant = constant_pool[index]

        unless constant
          offset = constant_pool_offset + index * 8
          start = serialized.unpack1("L", offset: offset)
          length = serialized.unpack1("L", offset: offset + 4)

          constant =
            if start.nobits?(1 << 31)
              input.byteslice(start, length).to_sym
            else
              serialized.byteslice(start & ((1 << 31) - 1), length).to_sym
            end

          constant_pool[index] = constant
        end

        constant
      end

      def load_required_constant
        load_constant(load_varint - 1)
      end

      def load_optional_constant
        index = load_varint
        load_constant(index - 1) if index != 0
      end

      def load_node
        type = io.getbyte
        location = load_location

        case type
        when 1 then
          AliasGlobalVariableNode.new(load_node, load_node, load_location, location)
        when 2 then
          AliasMethodNode.new(load_node, load_node, load_location, location)
        when 3 then
          AlternationPatternNode.new(load_node, load_node, load_location, location)
        when 4 then
          AndNode.new(load_node, load_node, load_location, location)
        when 5 then
          ArgumentsNode.new(Array.new(load_varint) { load_node }, location)
        when 6 then
          ArrayNode.new(Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, location)
        when 7 then
          ArrayPatternNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, location)
        when 8 then
          AssocNode.new(load_node, load_optional_node, load_optional_location, location)
        when 9 then
          AssocSplatNode.new(load_optional_node, load_location, location)
        when 10 then
          BackReferenceReadNode.new(load_required_constant, location)
        when 11 then
          BeginNode.new(load_optional_location, load_optional_node, load_optional_node, load_optional_node, load_optional_node, load_optional_location, location)
        when 12 then
          BlockArgumentNode.new(load_optional_node, load_location, location)
        when 13 then
          BlockLocalVariableNode.new(load_required_constant, location)
        when 14 then
          BlockNode.new(Array.new(load_varint) { load_required_constant }, load_optional_node, load_optional_node, load_location, load_location, location)
        when 15 then
          BlockParameterNode.new(load_optional_constant, load_optional_location, load_location, location)
        when 16 then
          BlockParametersNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, location)
        when 17 then
          BreakNode.new(load_optional_node, load_location, location)
        when 18 then
          CallAndWriteNode.new(load_optional_node, load_optional_location, load_optional_location, load_varint, load_required_constant, load_required_constant, load_location, load_node, location)
        when 19 then
          CallNode.new(load_optional_node, load_optional_location, load_optional_location, load_optional_location, load_optional_node, load_optional_location, load_optional_node, load_varint, load_required_constant, location)
        when 20 then
          CallOperatorWriteNode.new(load_optional_node, load_optional_location, load_optional_location, load_varint, load_required_constant, load_required_constant, load_required_constant, load_location, load_node, location)
        when 21 then
          CallOrWriteNode.new(load_optional_node, load_optional_location, load_optional_location, load_varint, load_required_constant, load_required_constant, load_location, load_node, location)
        when 22 then
          CapturePatternNode.new(load_node, load_node, load_location, location)
        when 23 then
          CaseNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, load_location, load_location, location)
        when 24 then
          ClassNode.new(Array.new(load_varint) { load_required_constant }, load_location, load_node, load_optional_location, load_optional_node, load_optional_node, load_location, load_required_constant, location)
        when 25 then
          ClassVariableAndWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 26 then
          ClassVariableOperatorWriteNode.new(load_required_constant, load_location, load_location, load_node, load_required_constant, location)
        when 27 then
          ClassVariableOrWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 28 then
          ClassVariableReadNode.new(load_required_constant, location)
        when 29 then
          ClassVariableTargetNode.new(load_required_constant, location)
        when 30 then
          ClassVariableWriteNode.new(load_required_constant, load_location, load_node, load_optional_location, location)
        when 31 then
          ConstantAndWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 32 then
          ConstantOperatorWriteNode.new(load_required_constant, load_location, load_location, load_node, load_required_constant, location)
        when 33 then
          ConstantOrWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 34 then
          ConstantPathAndWriteNode.new(load_node, load_location, load_node, location)
        when 35 then
          ConstantPathNode.new(load_optional_node, load_node, load_location, location)
        when 36 then
          ConstantPathOperatorWriteNode.new(load_node, load_location, load_node, load_required_constant, location)
        when 37 then
          ConstantPathOrWriteNode.new(load_node, load_location, load_node, location)
        when 38 then
          ConstantPathTargetNode.new(load_optional_node, load_node, load_location, location)
        when 39 then
          ConstantPathWriteNode.new(load_node, load_location, load_node, location)
        when 40 then
          ConstantReadNode.new(load_required_constant, location)
        when 41 then
          ConstantTargetNode.new(load_required_constant, location)
        when 42 then
          ConstantWriteNode.new(load_required_constant, load_location, load_node, load_location, location)
        when 43 then
          load_serialized_length
          DefNode.new(load_required_constant, load_location, load_optional_node, load_optional_node, load_optional_node, Array.new(load_varint) { load_required_constant }, load_location, load_optional_location, load_optional_location, load_optional_location, load_optional_location, load_optional_location, location)
        when 44 then
          DefinedNode.new(load_optional_location, load_node, load_optional_location, load_location, location)
        when 45 then
          ElseNode.new(load_location, load_optional_node, load_optional_location, location)
        when 46 then
          EmbeddedStatementsNode.new(load_location, load_optional_node, load_location, location)
        when 47 then
          EmbeddedVariableNode.new(load_location, load_node, location)
        when 48 then
          EnsureNode.new(load_location, load_optional_node, load_location, location)
        when 49 then
          FalseNode.new(location)
        when 50 then
          FindPatternNode.new(load_optional_node, load_node, Array.new(load_varint) { load_node }, load_node, load_optional_location, load_optional_location, location)
        when 51 then
          FlipFlopNode.new(load_optional_node, load_optional_node, load_location, load_varint, location)
        when 52 then
          FloatNode.new(location)
        when 53 then
          ForNode.new(load_node, load_node, load_optional_node, load_location, load_location, load_optional_location, load_location, location)
        when 54 then
          ForwardingArgumentsNode.new(location)
        when 55 then
          ForwardingParameterNode.new(location)
        when 56 then
          ForwardingSuperNode.new(load_optional_node, location)
        when 57 then
          GlobalVariableAndWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 58 then
          GlobalVariableOperatorWriteNode.new(load_required_constant, load_location, load_location, load_node, load_required_constant, location)
        when 59 then
          GlobalVariableOrWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 60 then
          GlobalVariableReadNode.new(load_required_constant, location)
        when 61 then
          GlobalVariableTargetNode.new(load_required_constant, location)
        when 62 then
          GlobalVariableWriteNode.new(load_required_constant, load_location, load_node, load_location, location)
        when 63 then
          HashNode.new(load_location, Array.new(load_varint) { load_node }, load_location, location)
        when 64 then
          HashPatternNode.new(load_optional_node, Array.new(load_varint) { load_node }, load_optional_node, load_optional_location, load_optional_location, location)
        when 65 then
          IfNode.new(load_optional_location, load_node, load_optional_node, load_optional_node, load_optional_location, location)
        when 66 then
          ImaginaryNode.new(load_node, location)
        when 67 then
          ImplicitNode.new(load_node, location)
        when 68 then
          InNode.new(load_node, load_optional_node, load_location, load_optional_location, location)
        when 69 then
          IndexAndWriteNode.new(load_optional_node, load_optional_location, load_location, load_optional_node, load_location, load_optional_node, load_varint, load_location, load_node, location)
        when 70 then
          IndexOperatorWriteNode.new(load_optional_node, load_optional_location, load_location, load_optional_node, load_location, load_optional_node, load_varint, load_required_constant, load_location, load_node, location)
        when 71 then
          IndexOrWriteNode.new(load_optional_node, load_optional_location, load_location, load_optional_node, load_location, load_optional_node, load_varint, load_location, load_node, location)
        when 72 then
          InstanceVariableAndWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 73 then
          InstanceVariableOperatorWriteNode.new(load_required_constant, load_location, load_location, load_node, load_required_constant, location)
        when 74 then
          InstanceVariableOrWriteNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 75 then
          InstanceVariableReadNode.new(load_required_constant, location)
        when 76 then
          InstanceVariableTargetNode.new(load_required_constant, location)
        when 77 then
          InstanceVariableWriteNode.new(load_required_constant, load_location, load_node, load_location, location)
        when 78 then
          IntegerNode.new(load_varint, location)
        when 79 then
          InterpolatedMatchLastLineNode.new(load_location, Array.new(load_varint) { load_node }, load_location, load_varint, location)
        when 80 then
          InterpolatedRegularExpressionNode.new(load_location, Array.new(load_varint) { load_node }, load_location, load_varint, location)
        when 81 then
          InterpolatedStringNode.new(load_optional_location, Array.new(load_varint) { load_node }, load_optional_location, location)
        when 82 then
          InterpolatedSymbolNode.new(load_optional_location, Array.new(load_varint) { load_node }, load_optional_location, location)
        when 83 then
          InterpolatedXStringNode.new(load_location, Array.new(load_varint) { load_node }, load_location, location)
        when 84 then
          KeywordHashNode.new(Array.new(load_varint) { load_node }, location)
        when 85 then
          KeywordParameterNode.new(load_required_constant, load_location, load_optional_node, location)
        when 86 then
          KeywordRestParameterNode.new(load_optional_constant, load_optional_location, load_location, location)
        when 87 then
          LambdaNode.new(Array.new(load_varint) { load_required_constant }, load_location, load_location, load_location, load_optional_node, load_optional_node, location)
        when 88 then
          LocalVariableAndWriteNode.new(load_location, load_location, load_node, load_required_constant, load_varint, location)
        when 89 then
          LocalVariableOperatorWriteNode.new(load_location, load_location, load_node, load_required_constant, load_required_constant, load_varint, location)
        when 90 then
          LocalVariableOrWriteNode.new(load_location, load_location, load_node, load_required_constant, load_varint, location)
        when 91 then
          LocalVariableReadNode.new(load_required_constant, load_varint, location)
        when 92 then
          LocalVariableTargetNode.new(load_required_constant, load_varint, location)
        when 93 then
          LocalVariableWriteNode.new(load_required_constant, load_varint, load_location, load_node, load_location, location)
        when 94 then
          MatchLastLineNode.new(load_location, load_location, load_location, load_string, load_varint, location)
        when 95 then
          MatchPredicateNode.new(load_node, load_node, load_location, location)
        when 96 then
          MatchRequiredNode.new(load_node, load_node, load_location, location)
        when 97 then
          MatchWriteNode.new(load_node, Array.new(load_varint) { load_required_constant }, location)
        when 98 then
          MissingNode.new(location)
        when 99 then
          ModuleNode.new(Array.new(load_varint) { load_required_constant }, load_location, load_node, load_optional_node, load_location, load_required_constant, location)
        when 100 then
          MultiTargetNode.new(Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, location)
        when 101 then
          MultiWriteNode.new(Array.new(load_varint) { load_node }, load_optional_location, load_optional_location, load_location, load_node, location)
        when 102 then
          NextNode.new(load_optional_node, load_location, location)
        when 103 then
          NilNode.new(location)
        when 104 then
          NoKeywordsParameterNode.new(load_location, load_location, location)
        when 105 then
          NumberedReferenceReadNode.new(load_varint, location)
        when 106 then
          OptionalParameterNode.new(load_required_constant, load_location, load_location, load_node, location)
        when 107 then
          OrNode.new(load_node, load_node, load_location, location)
        when 108 then
          ParametersNode.new(Array.new(load_varint) { load_node }, Array.new(load_varint) { load_node }, load_optional_node, Array.new(load_varint) { load_node }, Array.new(load_varint) { load_node }, load_optional_node, load_optional_node, location)
        when 109 then
          ParenthesesNode.new(load_optional_node, load_location, load_location, location)
        when 110 then
          PinnedExpressionNode.new(load_node, load_location, load_location, load_location, location)
        when 111 then
          PinnedVariableNode.new(load_node, load_location, location)
        when 112 then
          PostExecutionNode.new(load_optional_node, load_location, load_location, load_location, location)
        when 113 then
          PreExecutionNode.new(load_optional_node, load_location, load_location, load_location, location)
        when 114 then
          ProgramNode.new(Array.new(load_varint) { load_required_constant }, load_node, location)
        when 115 then
          RangeNode.new(load_optional_node, load_optional_node, load_location, load_varint, location)
        when 116 then
          RationalNode.new(load_node, location)
        when 117 then
          RedoNode.new(location)
        when 118 then
          RegularExpressionNode.new(load_location, load_location, load_location, load_string, load_varint, location)
        when 119 then
          RequiredDestructuredParameterNode.new(Array.new(load_varint) { load_node }, load_location, load_location, location)
        when 120 then
          RequiredParameterNode.new(load_required_constant, location)
        when 121 then
          RescueModifierNode.new(load_node, load_location, load_node, location)
        when 122 then
          RescueNode.new(load_location, Array.new(load_varint) { load_node }, load_optional_location, load_optional_node, load_optional_node, load_optional_node, location)
        when 123 then
          RestParameterNode.new(load_optional_constant, load_optional_location, load_location, location)
        when 124 then
          RetryNode.new(location)
        when 125 then
          ReturnNode.new(load_location, load_optional_node, location)
        when 126 then
          SelfNode.new(location)
        when 127 then
          SingletonClassNode.new(Array.new(load_varint) { load_required_constant }, load_location, load_location, load_node, load_optional_node, load_location, location)
        when 128 then
          SourceEncodingNode.new(location)
        when 129 then
          SourceFileNode.new(load_string, location)
        when 130 then
          SourceLineNode.new(location)
        when 131 then
          SplatNode.new(load_location, load_optional_node, location)
        when 132 then
          StatementsNode.new(Array.new(load_varint) { load_node }, location)
        when 133 then
          StringConcatNode.new(load_node, load_node, location)
        when 134 then
          StringNode.new(load_varint, load_optional_location, load_location, load_optional_location, load_string, location)
        when 135 then
          SuperNode.new(load_location, load_optional_location, load_optional_node, load_optional_location, load_optional_node, location)
        when 136 then
          SymbolNode.new(load_optional_location, load_optional_location, load_optional_location, load_string, location)
        when 137 then
          TrueNode.new(location)
        when 138 then
          UndefNode.new(Array.new(load_varint) { load_node }, load_location, location)
        when 139 then
          UnlessNode.new(load_location, load_node, load_optional_node, load_optional_node, load_optional_location, location)
        when 140 then
          UntilNode.new(load_location, load_optional_location, load_node, load_optional_node, load_varint, location)
        when 141 then
          WhenNode.new(load_location, Array.new(load_varint) { load_node }, load_optional_node, location)
        when 142 then
          WhileNode.new(load_location, load_optional_location, load_node, load_optional_node, load_varint, location)
        when 143 then
          XStringNode.new(load_location, load_location, load_location, load_string, location)
        when 144 then
          YieldNode.new(load_location, load_optional_location, load_optional_node, load_optional_location, location)
        end
      end
    end

    TOKEN_TYPES = [
      nil,
      :EOF,
      :MISSING,
      :NOT_PROVIDED,
      :AMPERSAND,
      :AMPERSAND_AMPERSAND,
      :AMPERSAND_AMPERSAND_EQUAL,
      :AMPERSAND_DOT,
      :AMPERSAND_EQUAL,
      :BACKTICK,
      :BACK_REFERENCE,
      :BANG,
      :BANG_EQUAL,
      :BANG_TILDE,
      :BRACE_LEFT,
      :BRACE_RIGHT,
      :BRACKET_LEFT,
      :BRACKET_LEFT_ARRAY,
      :BRACKET_LEFT_RIGHT,
      :BRACKET_LEFT_RIGHT_EQUAL,
      :BRACKET_RIGHT,
      :CARET,
      :CARET_EQUAL,
      :CHARACTER_LITERAL,
      :CLASS_VARIABLE,
      :COLON,
      :COLON_COLON,
      :COMMA,
      :COMMENT,
      :CONSTANT,
      :DOT,
      :DOT_DOT,
      :DOT_DOT_DOT,
      :EMBDOC_BEGIN,
      :EMBDOC_END,
      :EMBDOC_LINE,
      :EMBEXPR_BEGIN,
      :EMBEXPR_END,
      :EMBVAR,
      :EQUAL,
      :EQUAL_EQUAL,
      :EQUAL_EQUAL_EQUAL,
      :EQUAL_GREATER,
      :EQUAL_TILDE,
      :FLOAT,
      :FLOAT_IMAGINARY,
      :FLOAT_RATIONAL,
      :FLOAT_RATIONAL_IMAGINARY,
      :GLOBAL_VARIABLE,
      :GREATER,
      :GREATER_EQUAL,
      :GREATER_GREATER,
      :GREATER_GREATER_EQUAL,
      :HEREDOC_END,
      :HEREDOC_START,
      :IDENTIFIER,
      :IGNORED_NEWLINE,
      :INSTANCE_VARIABLE,
      :INTEGER,
      :INTEGER_IMAGINARY,
      :INTEGER_RATIONAL,
      :INTEGER_RATIONAL_IMAGINARY,
      :KEYWORD_ALIAS,
      :KEYWORD_AND,
      :KEYWORD_BEGIN,
      :KEYWORD_BEGIN_UPCASE,
      :KEYWORD_BREAK,
      :KEYWORD_CASE,
      :KEYWORD_CLASS,
      :KEYWORD_DEF,
      :KEYWORD_DEFINED,
      :KEYWORD_DO,
      :KEYWORD_DO_LOOP,
      :KEYWORD_ELSE,
      :KEYWORD_ELSIF,
      :KEYWORD_END,
      :KEYWORD_END_UPCASE,
      :KEYWORD_ENSURE,
      :KEYWORD_FALSE,
      :KEYWORD_FOR,
      :KEYWORD_IF,
      :KEYWORD_IF_MODIFIER,
      :KEYWORD_IN,
      :KEYWORD_MODULE,
      :KEYWORD_NEXT,
      :KEYWORD_NIL,
      :KEYWORD_NOT,
      :KEYWORD_OR,
      :KEYWORD_REDO,
      :KEYWORD_RESCUE,
      :KEYWORD_RESCUE_MODIFIER,
      :KEYWORD_RETRY,
      :KEYWORD_RETURN,
      :KEYWORD_SELF,
      :KEYWORD_SUPER,
      :KEYWORD_THEN,
      :KEYWORD_TRUE,
      :KEYWORD_UNDEF,
      :KEYWORD_UNLESS,
      :KEYWORD_UNLESS_MODIFIER,
      :KEYWORD_UNTIL,
      :KEYWORD_UNTIL_MODIFIER,
      :KEYWORD_WHEN,
      :KEYWORD_WHILE,
      :KEYWORD_WHILE_MODIFIER,
      :KEYWORD_YIELD,
      :KEYWORD___ENCODING__,
      :KEYWORD___FILE__,
      :KEYWORD___LINE__,
      :LABEL,
      :LABEL_END,
      :LAMBDA_BEGIN,
      :LESS,
      :LESS_EQUAL,
      :LESS_EQUAL_GREATER,
      :LESS_LESS,
      :LESS_LESS_EQUAL,
      :METHOD_NAME,
      :MINUS,
      :MINUS_EQUAL,
      :MINUS_GREATER,
      :NEWLINE,
      :NUMBERED_REFERENCE,
      :PARENTHESIS_LEFT,
      :PARENTHESIS_LEFT_PARENTHESES,
      :PARENTHESIS_RIGHT,
      :PERCENT,
      :PERCENT_EQUAL,
      :PERCENT_LOWER_I,
      :PERCENT_LOWER_W,
      :PERCENT_LOWER_X,
      :PERCENT_UPPER_I,
      :PERCENT_UPPER_W,
      :PIPE,
      :PIPE_EQUAL,
      :PIPE_PIPE,
      :PIPE_PIPE_EQUAL,
      :PLUS,
      :PLUS_EQUAL,
      :QUESTION_MARK,
      :REGEXP_BEGIN,
      :REGEXP_END,
      :SEMICOLON,
      :SLASH,
      :SLASH_EQUAL,
      :STAR,
      :STAR_EQUAL,
      :STAR_STAR,
      :STAR_STAR_EQUAL,
      :STRING_BEGIN,
      :STRING_CONTENT,
      :STRING_END,
      :SYMBOL_BEGIN,
      :TILDE,
      :UAMPERSAND,
      :UCOLON_COLON,
      :UDOT_DOT,
      :UDOT_DOT_DOT,
      :UMINUS,
      :UMINUS_NUM,
      :UPLUS,
      :USTAR,
      :USTAR_STAR,
      :WORDS_SEP,
      :__END__,
    ]
  end
end
