RSpec.describe OpenAI::Client do
  describe "#chat" do
    context "with messages", :vcr do
      let(:messages) { [{ role: "user", content: "Hello!" }] }
      let(:stream) { false }
      let(:response) do
        OpenAI::Client.new.chat(
          parameters: {
            model: model,
            messages: messages,
            stream: stream
          }
        )
      end
      let(:content) { response.dig("choices", 0, "message", "content") }
      let(:cassette) { "#{model} #{'streamed' if stream} chat".downcase }

      context "with model: gpt-3.5-turbo" do
        let(:model) { "gpt-3.5-turbo" }

        it "succeeds" do
          VCR.use_cassette(cassette) do
            expect(content.split.empty?).to eq(false)
          end
        end

        describe "streaming" do
          let(:chunks) { [] }
          let(:stream) do
            proc do |chunk, _bytesize|
              chunks << chunk
            end
          end

          it "succeeds" do
            VCR.use_cassette(cassette) do
              response
              expect(chunks.dig(0, "choices", 0, "index")).to eq(0)
            end
          end

          context "with an object with a call method" do
            let(:cassette) { "#{model} streamed chat without proc".downcase }
            let(:stream) do
              Class.new do
                attr_reader :chunks

                def initialize
                  @chunks = []
                end

                def call(chunk)
                  @chunks << chunk
                end
              end.new
            end

            it "succeeds" do
              VCR.use_cassette(cassette) do
                response
                expect(stream.chunks.dig(0, "choices", 0, "index")).to eq(0)
              end
            end
          end

          context "with an object without a call method" do
            let(:stream) { Object.new }

            it "raises an error" do
              VCR.use_cassette(cassette) do
                expect { response }.to raise_error(ArgumentError)
              end
            end
          end

          context "with an error response with a JSON body" do
            let(:cassette) { "#{model} streamed chat with json error response".downcase }

            it "raises an HTTP error with the parsed body" do
              VCR.use_cassette(cassette, record: :none) do
                response
              rescue Faraday::BadRequestError => e
                expect(e.response).to include(status: 400)
                expect(e.response[:body]).to eq({
                                                  "error" => {
                                                    "message" => "Test error",
                                                    "type" => "test_error",
                                                    "param" => nil,
                                                    "code" => "test"
                                                  }
                                                })
              else
                raise "Expected to raise Faraday::BadRequestError"
              end
            end
          end

          context "with an error response without a JSON body" do
            let(:cassette) { "#{model} streamed chat with error response".downcase }

            it "raises an HTTP error" do
              VCR.use_cassette(cassette, record: :none) do
                response
              rescue Faraday::ServerError => e
                expect(e.response).to include(status: 500)
                expect(e.response[:body]).to eq("")
              else
                raise "Expected to raise Faraday::ServerError"
              end
            end
          end
        end
      end

      context "with model: gpt-3.5-turbo-0301" do
        let(:model) { "gpt-3.5-turbo-0301" }

        it "succeeds" do
          VCR.use_cassette(cassette) do
            expect(content.split.empty?).to eq(false)
          end
        end
      end
    end
  end
end
