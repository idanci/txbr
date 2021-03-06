require 'liquid'
require 'uri'
require 'cgi'

module Txbr
  module Liquid
    class ConnectedContentTag < ::Liquid::Tag
      IDENTIFIER = ::Liquid::Lexer::IDENTIFIER

      # This regex is used to split apart the arguments provided in
      # connected_content tags, which typically look like this:
      #
      # connected_content https://foo.com/strings.json?project_slug=myproj&resource_slug=myrsrc :save strings :retry

      # This is a regular expression to pull out the variable in
      # which to store the value returned from the call made by
      # the connected_content filter. For example, if
      # connected_content makes a request to http://foo.com and is
      # told to store the results in a variable called "strings",
      # the API response will then be accessible via the normal
      # Liquid variable mechanism, i.e. {{...}}. Say the API at
      # foo.com returned something like {"bar":"baz"}, then the
      # template might contain {{strings.bar}}, which would print
      # out "baz".
      PARSE_RE = /(:#{IDENTIFIER})\s+(#{IDENTIFIER})/

      attr_reader :tag_name, :url, :arguments

      def initialize(tag_name, arg, _parse_context = nil)
        @tag_name = tag_name
        @url, @arguments = parse_arg(arg)
      end

      def prefix
        # we want to blow up if "save" isn't present
        arguments.fetch('save').first
      end

      def render(context)
        @url = ::Liquid::Template.parse(url).render(context)
        ''
      end

      def metadata
        uri = URI.parse(url)

        Metadata.new(
          CGI.parse(uri.query)
            .each_with_object({}) { |(k, v), ret| ret[k] = v.first }
            .merge('prefix' => prefix)
        )
      end

      private

      def parse_arg(arg)
        url, *components = arg.split(PARSE_RE)

        url.strip!
        components.map!(&:strip).reject!(&:empty?)

        idx = 0
        args = {}

        while idx < components.size
          if components[idx].start_with?(':')
            key = components[idx][1..-1]
            sub_args = []
            idx += 1

            while idx < components.size && !components[idx].start_with?(':')
              sub_args << components[idx]
              idx += 1
            end

            args[key] = sub_args
          end
        end

        [url, args]
      end
    end
  end
end
