describe ServiceOffering::AddToPortfolioItem, :type => [:service, :topology] do
  include ServiceOfferingHelper
  let(:service_offering_ref) { "1" }
  let(:subject) { described_class.new(params) }
  let(:params) do
    {
      :name                 => "Frank",
      :description          => "Franks Description",
      :service_offering_ref => service_offering_ref
    }
  end

  around do |example|
    Insights::API::Common::Request.with_request(default_request) do
      with_modified_env(:TOPOLOGICAL_INVENTORY_URL => "http://topology.example.com", :SOURCES_URL => "http://source.example.com") do
        example.call
      end
    end
  end

  describe "#process" do
    let(:topology_service_offering) { fully_populated_service_offering }
    let(:service_offering_icon) { fully_populated_service_offering_icon }
    let(:catalog_application_type) { {:data => [{:id => 1, :name => "/insights/platform/catalog"}]} }

    before do
      stub_request(:get, topological_url("service_offerings/1"))
        .to_return(:status => 200, :body => topology_service_offering.to_json, :headers => default_headers)
      stub_request(:get, topological_url("service_offering_icons/998"))
        .to_return(:status => 200, :body => service_offering_icon.to_json, :headers => default_headers)

      stub_request(:get, sources_url("application_types"))
        .to_return(:status => 200, :body => catalog_application_type.to_json, :headers => default_headers)
      stub_request(:get, sources_url("application_types/1/sources"))
        .to_return(:status => 200, :body => sources_response.to_json, :headers => default_headers)
    end

    context "when the source is valid" do
      let(:sources_response) { {:data => [{:id => 1}, {:id => 45}]} }

      context "when a user provides params" do
        it "sets the name and description" do
          result = subject.process
          expect(result.item.name).to eq("Frank")
          expect(result.item.description).to eq("Franks Description")
        end

        it "sets the service offering source ref" do
          expect(subject.process.item.service_offering_source_ref).to eq("45")
        end

        it "sets the service offering type" do
          expect(subject.process.item.service_offering_type).to eq("job_template")
        end

        context "when service_offering does not have a long_description" do
          let(:topology_service_offering) { fully_populated_service_offering.tap { |so| so.long_description = nil } }

          it "leaves long_description set to nil" do
            expect(subject.process.item.long_description).to be_nil
          end
        end
      end

      context "when there are no user provided params" do
        let(:params) { {:service_offering_ref => service_offering_ref} }

        it "uses the given name, description, and icon " do
          result = subject.process
          expect(result.item.name).to eq("test name")
          expect(result.item.description).to eq("test description")

          expect(result.item.icon.source_id).to eq service_offering_icon.source_id
          expect(result.item.icon.source_ref).to eq service_offering_icon.source_ref
        end

        it "sets the service offering source ref" do
          expect(subject.process.item.service_offering_source_ref).to eq("45")
        end

        it "sets the service offering type" do
          expect(subject.process.item.service_offering_type).to eq("job_template")
        end
      end

      context "when there is no icon" do
        let(:topology_service_offering) do
          fully_populated_service_offering.tap { |so| so.service_offering_icon_id = nil }
        end

        it "does not copy over the icon" do
          expect(subject.process.item.icon).to be_falsey
        end
      end

      context "when the icon has no data" do
        let(:service_offering_icon) { fully_populated_service_offering_icon.tap { |icon| icon.data = nil } }

        it "does not copy over the icon" do
          expect(subject.process.item.icon).to be_falsey
        end
      end

      context "when there is a topology error" do
        before do
          stub_request(:get, topological_url("service_offerings/1"))
            .to_return(:status => 500, :headers => default_headers)
        end

        it "raises an exception" do
          expect { subject.process }.to raise_exception(Catalog::TopologyError)
        end
      end
    end

    context "when the source is invalid" do
      let(:sources_response) { {:data => [{:id => 1}]} }

      it "raises an unauthorized error" do
        expect { subject.process }.to raise_exception(Catalog::NotAuthorized)
      end
    end
  end
end
