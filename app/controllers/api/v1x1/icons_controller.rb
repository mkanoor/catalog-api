module Api
  module V1x1
    class IconsController < ApplicationController
      include Mixins::IndexMixin

      # Due to the fact form-data is getting uploaded and isn't supported by openapi_parser
      skip_before_action :validate_request, :only => %i[create]

      def create
        icon = Catalog::CreateIcon.new(icon_params).process.icon
        render :json => icon
      end

      def destroy
        Catalog::SoftDelete.new(Icon.find(params.require(:id))).process
        head :no_content
      end

      def raw_icon
        image = find_icon(parse_raw_icon_params).image.decoded_image
        send_data(image,
                  :type        => MimeMagic.by_magic(image).type,
                  :disposition => 'inline')
      rescue ActiveRecord::RecordNotFound
        Rails.logger.debug("Icon not found for params: #{params.keys.select { |key| key.end_with?("_id") }}")
        head :no_content
      end

      private

      def icon_params
        params.require(:content)
        params.permit(:content, :portfolio_item_id, :portfolio_id)
      end

      def find_icon(ids)
        if ids[:portfolio_item_id].present?
          Icon.find_by!(:restore_to => PortfolioItem.find(ids[:portfolio_item_id]))
        elsif ids[:portfolio_id].present?
          Icon.find_by!(:restore_to => Portfolio.find(ids[:portfolio_id]))
        end
      end

      def parse_raw_icon_params
        params.permit(:icon_id, :portfolio_item_id, :portfolio_id)
      end
    end
  end
end
