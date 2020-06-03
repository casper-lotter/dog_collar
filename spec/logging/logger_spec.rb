require 'stringio'
require 'dog_collar/logging/logger'

describe DogCollar::Logging::Logger do
  let(:io) { StringIO.new }
  let(:logger) { described_class.new(io, progname: 'foo') }

  before do
    allow(Time).to receive(:now).and_return(Time.new)
  end

  describe '#formatter' do
    it 'defaults to the JSON formatter' do
      expect(logger.formatter).to be_a(DogCollar::Logging::Formatters::JSON)
    end
  end

  describe '#add' do
    let(:formatter) { double }
    let(:time) { Time.now }
    let(:severity) { Logger::INFO }
    let(:progname) { "foobar" }
    let(:msg) { "Hello, world!" }
    let(:meta) { { a: 1, b: 2, c: 3 } }
    let(:logger) { described_class.new(io, progname: progname) }

    before do
      logger.formatter = formatter
    end

    context 'when a block is provided' do
      it 'forwards the return value as the log message' do
        expect(formatter).to receive(:call).with(severity, time, progname, msg, meta)
        logger.add(severity, **meta) { msg }
      end

      it 'allows the user to modify the metadata inside the block' do
        expect(formatter).to receive(:call).with(severity, time, progname, msg, **meta, d: 4)
        logger.add(severity, **meta) do |meta|
          meta[:d] = 4
          msg
        end
      end

      it 'doesn not overwrite the message argument' do
        expect(formatter).to receive(:call).with(severity, time, progname, msg, **meta, d: 4)
        logger.add(severity, msg, **meta) do |meta|
          meta[:d] = 4
          "Overwrite"
        end
      end
    end

    context 'when a message is provided' do
      it 'calls the provided formatter' do
        expect(formatter).to receive(:call).with(severity, time, progname, msg, meta)
        logger.add(severity, msg, **meta)
      end
    end

    context 'when no message is provided' do
      it 'calls the provided formatter' do
        expect(formatter).to receive(:call).with(severity, time, progname, nil, meta)
        logger.add(severity, **meta)
      end
    end
  end

  describe '#before_log' do
    let(:formatter) { double }

    before do
      logger.formatter = formatter
      logger.before_log { { b: 100, c: 3 } }
      logger.before_log { { a: 100, b: 2 } }
    end

    it 'adds the resulting hash to the metadata on future logs' do
      expect(formatter).to receive(:call).with(anything, anything, anything, anything, a: 1, b: 2, c: 3)
      logger.info("foo", a: 1) # metadata here should override metadata from hooks
    end
  end

  described_class::LOG_SEV.each do |method, severity|
    describe "##{method}" do
      let(:meta) { { a: 1, b: 2, c: 3 } }

      context 'when a block is given' do
        it 'yields' do
          expect { |b| logger.add(Logger::INFO, **meta, &b) }.to yield_with_args(meta)
        end
      end

      context "when a message is provided" do
        let(:message) { "foobar" }

        it 'calls #add with the correct severity' do
          expect(logger).to receive(:add).with(severity, message, **meta)
          logger.send(method, message, **meta)
        end
      end

      context "when no message is provided" do
        it 'calls #add with the correct severity' do
          expect(logger).to receive(:add).with(severity, nil, **meta)
          logger.send(method, **meta)
        end
      end
    end
  end
end
