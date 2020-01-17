describe ServicePlan do
  let(:service_plan) { create(:service_plan) }
  let!(:portfolio_item) { service_plan.portfolio_item }
  let!(:service_offering_ref) { portfolio_item.service_offering_ref }
  let(:valid_ddf) { JSON.parse(File.read(Rails.root.join("spec", "support", "ddf", "valid_service_plan_ddf.json"))) }

  around do |example|
    with_modified_env(:TOPOLOGICAL_INVENTORY_URL => "http://topology.example.com", :BYPASS_RBAC => 'true') do
      Insights::API::Common::Request.with_request(default_request) { example.call }
    end
  end

  let(:topo_service_plan) do
    TopologicalInventoryApiClient::ServicePlan.new(
      :name               => "The Plan",
      :id                 => "1",
      :description        => "A Service Plan",
      :create_json_schema => valid_ddf
    )
  end

  let(:service_plan_response) { TopologicalInventoryApiClient::ServicePlansCollection.new(:data => [topo_service_plan]) }
  let(:service_offering_response) do
    TopologicalInventoryApiClient::ServiceOffering.new(:extra => {"survey_enabled" => true})
  end

  before do
    stub_request(:get, topological_url(service_offering_ref))
      .to_return(:status => 200, :body => service_offering_response.to_json, :headers => default_headers)
    stub_request(:get, topological_url("service_offerings/#{service_offering_ref}/service_plans"))
      .to_return(:status => 200, :body => service_plan_response.to_json, :headers => default_headers)
  end

  describe "#update" do
    context "invalid" do
      it "sets an error" do
        expect { service_plan.update!(:modified => { "schema"=> { "title" => "changed", "more" => "less" }}) }.to raise_error(Catalog::InvalidSurvey)
      end
    end

    context "valid" do
      let(:service_plan) { create(:service_plan, :base => valid_ddf) }

      before do
        service_plan.update!(:modified => valid_ddf)
        service_plan.reload
      end

      it "does not set an error" do
        expect(service_plan.valid?).to be true
        expect(service_plan.errors.first).to be_nil
      end

      it "shows the modified column is unchanged" do
        expect(service_plan.modified["schema"]).to eq valid_ddf["schema"]
      end
    end

    context "modified schema comparison" do
      let(:service_plan) { create(:service_plan, :base => reordered_ddf) }
      let(:reordered_ddf) { valid_ddf.tap { |ddf| ddf["schema"]["fields"].reverse! } }

      context "when only the order has changed" do
        it "passes validation" do
          service_plan.update!(:modified => reordered_ddf)

          expect(service_plan.valid?).to be_truthy
        end
      end

      context "when the order has changed but base has also changed" do
        let(:changed_ddf) { reordered_ddf.tap { |ddf| ddf["schema"]["fields"].first["name"] = "Not the same name" } }

        it "fails validation" do
          expect { service_plan.update!(:base => changed_ddf) }.to raise_error(Catalog::InvalidSurvey)
        end
      end
    end
  end
end
