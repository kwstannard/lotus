require 'test_helper'
require 'lotus/router'

describe Lotus::Configuration do
  before do
    module MockApp
    end

    ENV['RACK_ENV']   = nil
    ENV['LOTUS_ENV']  = nil
    ENV['LOTUS_HOST'] = nil
    ENV['LOTUS_PORT'] = nil

    @namespace     = MockApp
    @configuration = Lotus::Configuration.new
  end

  after do
    Object.send(:remove_const, :MockApp)
  end

  describe '#configure' do
    describe 'when block is given' do
      it 'overrides other env configs with default' do
        @configuration.configure do
          layout :default
        end

        @configuration.configure :test do
          layout :test
        end.load!(@namespace)

        @configuration.layout.must_equal :default
      end

      describe 'when ENV is set' do
        before do
          ENV['LOTUS_ENV'] = 'environment'
          @configuration   = Lotus::Configuration.new
        end

        after do
          ENV['LOTUS_ENV'] = nil
        end

        it 'sets config based on env' do
          @configuration.configure do
            layout :default
          end

          @configuration.configure :environment do
            layout :environment
          end.load!(@namespace)

          @configuration.layout.must_equal :environment
        end
      end
    end

    describe 'when no block is given' do
      it 'when loaded it will set defaults values' do
        @configuration.root.must_equal Pathname(Dir.pwd).realpath
      end
    end

    describe 'when a relative path is given' do
      before do
        @configuration.configure :development do
          layout :development
        end
      end

      describe "and it's valid" do
        let(:path) { __dir__ + '/fixtures/config/development' }

        it 'configuration path' do
          @configuration.configure :development, path
          @configuration.load!(@namespace)
          @configuration.layout.must_equal :development
          @configuration.handle_exceptions.must_equal false
        end
      end

      describe "and it's unknown" do
        let(:path) { __dir__ + '/fixtures/config/unknown' }

        it 'raises an error' do
          @configuration.configure :development, path

          -> {
            @configuration.load!(@namespace)
          }.must_raise ArgumentError
        end
      end
    end
  end

  describe '#root' do
    describe 'when a value is given' do
      describe "and it's a string" do
        let(:root) { '..' }

        it 'expand it to the real path' do
          @configuration.root root
          @configuration.root.must_equal Pathname.new(root).realpath
        end
      end

      describe "and it's a pathname" do
        let(:root) { Pathname.new('../..') }

        it 'expand it to the real path' do
          @configuration.root root
          @configuration.root.must_equal Pathname.new(root).realpath
        end
      end

      describe "and it implements to_pathname" do
        before do
          class RootPath
            attr_reader :value

            def initialize(value)
              @value = value
            end

            def to_pathname
              Pathname.new(value)
            end
          end
        end

        after do
          Object.send(:remove_const, :RootPath)
        end

        let(:root) { RootPath.new('..') }

        it 'expand it to the real path' do
          @configuration.root root
          @configuration.root.must_equal Pathname.new(root.value).realpath
        end
      end
    end

    describe "when a value isn't given" do
      before do
        @configuration.root '.'
      end

      it 'returns the value' do
        @configuration.root.must_equal Pathname.new('.').realpath
      end
    end
  end

  describe '#adapter' do
    describe 'when not previously set' do
      it 'returns nil' do
        @configuration.adapter.must_be_nil
      end
    end

    describe 'when set' do
      before do
        @configuration.adapter type: :sql, uri: 'sqlite3://uri'
      end

      it 'returns the configured value' do
        @configuration.adapter.must_equal({type: :sql, uri: 'sqlite3://uri'})
      end
    end
  end

  describe '#namespace' do
    describe "when not previously set" do
      it "returns nil" do
        @configuration.namespace.must_be_nil
      end

      describe "when the configuration is loaded" do
        before do
          @configuration.load!(MockApp)
        end

        it "returns the value" do
          @configuration.namespace.must_equal MockApp
        end
      end
    end

    describe "when previously set" do
      before do
        @configuration.namespace Object
      end

      it 'returns the value' do
        @configuration.namespace.must_equal Object
      end

      describe "when the configuration is loaded" do
        before do
          @configuration.configure do
            namespace Object
          end

          @configuration.load!(MockApp)
        end

        it "returns returns the value set by the configure block" do
          @configuration.namespace.must_equal Object
        end
      end
    end
  end

  describe '#load_paths' do
    before do
      @configuration.root '.'
    end

    describe 'by default' do
      it "is empty" do
        @configuration.load_paths.must_be_empty
      end
    end

    it 'allows to add other paths' do
      @configuration.load_paths << '..'
      @configuration.load_paths.must_include '..'
    end
  end

  describe '#routes' do
    describe 'when a block is given' do
      let(:routes) { Proc.new { get '/', to: ->{}, as: :root } }

      it 'sets the routes' do
        @configuration.routes(&routes)

        router = Lotus::Router.new(&@configuration.routes)
        router.path(:root).must_equal '/'
      end
    end

    describe 'when a relative path is given' do
      describe "and it's valid" do
        let(:path) { __dir__ + '/fixtures/routes' }

        it 'sets the routes' do
          @configuration.routes(path)

          router = Lotus::Router.new(&@configuration.routes)
          router.path(:root).must_equal '/'
        end
      end

      describe "and it's unknown" do
        let(:path) { __dir__ + '/fixtures/unknown' }

        it 'raises an error' do
          @configuration.routes(path)

          -> {
            Lotus::Router.new(&@configuration.routes)
          }.must_raise ArgumentError
        end
      end
    end
  end

  describe "#body_parsers" do
    describe "when not previously set" do
      it "defaults to nil" do
        @configuration.body_parsers.must_equal []
      end
    end

    describe "when set" do
      before do
        @configuration.body_parsers :json, :xml
      end

      it "returns the configured values" do
        @configuration.body_parsers.must_equal [:json, :xml]
      end
    end

    describe "when already set" do
      before do
        @configuration.body_parsers :json
      end

      describe "if I set a new value" do
        before do
          @configuration.body_parsers :xml
        end

        it "returns it" do
          @configuration.body_parsers.must_equal [:xml]
        end
      end
    end

  end


  describe '#middleware' do
    it 'returns a new instance of Lotus::Middleware' do
      @configuration.middleware.must_be_instance_of Lotus::Middleware
    end
  end

  # describe '#mapping' do
  #   describe 'when a block is given' do
  #     let(:mapping) { Proc.new { collection :customers do; end } }

  #     it 'sets the database mapping' do
  #       @configuration.mapping(&mapping)

  #       mapper = Lotus::Model::Mapper.new(&@configuration.mapping)
  #       mapper.collection(:customers).must_be_kind_of Lotus::Model::Mapping::Collection
  #     end
  #   end

  #   describe 'when a relative path is given' do
  #     describe "and it's valid" do
  #       let(:path) { __dir__ + '/fixtures/mapping' }

  #       it 'sets the routes' do
  #         @configuration.mapping(path)

  #         mapper = Lotus::Model::Mapper.new(&@configuration.mapping)
  #         mapper.collection(:customers).must_be_kind_of Lotus::Model::Mapping::Collection
  #       end
  #     end

  #     describe "and it's unknown" do
  #       let(:path) { __dir__ + '/fixtures/unknown' }

  #       it 'raises an error' do
  #         @configuration.mapping(path)

  #         -> {
  #           Lotus::Model::Mapper.new(&@configuration.mapping)
  #         }.must_raise ArgumentError
  #       end
  #     end
  #   end
  # end

  describe '#layout' do
    describe "when not previously set" do
      it 'defaults to nil' do
        @configuration.layout.must_be_nil
      end
    end

    describe "when called with an argument" do
      it 'sets the value' do
        @configuration.layout(:other)
        @configuration.layout.must_equal :other
      end
    end

    describe "when called with nil" do
      it 'sets the value' do
        @configuration.layout(nil)
        @configuration.layout.must_be_nil
      end
    end
  end

  describe '#templates' do
    describe "when not previously set" do
      it "is equal to configuration's root" do
        @configuration.root.wont_be_nil
        @configuration.templates.must_equal @configuration.root
      end
    end

    describe "when set" do
      before do
        @configuration.templates 'app/templates'
      end

      it 'returns the configured value' do
        @configuration.templates.must_equal @configuration.root.join('app/templates')
      end
    end
  end

  describe '#cookies' do
    describe "when not previously set" do
      it "is false" do
        @configuration.cookies.enabled?.must_equal false
      end
    end

    describe "when set" do
      before do
        @configuration.cookies true
      end

      it "returns the configured value" do
        @configuration.cookies.enabled?.must_equal true
      end
    end

    describe "when already set" do
      before do
        @configuration.cookies true
      end

      describe "if I set a new value" do
        before do
          @configuration.cookies false
        end

        it "returns it" do
          @configuration.cookies.enabled?.must_equal false
        end
      end
    end

  end

  describe '#sessions' do
    describe 'when not previously set' do
      it 'is not enabled' do
        @configuration.sessions.wont_be :enabled?
      end
    end

    describe 'when set without options' do
      before do
        @configuration.sessions :cookie
      end

      it 'is enabled' do
        @configuration.sessions.must_be :enabled?
      end

      it 'returns the configured value for middleware' do
        @configuration.sessions.middleware.must_equal ["Rack::Session::Cookie", { domain: nil, secure: false }]
      end

      it 'returns default values for options' do
        default_options = { domain:nil, secure:false }
        _, options = @configuration.sessions.middleware

        options.must_equal default_options
      end
    end

    describe 'when set with options' do
      before do
        @configuration.sessions :cookies, secure: true, expire_after: 2592000
      end

      it 'merges default option values' do
        _, options = @configuration.sessions.middleware
        options[:domain].must_be_nil
        options[:expire_after].must_equal 2592000
        options[:secure].must_equal true
      end
    end

    describe 'when already set' do
      before do
        @configuration.sessions :cookies

        module Rack::Session
          class FileSystem
          end
        end
      end

      after do
        Rack::Session.__send__(:remove_const, :FileSystem)
      end

      describe 'if set with new configuration' do
        before do
          @configuration.sessions 'Rack::Session::FileSystem'
        end

        it 'returns it' do
          @configuration.sessions.middleware.must_equal ['Rack::Session::FileSystem', { domain: nil, secure: false }]
        end
      end

      describe 'if set with false' do
        before do
          @configuration.sessions false
        end

        it 'is disabled' do
          @configuration.sessions.wont_be :enabled?
        end
      end
    end
  end

  describe 'assets' do
    before do
      @configuration.root 'test/fixtures/collaboration/apps/web'
    end

    describe "when serve_assets isn't previously set" do
      it "doesn't serve assets" do
        @configuration.serve_assets.must_equal false
      end
    end

    describe 'when serve_assets set to true' do
      before do
        @configuration.serve_assets true
      end
      describe 'with a directory name' do
        it 'returns the configured values' do
          expectations = [
            %(/stylesheets),
            %(/favicon.ico),
            %(/javascripts),
            %(/fonts),
            %(/images)
          ]
          actual = @configuration.assets.entries.values.flatten
          expectations.each do |expectation|
            actual.must_include expectation
          end
        end
      end

      describe 'if set with emtpy array' do
        before do
          @configuration.assets.instance_variable_set(:@paths, [])
        end

        it 'returns false' do
          @configuration.assets.wont_be :any?
        end
      end

      describe 'adding new assets paths' do
        before do
          @configuration.assets << [
            'vendor/assets',
            'vendor/another_assets_path'
          ]
        end

        it 'returns it' do
          expectations = [
            %(/stylesheets),
            %(/favicon.ico),
            %(/javascripts),
            %(/fonts),
            %(/images),
            %(/foo.js),
            %(/bar.js)
          ]
          actual = @configuration.assets.entries.values.flatten
          expectations.each do |expectation|
            actual.must_include expectation
          end
        end

        describe 'if set with emtpy array' do
          before do
            @configuration.assets.instance_variable_set(:@paths, [])
          end

          it 'returns it' do
            @configuration.assets.wont_be :any?
          end
        end
      end

      describe 'adding relative path' do
        before do
          @configuration.assets << [
            '../../vendor/assets'
          ]
        end

        it 'returns it' do
          expectations = [
            %(/stylesheets),
            %(/favicon.ico),
            %(/javascripts),
            %(/fonts),
            %(/images),
            %(/lotus.js)
          ]
          actual = @configuration.assets.entries.values.flatten
          expectations.each do |expectation|
            actual.must_include expectation
          end
        end
      end
    end
  end

  describe '#default_format' do
    describe "when not previously set" do
      it 'returns nil' do
        @configuration.default_format.must_equal :html
      end
    end

    describe "when set" do
      before do
        @configuration.default_format :json
      end

      it 'returns the value' do
        @configuration.default_format.must_equal :json
      end
    end

    it 'raises an error if the given format cannot be coerced into symbol' do
      -> { @configuration.default_format(23) }.must_raise TypeError
    end
  end

  describe '#scheme' do
    describe "when not previously set" do
      it 'defaults to a specific value' do
        @configuration.scheme.must_equal 'http'
      end
    end

    describe "when called with an argument" do
      it 'sets the value' do
        @configuration.scheme(scheme = 'https')
        @configuration.scheme.must_equal scheme
      end
    end
  end

  describe '#host' do
    before do
      ENV['LOTUS_HOST'] = nil
      ENV['LOTUS_ENV']  = nil
    end

    describe "when not previously set" do
      before do
        @configuration = Lotus::Configuration.new
      end

      it 'defaults to a specific value' do
        @configuration.host.must_equal 'localhost'
      end
    end

    describe "when the env var is set" do
      before do
        ENV['LOTUS_HOST'] = 'lotustest.org'
        @configuration = Lotus::Configuration.new
      end

      it 'returns that value' do
        @configuration.host.must_equal 'lotustest.org'
      end
    end

    describe "when called with an argument" do
      it 'sets the value' do
        @configuration.host(host = 'lotusrb.org')
        @configuration.host.must_equal host
      end
    end
  end

  describe '#port' do
    describe "when not previously set" do
      it 'defaults to 2300' do
        @configuration.port.must_equal 2300
      end
    end

    describe "when the env var is set" do
      before do
        ENV['LOTUS_PORT'] = '2306'
        @configuration = Lotus::Configuration.new
      end

      after do
        ENV['LOTUS_PORT'] = nil
      end

      it 'returns that value' do
        @configuration.port.must_equal 2306
      end
    end

    describe "when called with an argument" do
      it 'sets the value' do
        @configuration.port(port = '8080')
        @configuration.port.must_equal port.to_i
      end
    end
  end

  describe '#controller_pattern' do
    describe "when not previously set" do
      it 'defaults to a specific value' do
        @configuration.controller_pattern.must_equal 'Controllers::%{controller}::%{action}'
      end
    end

    describe "when called with an argument" do
      it 'sets the value' do
        @configuration.controller_pattern(pattern = '%{controller}Controller::%{action}')
        @configuration.controller_pattern.must_equal pattern
      end
    end
  end

  describe '#view_pattern' do
    describe "when not previously set" do
      it 'defaults to a specific value' do
        @configuration.view_pattern.must_equal 'Views::%{controller}::%{action}'
      end
    end

    describe "when called with an argument" do
      it 'sets the value' do
        @configuration.view_pattern(pattern = '%{controller}View::%{action}')
        @configuration.view_pattern.must_equal pattern
      end
    end
  end

  describe '#freeze' do
    before do
      @configuration.freeze
    end

    it 'must be frozen' do
      @configuration.must_be :frozen?
    end

    it 'it raises error when try to load!' do
      -> { @configuration.load! 'Bookshelf' }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate root' do
      -> { @configuration.root '..' }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate assets' do
      -> { @configuration.assets << 'assets' }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate templates' do
      -> { @configuration.templates 'app/templates' }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the configure block' do
      -> { @configuration.configure(&Proc.new{}) }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the controller_pattern' do
      -> { @configuration.controller_pattern('%{controller}::%{action}') }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the view_pattern' do
      -> { @configuration.view_pattern('%{controller}::%{action}') }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the default_format' do
      -> { @configuration.default_format(:xml) }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the scheme' do
      -> { @configuration.scheme('http') }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the host' do
      -> { @configuration.host('example.org') }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the port' do
      -> { @configuration.port(80) }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the layout' do
      -> { @configuration.layout(:another) }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the load_paths' do
      -> { @configuration.load_paths << 'app/controllers' }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the namespace' do
      -> { @configuration.namespace(Object) }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate the routes' do
      -> { @configuration.routes(&Proc.new{}) }.must_raise RuntimeError
    end

    it 'it raises error when try to mutate handle_exceptions setting' do
      -> { @configuration.handle_exceptions(false) }.must_raise RuntimeError
    end
  end
end
